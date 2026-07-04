from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User

@admin.register(User)
class UserAdmin(BaseUserAdmin):
    """Interface d'administration pour les utilisateurs."""
    list_display = [
        'email',
        'full_name',
        'phone_number',
        'grade',
        'is_activated',
        'wallet_total_display',
        'date_joined',
    ]
    list_filter = ['grade', 'is_activated', 'is_staff', 'date_joined']
    search_fields = ['email', 'full_name', 'phone_number']
    ordering = ['-date_joined']
    readonly_fields = ['date_joined', 'last_login']
    
    fieldsets = (
        (None, {'fields': ('email', 'phone_number', 'password')}),
        ('Informations personnelles', {'fields': ('full_name', 'grade')}),
        ('Activation', {'fields': ('is_activated', 'activation_amount', 'commission_balance', 'pending_commissions')}),
        ('Retraits', {'fields': ('last_withdrawal_date', 'withdrawal_requested', 'withdrawal_requested_at')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Dates importantes', {'fields': ('date_joined', 'last_login')}),
    )
    
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'phone_number', 'full_name', 'password1', 'password2'),
        }),
    )
    
    def wallet_total_display(self, obj):
        total = obj.get_wallet_total()
        return f"{total:,.0f} FCFA"
    wallet_total_display.short_description = 'Portefeuille Total'