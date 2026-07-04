from rest_framework import serializers
from decimal import Decimal
from .models import Transaction, DistributionCommission
from .services import CommissionService
from accounts.serializers import UserSerializer
from accounts.models import User
from accounts.grade_constants import get_grade_from_amount, get_grade_display_name


class TransactionSerializer(serializers.ModelSerializer):
    """Serializer pour les transactions."""
    utilisateur_details = UserSerializer(source='utilisateur', read_only=True)
    
    class Meta:
        model = Transaction
        fields = [
            'id', 'utilisateur', 'utilisateur_details',
            'type_transaction', 'montant', 'frais', 'montant_net',
            'moyen_paiement', 'reference_paiement', 'statut',
            'date_transaction', 'date_validation', 'description',
            'transaction_originale', 'niveau_commission'
        ]
        read_only_fields = ['id', 'date_transaction', 'frais', 'montant_net', 'statut']


class ActivationSerializer(serializers.Serializer):
    """Serializer pour activer un compte avec un montant."""
    montant = serializers.DecimalField(max_digits=15, decimal_places=2)
    moyen_paiement = serializers.ChoiceField(choices=Transaction.MOYEN_PAIEMENT_CHOICES)
    reference_paiement = serializers.CharField(required=False, allow_blank=True)
    
    def validate_montant(self, value):
        if value < Decimal('1'):
            raise serializers.ValidationError("Le montant minimum est de 1 FCFA.")
        return value
    
    def create(self, validated_data):
        utilisateur = self.context['request'].user
        
        # Ne pas permettre l'activation si déjà activé
        if utilisateur.is_activated:
            raise serializers.ValidationError("Votre compte est déjà activé.")
        
        montant = validated_data['montant']
        moyen_paiement = validated_data['moyen_paiement']
        reference_paiement = validated_data.get('reference_paiement', '')
        
        # Déterminer le grade selon le montant
        grade = get_grade_from_amount(montant)
        
        # Créer la transaction d'activation
        activation = Transaction.objects.create(
            utilisateur=utilisateur,
            type_transaction='DEPOT',
            montant=montant,
            frais=Decimal('0'),
            montant_net=montant,
            moyen_paiement= moyen_paiement,
            reference_paiement=reference_paiement,
            statut='VALIDEE',
            description=f"Activation du compte - Grade: {get_grade_display_name(grade)}"
        )
        
        # Activer le compte
        utilisateur.is_activated = True
        utilisateur.activation_amount = montant
        utilisateur.grade = grade
        utilisateur.save()
        
        # Débloquer les commissions en attente s'il y en a
        CommissionService.debloquer_commissions_en_attente(utilisateur)
        
        # Distribuer les commissions au parrain et à la branche
        commissions = CommissionService.distribuer_commissions(activation)
        
        return {
            'transaction': activation,
            'grade': grade,
            'grade_display': get_grade_display_name(grade),
            'commissions_distribuees': commissions
        }


class DepotSerializer(serializers.Serializer):
    """Serializer pour créer un dépôt (après activation)."""
    montant = serializers.DecimalField(max_digits=12, decimal_places=2)
    moyen_paiement = serializers.ChoiceField(choices=Transaction.MOYEN_PAIEMENT_CHOICES)
    reference_paiement = serializers.CharField(required=False, allow_blank=True)
    
    def validate_montant(self, value):
        if value <= 0:
            raise serializers.ValidationError("Le montant doit être supérieur à 0.")
        return value
    
    def create(self, validated_data):
        utilisateur = self.context['request'].user
        
        if not utilisateur.is_activated:
            raise serializers.ValidationError("Vous devez d'abord activer votre compte.")
        
        montant = validated_data['montant']
        
        # Créer la transaction de dépôt
        depot = Transaction.objects.create(
            utilisateur=utilisateur,
            type_transaction='DEPOT',
            montant=montant,
            frais=Decimal('0'),
            montant_net=montant,
            moyen_paiement=validated_data['moyen_paiement'],
            reference_paiement=validated_data.get('reference_paiement', ''),
            statut='VALIDEE',
            description=f"Dépôt via {validated_data['moyen_paiement']}"
        )
        
        return depot


class RetraitSerializer(serializers.Serializer):
    """Serializer pour créer un retrait."""
    montant = serializers.DecimalField(max_digits=12, decimal_places=2)
    moyen_paiement = serializers.ChoiceField(choices=Transaction.MOYEN_PAIEMENT_CHOICES)
    phone_number = serializers.CharField(max_length=15, required=True)
    
    def validate_montant(self, value):
        utilisateur = self.context['request'].user
        
        if value <= 0:
            raise serializers.ValidationError("Le montant doit être supérieur à 0.")
        
        if not utilisateur.is_activated:
            raise serializers.ValidationError("Votre compte n'est pas activé.")
        
        if value > utilisateur.commission_balance:
            raise serializers.ValidationError(
                f"Vous ne pouvez retirer que vos commissions. "
                f"Solde commissions: {utilisateur.commission_balance} FCFA"
            )
        
        if not utilisateur.can_withdraw():
            if utilisateur.withdrawal_requested:
                raise serializers.ValidationError("Vous avez déjà une demande de retrait en attente.")
            raise serializers.ValidationError("Vous ne pouvez retirer qu'une fois par mois.")
        
        return value
    
    def create(self, validated_data):
        utilisateur = self.context['request'].user
        montant = validated_data['montant']
        
        # Calculer les frais (25%)
        frais, montant_net = CommissionService.calculer_frais_retrait(montant)
        
        # Créer la transaction de retrait (en attente de validation)
        retrait = Transaction.objects.create(
            utilisateur=utilisateur,
            type_transaction='RETRAIT',
            montant=montant,
            frais=frais,
            montant_net=montant_net,
            moyen_paiement=validated_data['moyen_paiement'],
            reference_paiement=validated_data['phone_number'],
            statut='EN_ATTENTE',  # ← IMPORTANT : Statut EN_ATTENTE
            description=f"Retrait via {validated_data['moyen_paiement']} vers {validated_data['phone_number']} (frais: {frais} FCFA) - En attente de validation"
        )
        
        # Marquer l'utilisateur comme ayant une demande en attente
        from django.utils import timezone
        utilisateur.withdrawal_requested = True
        utilisateur.withdrawal_requested_at = timezone.now()
        utilisateur.save()
        
        return retrait

class GradeUpgradeSerializer(serializers.Serializer):
    """Serializer pour monter de grade."""
    
    def validate(self, data):
        utilisateur = self.context['request'].user
        
        if not utilisateur.is_activated:
            raise serializers.ValidationError("Votre compte n'est pas activé.")
        
        if not utilisateur.can_upgrade_grade():
            raise serializers.ValidationError(
                "Votre portefeuille n'atteint pas le seuil du grade supérieur."
            )
        
        return data
    
    def create(self, validated_data):
        utilisateur = self.context['request'].user
        
        # Monter d'un grade
        from accounts.grade_constants import get_next_grade, get_grade_display_name
        next_grade = get_next_grade(utilisateur.grade)
        
        if not next_grade:
            raise serializers.ValidationError("Vous avez atteint le grade maximum.")
        
        # Réinitialiser les commissions
        utilisateur.commission_balance = Decimal('0')
        utilisateur.grade = next_grade
        utilisateur.save()
        
        return {
            'ancien_grade': get_grade_display_name(utilisateur.grade),
            'nouveau_grade': get_grade_display_name(next_grade),
        }


class DistributionCommissionSerializer(serializers.ModelSerializer):
    """Serializer pour les distributions de commission."""
    beneficiaire_details = UserSerializer(source='beneficiaire', read_only=True)
    
    class Meta:
        model = DistributionCommission
        fields = [
            'id', 'transaction_source', 'beneficiaire', 'beneficiaire_details',
            'montant', 'pourcentage', 'niveau', 'date_distribution', 'est_paye'
        ]
        read_only_fields = ['id', 'date_distribution']