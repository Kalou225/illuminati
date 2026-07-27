from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Sum
from django.utils import timezone
from decimal import Decimal

from .models import Transaction, DistributionCommission
from .serializers import (
    TransactionSerializer, 
    DistributionCommissionSerializer,
    DepotSerializer,
    RetraitSerializer,
    ActivationSerializer,
    GradeUpgradeSerializer
)
from accounts.models import User  # ⭐ IMPORT NÉCESSAIRE
from accounts.grade_constants import get_grade_display_name


class ActivationView(APIView):
    """Créer une demande d'activation (en attente de validation admin)."""
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        serializer = ActivationSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        transaction = serializer.save()
        
        return Response({
            'message': 'Demande d\'activation soumise. En attente de validation par l\'administrateur.',
            'transaction': TransactionSerializer(transaction).data
        }, status=status.HTTP_201_CREATED)


class DepotView(APIView):
    """Créer un dépôt (après activation)."""
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        serializer = DepotSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        depot = serializer.save()
        
        return Response({
            'message': 'Dépôt effectué avec succès',
            'transaction': TransactionSerializer(depot).data
        }, status=status.HTTP_201_CREATED)


class RetraitView(APIView):
    """Créer une demande de retrait (en attente de validation)."""
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        serializer = RetraitSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        retrait = serializer.save()
        
        return Response({
            'message': 'Demande de retrait soumise. Validation sous 24h.',
            'transaction': TransactionSerializer(retrait).data
        }, status=status.HTTP_201_CREATED)


class GradeUpgradeView(APIView):
    """Montée en grade manuelle avec utilisation partielle des commissions."""
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        serializer = GradeUpgradeSerializer(
            data=request.data,
            context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        
        return Response({
            'message': f'Félicitations ! Vous êtes maintenant {result["nouveau_grade_display"]} !',
            'nouveau_grade': result['nouveau_grade'],
            'nouveau_grade_display': result['nouveau_grade_display'],
            'montant_utilise': float(result['montant_utilise']),
            'nouveau_solde_activation': float(result['user'].activation_amount),
            'nouveau_solde_commissions': float(result['user'].commission_balance),
            'nouveau_pourcentage_commission': float(result['user'].get_commission_percentage()),
        }, status=status.HTTP_200_OK)


class TransactionListView(generics.ListAPIView):
    """Lister toutes les transactions de l'utilisateur connecté."""
    serializer_class = TransactionSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return Transaction.objects.filter(utilisateur=self.request.user).order_by('-date_transaction')


class TransactionDetailView(generics.RetrieveAPIView):
    """Voir le détail d'une transaction."""
    serializer_class = TransactionSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return Transaction.objects.filter(utilisateur=self.request.user)


class DistributionCommissionListView(generics.ListAPIView):
    """Lister les commissions reçues par l'utilisateur."""
    serializer_class = DistributionCommissionSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return DistributionCommission.objects.filter(beneficiaire=self.request.user)


class BalanceView(APIView):
    """Calculer le solde réel de l'utilisateur."""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        user = request.user
        user.refresh_from_db()
        
        total_depots = Transaction.objects.filter(
            utilisateur=user,
            type_transaction='DEPOT',
            statut='VALIDEE'
        ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
        
        total_activations = Transaction.objects.filter(
            utilisateur=user,
            type_transaction='ACTIVATION',
            statut='VALIDEE'
        ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
        
        total_retraits = Transaction.objects.filter(
            utilisateur=user,
            type_transaction='RETRAIT',
            statut='VALIDEE'
        ).aggregate(total=Sum('montant_net'))['total'] or Decimal('0')
        
        total_commissions = user.commission_balance
        activation_amount = user.activation_amount
        wallet_total = activation_amount + total_commissions
        
        return Response({
            'solde': float(wallet_total),
            'activation_amount': float(activation_amount),
            'commission_balance': float(total_commissions),
            'total_depots': float(total_depots),
            'total_retraits': float(total_retraits),
            'is_activated': user.is_activated,
            'grade': user.grade,
            'can_withdraw': user.can_withdraw(),
            'can_upgrade': user.can_upgrade_grade(),
        })


class WithdrawalRequestsView(APIView):
    """Lister toutes les demandes de retrait en attente (Admin uniquement)."""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        if not request.user.is_staff or request.user.grade != 'GRAND_MAITRE':
            return Response(
                {'detail': 'Accès refusé. Réservé au Grand Maître.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        withdrawals = Transaction.objects.filter(
            type_transaction='RETRAIT',
            statut='EN_ATTENTE'
        ).select_related('utilisateur').order_by('-date_transaction')
        
        return Response({
            'count': withdrawals.count(),
            'results': TransactionSerializer(withdrawals, many=True).data
        })


class ValidateWithdrawalView(APIView):
    """Valider ou rejeter une demande de retrait (Admin uniquement)."""
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request, pk):
        if not request.user.is_staff or request.user.grade != 'GRAND_MAITRE':
            return Response(
                {'detail': 'Accès refusé. Réservé au Grand Maître.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            withdrawal = Transaction.objects.get(
                pk=pk,
                type_transaction='RETRAIT',
                statut='EN_ATTENTE'
            )
        except Transaction.DoesNotExist:
            return Response(
                {'detail': 'Demande de retrait non trouvée.'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        action = request.data.get('action')
        
        if action == 'approve':
            withdrawal.statut = 'VALIDEE'
            withdrawal.date_validation = timezone.now()
            withdrawal.save()
            
            user = withdrawal.utilisateur
            user.commission_balance -= withdrawal.montant
            user.last_withdrawal_date = timezone.now()
            user.withdrawal_requested = False
            user.save()
            
            return Response({
                'message': 'Retrait validé avec succès.',
                'transaction': TransactionSerializer(withdrawal).data
            })
        
        elif action == 'reject':
            withdrawal.statut = 'REJETEE'
            withdrawal.date_validation = timezone.now()
            withdrawal.save()
            
            user = withdrawal.utilisateur
            user.withdrawal_requested = False
            user.save()
            
            return Response({
                'message': 'Retrait rejeté.',
                'transaction': TransactionSerializer(withdrawal).data
            })
        
        else:
            return Response(
                {'detail': 'Action invalide. Utilisez "approve" ou "reject".'},
                status=status.HTTP_400_BAD_REQUEST
            )


class NetworkView(APIView):
    """Voir son réseau complet (toute l'arborescence de filleuls)."""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        user = request.user
        
        # Récupérer TOUS les descendants (récursif)
        all_descendants = self._get_all_descendants(user)
        
        # Statistiques
        total_descendants = len(all_descendants)
        total_activated = sum(1 for u in all_descendants if u.is_activated)
        total_pending = total_descendants - total_activated
        
        # Calculer le total des commissions générées par tout le réseau
        total_commissions_generated = Transaction.objects.filter(
            transaction_originale__utilisateur__in=all_descendants,
            type_transaction='COMMISSION',
            utilisateur=user
        ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
        
        # Données de tous les descendants
        descendants_data = []
        for descendant in all_descendants:
            niveau = self._get_level(user, descendant)
            
            total_depots = Transaction.objects.filter(
                utilisateur=descendant,
                type_transaction__in=['DEPOT', 'ACTIVATION'],
                statut='VALIDEE'
            ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
            
            commissions_generees = Transaction.objects.filter(
                transaction_originale__utilisateur=descendant,
                type_transaction='COMMISSION',
                utilisateur=user
            ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
            
            descendants_data.append({
                'id': descendant.id,
                'email': descendant.email,
                'full_name': descendant.full_name,
                'phone_number': descendant.phone_number,
                'grade': descendant.grade,
                'grade_display': get_grade_display_name(descendant.grade),
                'referral_code': descendant.referral_code,
                'date_joined': descendant.date_joined,
                'is_activated': descendant.is_activated,
                'niveau': niveau,
                'wallet_total': float(descendant.get_wallet_total()),
                'total_depots': float(total_depots),
                'commissions_generees': float(commissions_generees),
            })
        
        return Response({
            'total_descendants': total_descendants,
            'total_activated': total_activated,
            'total_pending': total_pending,
            'total_commissions_generated': float(total_commissions_generated),
            'descendants': descendants_data,
        })
    
    def _get_all_descendants(self, user):
        """Récupère tous les descendants (filleuls directs et indirects) de manière récursive."""
        descendants = []
        queue = list(User.objects.filter(sponsor=user))
        
        while queue:
            current = queue.pop(0)
            descendants.append(current)
            queue.extend(User.objects.filter(sponsor=current))
        
        return descendants
    
    def _get_level(self, root_user, descendant):
        """Calcule le niveau d'un descendant dans l'arborescence."""
        level = 0
        current = descendant
        
        while current.sponsor and current.sponsor != root_user:
            level += 1
            current = current.sponsor
        
        return level + 1

class MesTransactionsView(APIView):
    """Liste uniquement les transactions personnelles (hors commissions)."""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        # Filtrer : DEPOT, RETRAIT, ACTIVATION (exclure COMMISSION)
        transactions = Transaction.objects.filter(
            utilisateur=request.user,
            type_transaction__in=['DEPOT', 'RETRAIT', 'ACTIVATION']
        ).order_by('-date_transaction')
        
        return Response({
            'count': transactions.count(),
            'results': TransactionSerializer(transactions, many=True).data
        })


class MesCommissionsView(APIView):
    """Liste uniquement les commissions reçues."""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        # Filtrer : uniquement les COMMISSIONS
        commissions = Transaction.objects.filter(
            utilisateur=request.user,
            type_transaction='COMMISSION'
        ).order_by('-date_transaction')
        
        # Calculer le total des commissions reçues
        total_commissions = commissions.aggregate(
            total=Sum('montant')
        )['total'] or Decimal('0')
        
        return Response({
            'count': commissions.count(),
            'total': float(total_commissions),
            'results': TransactionSerializer(commissions, many=True).data
        })