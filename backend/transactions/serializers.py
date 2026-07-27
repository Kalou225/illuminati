from rest_framework import serializers
from decimal import Decimal
from .models import Transaction, DistributionCommission
from accounts.models import User
from accounts.grade_constants import get_grade_from_amount, get_grade_display_name


class ActivationSerializer(serializers.Serializer):
    """Serializer pour créer une demande d'activation (en attente de validation admin)."""
    montant = serializers.DecimalField(max_digits=15, decimal_places=2)
    moyen_paiement = serializers.ChoiceField(choices=Transaction.MOYEN_PAIEMENT_CHOICES)
    reference_paiement = serializers.CharField(max_length=100, required=False, allow_blank=True)
    
    def validate_montant(self, value):
        if value <= 0:
            raise serializers.ValidationError("Le montant doit être supérieur à 0.")
        if value < Decimal('1000'):
            raise serializers.ValidationError("Le montant minimum d'activation est de 1 000 FCFA.")
        return value
    
    def validate(self, data):
        user = self.context['request'].user
        
        # Vérifier si le compte est déjà activé
        if user.is_activated:
            raise serializers.ValidationError("Votre compte est déjà activé.")
        
        # Vérifier s'il y a déjà une demande en attente
        pending_activation = Transaction.objects.filter(
            utilisateur=user,
            type_transaction='ACTIVATION',
            statut='EN_ATTENTE'
        ).exists()
        
        if pending_activation:
            raise serializers.ValidationError("Vous avez déjà une demande d'activation en attente de validation.")
        
        return data
    
    def create(self, validated_data):
        user = self.context['request'].user
        
        # Créer une transaction d'activation EN ATTENTE
        transaction = Transaction.objects.create(
            utilisateur=user,
            type_transaction='ACTIVATION',
            montant=validated_data['montant'],
            statut='EN_ATTENTE',
            moyen_paiement=validated_data['moyen_paiement'],
            reference_paiement=validated_data.get('reference_paiement', ''),
            description=f"Demande d'activation - {validated_data['montant']} FCFA"
        )
        
        return transaction


class DepotSerializer(serializers.Serializer):
    """Serializer pour créer un dépôt."""
    montant = serializers.DecimalField(max_digits=15, decimal_places=2)
    moyen_paiement = serializers.ChoiceField(choices=Transaction.MOYEN_PAIEMENT_CHOICES)
    reference_paiement = serializers.CharField(max_length=100, required=False, allow_blank=True)
    
    def validate_montant(self, value):
        if value <= 0:
            raise serializers.ValidationError("Le montant doit être supérieur à 0.")
        return value
    
    def create(self, validated_data):
        user = self.context['request'].user
        
        if not user.is_activated:
            raise serializers.ValidationError("Votre compte doit être activé pour effectuer un dépôt.")
        
        transaction = Transaction.objects.create(
            utilisateur=user,
            type_transaction='DEPOT',
            montant=validated_data['montant'],
            statut='VALIDEE',
            moyen_paiement=validated_data['moyen_paiement'],
            reference_paiement=validated_data.get('reference_paiement', ''),
            date_validation=timezone.now()
        )
        
        # Ajouter au solde d'activation
        user.activation_amount += validated_data['montant']
        
        # Mettre à jour le grade selon la nouvelle plage
        new_grade = get_grade_from_amount(user.activation_amount)
        if new_grade != user.grade:
            user.grade = new_grade
        
        user.save()
        
        # Distribuer les commissions
        from .services import CommissionService
        CommissionService.distribuer_commissions(transaction)
        
        return transaction

class RetraitSerializer(serializers.Serializer):
    """Serializer pour créer une demande de retrait."""
    montant = serializers.DecimalField(max_digits=15, decimal_places=2)
    moyen_paiement = serializers.ChoiceField(choices=Transaction.MOYEN_PAIEMENT_CHOICES)
    phone_number = serializers.CharField(max_length=15)
    phone_number_confirm = serializers.CharField(max_length=15)
    
    def validate_montant(self, value):
        if value <= 0:
            raise serializers.ValidationError("Le montant doit être supérieur à 0.")
        return value
    
    def validate(self, data):
        user = self.context['request'].user
        
        if not user.is_activated:
            raise serializers.ValidationError("Votre compte doit être activé.")
        
        # Vérifier que les numéros correspondent
        if data['phone_number'] != data['phone_number_confirm']:
            raise serializers.ValidationError({
                'phone_number_confirm': 'Les numéros de téléphone ne correspondent pas.'
            })
        
        # Calculer le montant maximum autorisé (1/3 des commissions)
        max_withdrawal = user.commission_balance / Decimal('3')
        
        if data['montant'] > max_withdrawal:
            raise serializers.ValidationError({
                'montant': f'Le montant maximum de retrait est de {max_withdrawal:,.0f} FCFA (1/3 de vos commissions).'
            })
        
        if data['montant'] > user.commission_balance:
            raise serializers.ValidationError(
                f"Solde commissions insuffisant. Disponible: {user.commission_balance} FCFA"
            )
        
        # Vérifier si un retrait est déjà en attente
        if user.withdrawal_requested:
            pending_withdrawal = Transaction.objects.filter(
                utilisateur=user,
                type_transaction='RETRAIT',
                statut='EN_ATTENTE'
            ).first()
            
            if pending_withdrawal:
                # Vérifier si 48h se sont écoulées
                from django.utils import timezone
                from datetime import timedelta
                
                time_since_request = timezone.now() - pending_withdrawal.date_transaction
                
                if time_since_request < timedelta(hours=48):
                    hours_remaining = (timedelta(hours=48) - time_since_request).seconds // 3600
                    raise serializers.ValidationError(
                        f"Une demande de retrait est déjà en attente. Veuillez attendre {hours_remaining}h ou contactez l'admin."
                    )
                else:
                    # Plus de 48h, on peut annuler l'ancienne demande
                    pending_withdrawal.statut = 'REJETEE'
                    pending_withdrawal.save()
                    user.withdrawal_requested = False
                    user.save()
        
        # Vérifier le délai d'1 mois depuis le dernier retrait validé
        if user.last_withdrawal_date:
            from django.utils import timezone
            from datetime import timedelta
            
            if timezone.now() - user.last_withdrawal_date < timedelta(days=30):
                days_remaining = (user.last_withdrawal_date + timedelta(days=30) - timezone.now()).days
                raise serializers.ValidationError(
                    f"Vous devez attendre {days_remaining} jour(s) avant de pouvoir retirer à nouveau (1 retrait par mois)."
                )
        
        return data
    
    def create(self, validated_data):
        user = self.context['request'].user
        
        # Calculer les frais (25%)
        frais = validated_data['montant'] * Decimal('0.25')
        montant_net = validated_data['montant'] - frais
        
        # Créer la transaction de retrait
        transaction = Transaction.objects.create(
            utilisateur=user,
            type_transaction='RETRAIT',
            montant=validated_data['montant'],
            frais=frais,
            montant_net=montant_net,
            statut='EN_ATTENTE',
            moyen_paiement=validated_data['moyen_paiement'],
            reference_paiement=validated_data['phone_number'],
            description=f"Demande de retrait - {validated_data['montant']} FCFA via {validated_data['moyen_paiement']}"
        )
        
        # Marquer le flag de retrait
        user.withdrawal_requested = True
        from django.utils import timezone
        user.withdrawal_requested_at = timezone.now()
        user.save()
        
        return transaction


class GradeUpgradeSerializer(serializers.Serializer):
    """Serializer pour la montée en grade avec utilisation partielle des commissions."""
    montant = serializers.DecimalField(max_digits=15, decimal_places=2, required=False)
    
    def validate_montant(self, value):
        if value is not None and value <= 0:
            raise serializers.ValidationError("Le montant doit être supérieur à 0.")
        return value
    
    def validate(self, data):
        user = self.context['request'].user
        
        if not user.is_activated:
            raise serializers.ValidationError("Votre compte doit être activé pour monter en grade.")
        
        if user.grade == 'GRAND_MAITRE':
            raise serializers.ValidationError("Vous êtes déjà au grade maximum.")
        
        # Obtenir le grade suivant et le montant minimum requis
        from accounts.grade_constants import get_next_grade, get_minimum_for_grade
        next_grade = get_next_grade(user.grade)
        minimum_required = get_minimum_for_grade(next_grade)
        
        if minimum_required is None:
            raise serializers.ValidationError("Grade suivant non disponible.")
        
        # Si aucun montant spécifié, utiliser le minimum requis
        montant = data.get('montant', minimum_required)
        
        if montant < minimum_required:
            raise serializers.ValidationError(
                f"Le montant minimum pour atteindre {get_grade_display_name(next_grade)} "
                f"est de {minimum_required:,.0f} FCFA."
            )
        
        if montant > user.commission_balance:
            raise serializers.ValidationError(
                f"Solde commissions insuffisant. Disponible: {user.commission_balance:,.0f} FCFA"
            )
        
        data['montant'] = montant
        data['next_grade'] = next_grade
        data['minimum_required'] = minimum_required
        
        return data
    
    def create(self, validated_data):
        user = self.context['request'].user
        montant = validated_data['montant']
        next_grade = validated_data['next_grade']
        
        # Effectuer la montée en grade
        user.commission_balance -= montant
        user.activation_amount += montant
        user.grade = next_grade
        user.save()
        
        return {
            'user': user,
            'montant_utilise': montant,
            'nouveau_grade': next_grade,
            'nouveau_grade_display': get_grade_display_name(next_grade),
        }


class TransactionSerializer(serializers.ModelSerializer):
    """Serializer pour les transactions."""
    utilisateur_details = serializers.SerializerMethodField()
    
    class Meta:
        model = Transaction
        fields = [
            'id', 'utilisateur', 'utilisateur_details', 'type_transaction',
            'montant', 'frais', 'montant_net', 'statut', 'moyen_paiement',
            'reference_paiement', 'description', 'date_transaction',
            'date_validation', 'transaction_originale', 'niveau_commission',
        ]
        read_only_fields = fields
    
    def get_utilisateur_details(self, obj):
        return {
            'id': obj.utilisateur.id,
            'email': obj.utilisateur.email,
            'full_name': obj.utilisateur.full_name,
            'grade': obj.utilisateur.grade,
            'grade_display': get_grade_display_name(obj.utilisateur.grade),
        }


class DistributionCommissionSerializer(serializers.ModelSerializer):
    """Serializer pour les distributions de commissions."""
    beneficiaire_details = serializers.SerializerMethodField()
    
    class Meta:
        model = DistributionCommission
        fields = [
            'id', 'beneficiaire', 'beneficiaire_details', 'transaction_source',
            'montant', 'pourcentage', 'niveau', 'est_paye', 'date_distribution',
        ]
        read_only_fields = fields
    
    def get_beneficiaire_details(self, obj):
        return {
            'id': obj.beneficiaire.id,
            'email': obj.beneficiaire.email,
            'full_name': obj.beneficiaire.full_name,
            'grade': obj.beneficiaire.grade,
        }