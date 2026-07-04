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
)

urlpatterns = [
    path('activation/', ActivationView.as_view(), name='activation'),
    path('depot/', DepotView.as_view(), name='depot'),
    path('retrait/', RetraitView.as_view(), name='retrait'),
    path('grade-upgrade/', GradeUpgradeView.as_view(), name='grade-upgrade'),
    path('transactions/', TransactionListView.as_view(), name='transactions-list'),
    path('transactions/<int:pk>/', TransactionDetailView.as_view(), name='transaction-detail'),
    path('commissions/', DistributionCommissionListView.as_view(), name='commissions-list'),
    path('balance/', BalanceView.as_view(), name='balance'),
    path('withdrawals/', WithdrawalRequestsView.as_view(), name='withdrawals-list'),
    path('withdrawals/<int:pk>/', ValidateWithdrawalView.as_view(), name='validate-withdrawal'),
]