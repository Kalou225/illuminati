from decimal import Decimal
from django.db import transaction
from django.utils import timezone
from .models import Transaction, DistributionCommission
from accounts.models import User
from accounts.grade_constants import get_grade_from_amount


class CommissionService:
    """Service pour calculer et distribuer les commissions selon la nouvelle logique."""
    
    # Pourcentage réservé à la branche directe (réparti jusqu'au Grand Maître)
    BRANCH_PERCENTAGE = Decimal('20')
    
    @staticmethod
    def _get_commission_percentage(user):
        """Retourne le pourcentage de commission selon le grade de l'utilisateur."""
        if not user or not user.is_activated:
            return Decimal('0')
        
        percentages = {
            'APPRENTI': Decimal('2'),
            'COMPAGNON_N3': Decimal('3'),
            'COMPAGNON_N2': Decimal('4'),
            'COMPAGNON_N1': Decimal('5'),
            'MAITRE_N3': Decimal('6'),
            'MAITRE_N2': Decimal('7'),
            'MAITRE_N1': Decimal('8'),
            'GRAND_MAITRE': Decimal('0'),  # Le GM ne reçoit pas de commission de parrainage direct
        }
        return percentages.get(user.grade, Decimal('0'))
    
    @staticmethod
    def _get_grand_maitre():
        """Retourne le Grand Maître (fondateur)."""
        return User.objects.filter(grade='GRAND_MAITRE', is_staff=True).first()
    
    @staticmethod
    @transaction.atomic
    def distribuer_commissions(activation_transaction):
        """
        Distribue les commissions lors de l'activation d'un compte.
        
        Règles :
        - Parrain direct : 2% à 8% selon son grade
        - Branche directe : 20% réparti jusqu'au Grand Maître
        - Reste : au Grand Maître
        - Si parrain non activé : sa part va au Grand Maître
        """
        utilisateur = activation_transaction.utilisateur
        montant = activation_transaction.montant
        
        commissions_distribuees = []
        grand_maitre = CommissionService._get_grand_maitre()
        
        if not grand_maitre:
            raise Exception("Aucun Grand Maître trouvé dans le système")
        
        # 1. Commission du parrain direct (selon son grade)
        parrain_direct = utilisateur.sponsor
        pourcentage_parrain = CommissionService._get_commission_percentage(parrain_direct)
        montant_parrain = (montant * pourcentage_parrain) / Decimal('100')
        
        if parrain_direct and parrain_direct.is_activated:
            # Ajouter au compteur de commissions du parrain
            parrain_direct.commission_balance += montant_parrain
            parrain_direct.save()
            
            # Créer la transaction de commission
            Transaction.objects.create(
                utilisateur=parrain_direct,
                type_transaction='COMMISSION',
                montant=montant_parrain,
                frais=Decimal('0'),
                montant_net=montant_parrain,
                statut='VALIDEE',
                transaction_originale=activation_transaction,
                niveau_commission=1,
                description=f"Commission parrain direct ({pourcentage_parrain}%) sur activation de {utilisateur.full_name}"
            )
            
            commissions_distribuees.append({
                'beneficiaire': parrain_direct.full_name,
                'montant': float(montant_parrain),
                'pourcentage': float(pourcentage_parrain),
                'type': 'Parrain direct'
            })
        else:
            # Parrain non activé → commission va au Grand Maître
            montant_parrain = Decimal('0')
        
        # 2. Branche directe (20%) - réparti jusqu'au Grand Maître
        montant_branche = (montant * CommissionService.BRANCH_PERCENTAGE) / Decimal('100')
        
        # Parcourir la chaîne de parrainage pour distribuer les 20%
        utilisateur_actuel = utilisateur
        niveau = 2
        montant_restant_branche = montant_branche
        
        while montant_restant_branche > 0 and utilisateur_actuel and utilisateur_actuel.sponsor:
            parrain_niveau = utilisateur_actuel.sponsor
            
            # Si on atteint le Grand Maître, il prend tout le reste
            if parrain_niveau == grand_maitre:
                if parrain_niveau.is_activated:
                    parrain_niveau.commission_balance += montant_restant_branche
                    parrain_niveau.save()
                    
                    Transaction.objects.create(
                        utilisateur=parrain_niveau,
                        type_transaction='COMMISSION',
                        montant=montant_restant_branche,
                        frais=Decimal('0'),
                        montant_net=montant_restant_branche,
                        statut='VALIDEE',
                        transaction_originale=activation_transaction,
                        niveau_commission=niveau,
                        description=f"Commission branche directe (reste) sur activation de {utilisateur.full_name}"
                    )
                    
                    commissions_distribuees.append({
                        'beneficiaire': parrain_niveau.full_name,
                        'montant': float(montant_restant_branche),
                        'pourcentage': float((montant_restant_branche / montant) * 100),
                        'type': f'Grand Maître (reste branche)'
                    })
                
                montant_restant_branche = Decimal('0')
                break
            
            # Distribution égale entre les niveaux de la branche
            # On compte combien de niveaux jusqu'au GM
            niveaux_restants = CommissionService._count_levels_to_grand_maitre(parrain_niveau)
            
            if niveaux_restants > 0:
                part_niveau = montant_restant_branche / Decimal(niveaux_restants + 1)
            else:
                part_niveau = montant_restant_branche
            
            if parrain_niveau.is_activated:
                parrain_niveau.commission_balance += part_niveau
                parrain_niveau.save()
                
                Transaction.objects.create(
                    utilisateur=parrain_niveau,
                    type_transaction='COMMISSION',
                    montant=part_niveau,
                    frais=Decimal('0'),
                    montant_net=part_niveau,
                    statut='VALIDEE',
                    transaction_originale=activation_transaction,
                    niveau_commission=niveau,
                    description=f"Commission branche directe (niveau {niveau}) sur activation de {utilisateur.full_name}"
                )
                
                commissions_distribuees.append({
                    'beneficiaire': parrain_niveau.full_name,
                    'montant': float(part_niveau),
                    'pourcentage': float((part_niveau / montant) * 100),
                    'type': f'Branche directe (niveau {niveau})'
                })
            
            montant_restant_branche -= part_niveau
            utilisateur_actuel = parrain_niveau
            niveau += 1
        
        # 3. Le reste va au Grand Maître
        total_distribue = montant_parrain + montant_branche
        montant_reste = montant - total_distribue
        
        if montant_reste > 0 and grand_maitre.is_activated:
            grand_maitre.commission_balance += montant_reste
            grand_maitre.save()
            
            Transaction.objects.create(
                utilisateur=grand_maitre,
                type_transaction='COMMISSION',
                montant=montant_reste,
                frais=Decimal('0'),
                montant_net=montant_reste,
                statut='VALIDEE',
                transaction_originale=activation_transaction,
                niveau_commission=0,
                description=f"Commission Grand Maître (reste) sur activation de {utilisateur.full_name}"
            )
            
            commissions_distribuees.append({
                'beneficiaire': grand_maitre.full_name,
                'montant': float(montant_reste),
                'pourcentage': float((montant_reste / montant) * 100),
                'type': 'Grand Maître (reste)'
            })
        
        return commissions_distribuees
    
    @staticmethod
    def _count_levels_to_grand_maitre(user):
        """Compte le nombre de niveaux jusqu'au Grand Maître."""
        grand_maitre = CommissionService._get_grand_maitre()
        count = 0
        current = user
        
        while current and current.sponsor and current.sponsor != grand_maitre:
            count += 1
            current = current.sponsor
        
        return count
    
    @staticmethod
    def calculer_frais_retrait(montant):
        """Calcule les frais de retrait (25%)."""
        frais = (montant * Decimal('25')) / Decimal('100')
        montant_net = montant - frais
        return frais, montant_net
    
    @staticmethod
    def debloquer_commissions_en_attente(user):
        """Débloque les commissions en attente quand un utilisateur active son compte."""
        if user.pending_commissions > 0:
            user.commission_balance += user.pending_commissions
            user.pending_commissions = Decimal('0')
            user.save()
            return True
        return False