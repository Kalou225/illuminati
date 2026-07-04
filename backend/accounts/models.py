from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from decimal import Decimal

class UserManager(BaseUserManager):
    """Gestionnaire pour créer des utilisateurs et super-utilisateurs."""
    
    def create_user(self, email, phone_number, full_name, password=None, **extra_fields):
        if not email:
            raise ValueError('L\'adresse email est obligatoire')
        if not phone_number:
            raise ValueError('Le numéro de téléphone est obligatoire')
            
        email = self.normalize_email(email)
        user = self.model(email=email, phone_number=phone_number, full_name=full_name, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, phone_number, full_name, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('grade', 'GRAND_MAITRE')
        extra_fields.setdefault('is_activated', True)
        extra_fields.setdefault('activation_amount', Decimal('20000000'))  # 20M FCFA pour le fondateur
        
        if extra_fields.get('is_staff') is not True:
            raise ValueError('Le superutilisateur doit avoir is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Le superutilisateur doit avoir is_superuser=True.')

        return self.create_user(email, phone_number, full_name, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    """Modèle utilisateur personnalisé pour Illuminati."""
    
    GRADE_CHOICES = [
        ('APPRENTI', 'Apprenti'),
        ('COMPAGNON_N3', 'Compagnon Niveau 3'),
        ('COMPAGNON_N2', 'Compagnon Niveau 2'),
        ('COMPAGNON_N1', 'Compagnon Niveau 1'),
        ('MAITRE_N3', 'Maître Niveau 3'),
        ('MAITRE_N2', 'Maître Niveau 2'),
        ('MAITRE_N1', 'Maître Niveau 1'),
        ('GRAND_MAITRE', 'Grand Maître'),
    ]

    # Informations de base
    email = models.EmailField(unique=True, verbose_name="Adresse Email")
    phone_number = models.CharField(max_length=15, unique=True, verbose_name="Numéro de téléphone")
    full_name = models.CharField(max_length=100, verbose_name="Nom complet")
    
    # Grade dans la loge
    grade = models.CharField(
        max_length=20, 
        choices=GRADE_CHOICES, 
        default='APPRENTI',
        verbose_name="Grade"
    )
    
    # Activation du compte
    is_activated = models.BooleanField(
        default=False,
        verbose_name="Compte activé"
    )
    activation_amount = models.DecimalField(
        max_digits=15, 
        decimal_places=2, 
        default=Decimal('0'),
        verbose_name="Montant d'activation (bloqué)"
    )
    
    # Compteur de commissions
    commission_balance = models.DecimalField(
        max_digits=15, 
        decimal_places=2, 
        default=Decimal('0'),
        verbose_name="Cumul des commissions"
    )
    
    # Commissions en attente (si utilisateur non activé)
    pending_commissions = models.DecimalField(
        max_digits=15, 
        decimal_places=2, 
        default=Decimal('0'),
        verbose_name="Commissions en attente"
    )
    
    # Gestion des retraits
    last_withdrawal_date = models.DateTimeField(
        blank=True, 
        null=True,
        verbose_name="Date du dernier retrait"
    )
    withdrawal_requested = models.BooleanField(
        default=False,
        verbose_name="Retrait en attente de validation"
    )
    withdrawal_requested_at = models.DateTimeField(
        blank=True, 
        null=True,
        verbose_name="Date de la demande de retrait"
    )
    
    # Droits et statut
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)

    # Système de parrainage
    sponsor = models.ForeignKey(
        'self', 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name='sponsored_users',
        verbose_name="Parrain"
    )
    referral_code = models.CharField(
        max_length=20, 
        unique=True, 
        blank=True, 
        null=True, 
        verbose_name="Code de parrainage"
    )

    objects = UserManager()

    # On utilise l'email pour se connecter au lieu du username
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['phone_number', 'full_name']
    
    def save(self, *args, **kwargs):
        # Générer un code de parrainage unique si l'utilisateur n'en a pas
        if not self.referral_code and not self.pk:
            import uuid
            short_uuid = uuid.uuid4().hex[:4].upper()
            name_prefix = self.full_name.split()[0][:3].upper() if self.full_name else 'USR'
            self.referral_code = f"{name_prefix}-{short_uuid}"
        
        # NE PAS mettre à jour le grade automatiquement
        # Le grade est mis à jour uniquement via le bouton "Monter de grade"
        
        super().save(*args, **kwargs)
    
    def get_commission_percentage(self):
        """Retourne le pourcentage de commission selon le grade."""
        percentages = {
            'APPRENTI': Decimal('2'),
            'COMPAGNON_N3': Decimal('3'),
            'COMPAGNON_N2': Decimal('4'),
            'COMPAGNON_N1': Decimal('5'),
            'MAITRE_N3': Decimal('6'),
            'MAITRE_N2': Decimal('7'),
            'MAITRE_N1': Decimal('8'),
            'GRAND_MAITRE': Decimal('0'),
        }
        return percentages.get(self.grade, Decimal('0'))
    
    def get_wallet_total(self):
        """Retourne le total du portefeuille (activation + commissions)."""
        return self.activation_amount + self.commission_balance
    
    def can_withdraw(self):
        """Vérifie si l'utilisateur peut effectuer un retrait."""
        if not self.is_activated:
            return False
        if self.commission_balance <= 0:
            return False
        if self.withdrawal_requested:
            return False
        
        # Vérifier si 1 mois s'est écoulé depuis le dernier retrait
        if self.last_withdrawal_date:
            from django.utils import timezone
            from datetime import timedelta
            if timezone.now() - self.last_withdrawal_date < timedelta(days=30):
                return False
        
        return True
    
    def can_upgrade_grade(self):
        """Vérifie si l'utilisateur peut monter de grade."""
        current_grade = self.grade
        wallet_total = self.get_wallet_total()
        
        # Définir les seuils de montée de grade
        thresholds = {
            'APPRENTI': Decimal('201000'),  # Vers Compagnon N3
            'COMPAGNON_N3': Decimal('401000'),  # Vers Compagnon N2
            'COMPAGNON_N2': Decimal('601000'),  # Vers Compagnon N1
            'COMPAGNON_N1': Decimal('801000'),  # Vers Maître N3
            'MAITRE_N3': Decimal('1001000'),  # Vers Maître N2
            'MAITRE_N2': Decimal('2100000'),  # Vers Maître N1
            'MAITRE_N1': Decimal('20000000'),  # Vers Grand Maître
            'GRAND_MAITRE': None,  # Ne peut pas monter plus haut
        }
        
        threshold = thresholds.get(current_grade)
        if threshold is None:
            return False
        
        return wallet_total >= threshold

    class Meta:
        verbose_name = "Utilisateur"
        verbose_name_plural = "Utilisateurs"

    def __str__(self):
        return f"{self.full_name} ({self.grade})"