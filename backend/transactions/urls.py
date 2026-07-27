from django.urls import path
from .views import (
    ActivationView,
    DepotView,
    RetraitView,
    GradeUpgradeView,
    TransactionListView,
    TransactionDetailView,
    DistributionCommissionListView,
    BalanceView,
    WithdrawalRequestsView,
    ValidateWithdrawalView,
    NetworkView,
    MesTransactionsView,  # ⭐ NOUVELLE VUE
    MesCommissionsView,    # ⭐ NOUVELLE VUE
)

urlpatterns = [
    path('activation/', ActivationView.as_view(), name='activation'),
    path('depot/', DepotView.as_view(), name='depot'),
    path('retrait/', RetraitView.as_view(), name='retrait'),
    path('grade-upgrade/', GradeUpgradeView.as_view(), name='grade-upgrade'),
    
    path('transactions/', TransactionListView.as_view(), name='transactions'),
    path('transactions/<int:pk>/', TransactionDetailView.as_view(), name='transaction-detail'),
    
    path('commissions/', DistributionCommissionListView.as_view(), name='commissions'),
    
    path('balance/', BalanceView.as_view(), name='balance'),
    
    path('withdrawal-requests/', WithdrawalRequestsView.as_view(), name='withdrawal-requests'),
    path('withdrawal-requests/<int:pk>/validate/', ValidateWithdrawalView.as_view(), name='validate-withdrawal'),
    
    path('network/', NetworkView.as_view(), name='network'),
    
    # ⭐ NOUVELLES ROUTES POUR L'HISTORIQUE SÉPARÉ
    path('mes-transactions/', MesTransactionsView.as_view(), name='mes-transactions'),
    path('mes-commissions/', MesCommissionsView.as_view(), name='mes-commissions'),
]