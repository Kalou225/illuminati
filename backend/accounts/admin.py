from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User
from .grade_constants import get_grade_display_name
from django.utils import timezone


@admin.action(description='✓ Activer les comptes sélectionnés')
def activate_users(modeladmin, request, queryset):
    """Active manuellement les comptes sélectionnés."""
    activated_count = 0
    for user in queryset:
        if not user.is_activated:
            user.is_activated = True
            user.save()
            activated_count += 1
    
    if activated_count == 0:
        messages.info(request, 'Aucun compte à activer (déjà activés).')
    else:
        messages.success(request, f'{activated_count} compte(s) activé(s) avec succès !')


@admin.action(description='✗ Désactiver les comptes sélectionnés')
def deactivate_users(modeladmin, request, queryset):
    """Désactive les comptes sélectionnés."""
    deactivated_count = 0
    for user in queryset:
        if user.is_activated:
            user.is_activated = False
            user.save()
            deactivated_count += 1
    
    if deactivated_count == 0:
        messages.info(request, 'Aucun compte à désactiver.')
    else:
        messages.success(request, f'{deactivated_count} compte(s) désactivé(s).')


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    """Interface d'administration pour les utilisateurs."""
    list_display = [
        'email',
        'full_name',
        'phone_number',
        'grade',
        'is_activated',
        'activation_amount',
        'commission_balance',
        'get_wallet_total',
        'date_joined',
    ]
    list_filter = ['grade', 'is_activated', 'is_staff', 'date_joined']
    search_fields = ['email', 'full_name', 'phone_number', 'referral_code']
    ordering = ['-date_joined']
    readonly_fields = ['date_joined', 'last_login', 'get_wallet_total']
    actions = [activate_users, deactivate_users]
    
    fieldsets = (
        (None, {'fields': ('email', 'phone_number', 'password')}),
        ('Informations personnelles', {'fields': ('full_name', 'grade', 'sponsor', 'referral_code')}),
        ('Activation et Soldes', {
            'fields': ('is_activated', 'activation_amount', 'commission_balance', 'get_wallet_total'),
            'description': 'Le solde d\'activation détermine le grade. Les commissions sont retirables ou utilisables pour monter en grade.'
        }),
        ('Commissions en attente', {'fields': ('pending_commissions',)}),
        ('Retraits', {
            'fields': ('last_withdrawal_date', 'withdrawal_requested', 'withdrawal_requested_at'),
            'description': 'Gestion des retraits (1x/mois, frais 25%)'
        }),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Dates importantes', {'fields': ('date_joined', 'last_login')}),
    )
    
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'phone_number', 'full_name', 'password1', 'password2'),
        }),
    )
    
    def get_wallet_total(self, obj):
        """Affiche le total du portefeuille."""
        total = obj.get_wallet_total()
        return f"{total:,.0f} FCFA"
    get_wallet_total.short_description = 'Portefeuille Total'