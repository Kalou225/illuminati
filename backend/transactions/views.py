from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Sum
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


class ActivationView(APIView):
    """Activer un compte avec un dépôt."""
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        serializer = ActivationSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        
        return Response({
            'message': f'Compte activé avec succès ! Grade : {result["grade_display"]}',
            'grade': result['grade'],
            'grade_display': result['grade_display'],
            'transaction': TransactionSerializer(result['transaction']).data,
            'commissions_distribuees': result['commissions_distribuees']
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
    """Monter de grade."""
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        serializer = GradeUpgradeSerializer(data={}, context={'request': request})
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        
        return Response({
            'message': f'Félicitations ! Vous êtes maintenant {result["nouveau_grade"]}',
            'ancien_grade': result['ancien_grade'],
            'nouveau_grade': result['nouveau_grade'],
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
        # Rafraîchir depuis la base de données
        user.refresh_from_db()
        
        # Total des dépôts validés
        total_depots = Transaction.objects.filter(
            utilisateur=user,
            type_transaction='DEPOT',
            statut='VALIDEE'
        ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
        
        # Total des retraits validés (montant NET après frais)
        total_retraits = Transaction.objects.filter(
            utilisateur=user,
            type_transaction='RETRAIT',
            statut='VALIDEE'
        ).aggregate(total=Sum('montant_net'))['total'] or Decimal('0')
        
        # Commissions (déjà dans commission_balance)
        total_commissions = user.commission_balance
        
        # Solde d'activation
        activation_amount = user.activation_amount
        
        # Portefeuille total
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
        # Vérifier si l'utilisateur est un admin (Grand Maître)
        if not request.user.is_staff or request.user.grade != 'GRAND_MAITRE':
            return Response(
                {'detail': 'Accès refusé. Réservé au Grand Maître.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Récupérer toutes les demandes en attente
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
        # Vérifier si l'utilisateur est un admin
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
            # Valider le retrait
            withdrawal.statut = 'VALIDEE'
            withdrawal.date_validation = timezone.now()
            withdrawal.save()
            
            # Déduire le montant des commissions de l'utilisateur
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
            # Rejeter le retrait
            withdrawal.statut = 'REJETEE'
            withdrawal.date_validation = timezone.now()
            withdrawal.save()
            
            # Réinitialiser le flag de retrait
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