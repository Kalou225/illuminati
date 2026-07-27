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
    
    # Grade dans la loge (déterminé par activation_amount)
    grade = models.CharField(
        max_length=20, 
        choices=GRADE_CHOICES, 
        default='APPRENTI',
        verbose_name="Grade"
    )
    
    # Activation du compte (manuellement par l'admin)
    is_activated = models.BooleanField(
        default=False,
        verbose_name="Compte activé"
    )
    
    # Solde d'activation (BLOQUÉ À VIE - détermine le grade)
    activation_amount = models.DecimalField(
        max_digits=15, 
        decimal_places=2, 
        default=Decimal('0'),
        verbose_name="Solde d'activation (bloqué à vie)"
    )
    
    # Solde des commissions (retirable ou utilisable pour montée en grade)
    commission_balance = models.DecimalField(
        max_digits=15, 
        decimal_places=2, 
        default=Decimal('0'),
        verbose_name="Solde des commissions"
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
        
        # METTRE À JOUR LE GRADE AUTOMATIQUEMENT selon le solde d'activation
        if self.activation_amount > 0:
            new_grade = self.get_grade_from_activation_balance()
            if new_grade != self.grade:
                self.grade = new_grade
        
        super().save(*args, **kwargs)
        
    def get_commission_percentage(self):
        """Retourne le pourcentage de commission selon le grade."""
        from .grade_constants import COMMISSION_PERCENTAGES
        return COMMISSION_PERCENTAGES.get(self.grade, Decimal('0'))
    
    def get_grade_from_activation_balance(self):
        """Détermine le grade selon le solde d'activation."""
        from .grade_constants import GRADE_PLAGE
        
        for grade, (min_montant, max_montant) in GRADE_PLAGE.items():
            if min_montant <= self.activation_amount <= max_montant:
                return grade
        return 'APPRENTI'
    
    def get_next_grade(self):
        """Retourne le grade suivant dans la hiérarchie."""
        grade_order = [
            'APPRENTI', 'COMPAGNON_N3', 'COMPAGNON_N2', 'COMPAGNON_N1',
            'MAITRE_N3', 'MAITRE_N2', 'MAITRE_N1', 'GRAND_MAITRE'
        ]
        current_index = grade_order.index(self.grade)
        if current_index < len(grade_order) - 1:
            return grade_order[current_index + 1]
        return None
    
    def get_minimum_for_next_grade(self):
        """Retourne le montant minimum requis pour atteindre le grade suivant."""
        from .grade_constants import GRADE_PLAGE
        next_grade = self.get_next_grade()
        if next_grade:
            return GRADE_PLAGE[next_grade][0]  # Minimum de la plage
        return None
    
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
        """Vérifie si l'utilisateur peut monter de grade avec ses commissions."""
        if self.grade == 'GRAND_MAITRE':
            return False
        
        minimum_required = self.get_minimum_for_next_grade()
        if minimum_required is None:
            return False
        
        # Vérifier si le solde commissions est suffisant
        return self.commission_balance >= minimum_required
    
    def upgrade_grade(self, amount=None):
        """
        Monte en grade en utilisant les commissions.
        
        Args:
            amount: Montant à utiliser (par défaut: minimum requis pour le grade suivant)
        
        Returns:
            dict: Informations sur la montée en grade
        """
        if not self.can_upgrade_grade():
            raise ValueError("Vous ne pouvez pas monter de grade actuellement.")
        
        next_grade = self.get_next_grade()
        minimum_required = self.get_minimum_for_next_grade()
        
        # Si aucun montant spécifié, utiliser le minimum requis
        if amount is None:
            amount = minimum_required
        elif amount < minimum_required:
            raise ValueError(f"Le montant minimum pour monter en grade est de {minimum_required} FCFA.")
        elif amount > self.commission_balance:
            raise ValueError(f"Solde commissions insuffisant. Disponible: {self.commission_balance} FCFA.")
        
        # Effectuer la montée en grade
        self.commission_balance -= amount
        self.activation_amount += amount
        self.grade = next_grade
        self.save()
        
        return {
            'new_grade': next_grade,
            'amount_used': amount,
            'new_activation_balance': self.activation_amount,
            'new_commission_balance': self.commission_balance,
            'new_commission_percentage': self.get_commission_percentage(),
        }

    class Meta:
        verbose_name = "Utilisateur"
        verbose_name_plural = "Utilisateurs"

    def __str__(self):
        return f"{self.full_name} ({self.grade})"