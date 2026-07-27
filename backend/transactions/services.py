from decimal import Decimal
from django.db import transaction
from django.utils import timezone
from .models import Transaction, DistributionCommission
from accounts.models import User
from accounts.grade_constants import get_grade_from_amount


class CommissionService:
    """Service pour calculer et distribuer les commissions selon la logique dégressive."""
    
    # Pourcentage réservé à la branche directe
    BRANCH_PERCENTAGE = Decimal('20')
    
    # Poids de chaque grade pour la distribution dégressive
    # Plus le grade est élevé, plus le poids est grand
    GRADE_WEIGHTS = {
        'APPRENTI': 1,
        'COMPAGNON_N3': 2,
        'COMPAGNON_N2': 3,
        'COMPAGNON_N1': 4,
        'MAITRE_N3': 5,
        'MAITRE_N2': 6,
        'MAITRE_N1': 7,
        'GRAND_MAITRE': 0,  # Exclu de la répartition (reçoit le reste)
    }
    
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
            'GRAND_MAITRE': Decimal('0'),
        }
        return percentages.get(user.grade, Decimal('0'))
    
    @staticmethod
    def _get_grand_maitre():
        """Retourne le Grand Maître (fondateur)."""
        return User.objects.filter(grade='GRAND_MAITRE', is_staff=True).first()
    
    @staticmethod
    def _get_branch_sponsors(user):
        """
        Retourne la liste de tous les parrains de la branche directe (du plus proche au plus éloigné).
        Exclut le Grand Maître.
        """
        grand_maitre = CommissionService._get_grand_maitre()
        sponsors = []
        current = user
        
        while current and current.sponsor:
            parrain = current.sponsor
            
            # Si on atteint le Grand Maître, on s'arrête
            if parrain == grand_maitre:
                break
            
            sponsors.append(parrain)
            current = parrain
        
        return sponsors
    
    @staticmethod
    @transaction.atomic
    def distribuer_commissions(activation_transaction):
        """
        Distribue les commissions lors d'un dépôt/activation.
        
        Règles :
        - Parrain direct : 2% à 8% selon son grade
        - Branche directe : 20% réparti de manière dégressive selon les grades
          (plus le grade est élevé, plus on reçoit)
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
            # Ajouter au solde de commissions du parrain
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
                description=f"Commission parrain direct ({pourcentage_parrain}%) sur dépôt de {utilisateur.full_name}"
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
        
        # 2. Branche directe (20%) - répartition dégressive selon les grades
        montant_branche = (montant * CommissionService.BRANCH_PERCENTAGE) / Decimal('100')
        
        # Récupérer tous les parrains de la branche (excluant le GM)
        sponsors_branche = CommissionService._get_branch_sponsors(utilisateur)
        
        if sponsors_branche and montant_branche > 0:
            # Calculer les poids de chaque parrain selon son grade
            poids_total = 0
            poids_par_parrain = []
            
            for sponsor in sponsors_branche:
                poids = CommissionService.GRADE_WEIGHTS.get(sponsor.grade, 1)
                poids_par_parrain.append((sponsor, poids))
                poids_total += poids
            
            # Distribuer proportionnellement aux poids
            for sponsor, poids in poids_par_parrain:
                if poids_total > 0:
                    part = (montant_branche * Decimal(poids)) / Decimal(poids_total)
                else:
                    part = Decimal('0')
                
                if sponsor.is_activated:
                    sponsor.commission_balance += part
                    sponsor.save()
                    
                    Transaction.objects.create(
                        utilisateur=sponsor,
                        type_transaction='COMMISSION',
                        montant=part,
                        frais=Decimal('0'),
                        montant_net=part,
                        statut='VALIDEE',
                        transaction_originale=activation_transaction,
                        niveau_commission=2,
                        description=f"Commission branche directe ({sponsor.grade}) sur dépôt de {utilisateur.full_name}"
                    )
                    
                    commissions_distribuees.append({
                        'beneficiaire': sponsor.full_name,
                        'montant': float(part),
                        'pourcentage': float((part / montant) * 100),
                        'type': f'Branche directe ({sponsor.grade})'
                    })
                else:
                    # Parrain non activé → sa part va au Grand Maître
                    pass
        
        # 3. Le reste va au Grand Maître
        total_distribue_branche = sum(
            float(c['montant']) for c in commissions_distribuees 
            if c['type'].startswith('Branche directe')
        )
        montant_reste = montant - montant_parrain - Decimal(str(total_distribue_branche))
        
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
                description=f"Commission Grand Maître (reste) sur dépôt de {utilisateur.full_name}"
            )
            
            commissions_distribuees.append({
                'beneficiaire': grand_maitre.full_name,
                'montant': float(montant_reste),
                'pourcentage': float((montant_reste / montant) * 100),
                'type': 'Grand Maître (reste)'
            })
        
        return commissions_distribuees
    
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