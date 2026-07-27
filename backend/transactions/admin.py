from django.contrib import admin, messages
from django.utils.html import format_html
from django.urls import reverse
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal

from .models import Transaction, DistributionCommission
from accounts.models import User
from accounts.grade_constants import get_grade_display_name
from transactions.services import CommissionService


# ============ ACTIONS POUR LES TRANSACTIONS ============

@admin.action(description='✓ Valider les activations sélectionnées (et distribuer commissions)')
def validate_activations(modeladmin, request, queryset):
    """Valide les demandes d'activation, attribue le grade et distribue les commissions."""
    validated_count = 0
    
    for transaction in queryset.filter(statut='EN_ATTENTE', type_transaction='ACTIVATION'):
        user = transaction.utilisateur
        
        # 1. Mettre à jour le solde d'activation et activer le compte
        user.activation_amount += transaction.montant
        user.is_activated = True
        
        # Le grade sera automatiquement mis à jour par la méthode save() du modèle User
        user.save()
        
        # 2. Valider la transaction
        transaction.statut = 'VALIDEE'
        transaction.date_validation = timezone.now()
        transaction.description = f"Activation validée - Grade: {get_grade_display_name(user.grade)}"
        transaction.save()
        
        # 3. ⭐ DISTRIBUER LES COMMISSIONS AUTOMATIQUEMENT
        try:
            commissions = CommissionService.distribuer_commissions(transaction)
            messages.success(
                request,
                f'✅ Activation de {user.full_name} validée. Grade: {get_grade_display_name(user.grade)}. {len(commissions)} commission(s) distribuée(s).'
            )
        except Exception as e:
            messages.error(
                request,
                f'⚠️ Activation de {user.full_name} validée, mais erreur distribution commissions: {str(e)}'
            )
        
        validated_count += 1
    
    if validated_count == 0:
        messages.info(request, 'Aucune demande d\'activation en attente à valider.')
    else:
        messages.success(request, f'{validated_count} activation(s) traitée(s) avec succès.')


@admin.action(description='✗ Rejeter les activations sélectionnées')
def reject_activations(modeladmin, request, queryset):
    """Rejette les demandes d'activation."""
    rejected_count = 0
    
    for transaction in queryset.filter(statut='EN_ATTENTE', type_transaction='ACTIVATION'):
        transaction.statut = 'REJETEE'
        transaction.date_validation = timezone.now()
        transaction.save()
        rejected_count += 1
    
    if rejected_count == 0:
        messages.info(request, 'Aucune demande d\'activation en attente à rejeter.')
    else:
        messages.success(request, f'{rejected_count} activation(s) rejetée(s).')


@admin.action(description='⏰ Vérifier et rejeter les retraits expirés (>48h)')
def check_expired_withdrawals(modeladmin, request, queryset):
    """Marque automatiquement les retraits non validés après 48h."""
    expired_count = 0
    for withdrawal in queryset.filter(statut='EN_ATTENTE', type_transaction='RETRAIT'):
        time_since_request = timezone.now() - withdrawal.date_transaction
        
        if time_since_request > timedelta(hours=48):
            withdrawal.statut = 'REJETEE'
            withdrawal.description = f"Rejet automatique - Délai de 48h dépassé"
            withdrawal.save()
            
            # Réinitialiser le flag pour permettre à l'utilisateur de refaire une demande
            user = withdrawal.utilisateur
            user.withdrawal_requested = False
            user.save()
            
            expired_count += 1
    
    if expired_count == 0:
        messages.info(request, 'Aucun retrait expiré.')
    else:
        messages.success(request, f'{expired_count} retrait(s) expiré(s) rejeté(s) automatiquement.')


# ============ ADMIN TRANSACTION ============

@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    """Interface d'administration pour les transactions."""
    list_display = [
        'id',
        'utilisateur_link',
        'type_transaction_colored',
        'montant_display',
        'frais_display',
        'montant_net_display',
        'numero_paiement',  # ⭐ NOUVEAU : Affiche le numéro dans la liste
        'statut_colored',
        'date_transaction',
        'validation_actions',
    ]
    list_filter = ['type_transaction', 'statut', 'date_transaction', 'moyen_paiement'] # ⭐ AJOUT : Filtrer par MTN/Wave/Moov
    search_fields = ['utilisateur__email', 'utilisateur__full_name', 'reference_paiement']
    readonly_fields = ['date_transaction', 'date_validation', 'numero_paiement_detail'] # ⭐ AJOUT
    ordering = ['-date_transaction']
    list_per_page = 20
    actions = [validate_activations, reject_activations, check_expired_withdrawals] # ⭐ AJOUT de l'action 48h
    
    def utilisateur_link(self, obj):
        url = reverse('admin:accounts_user_change', args=[obj.utilisateur.pk])
        return format_html('<a href="{}">{}</a>', url, obj.utilisateur.full_name)
    utilisateur_link.short_description = 'Utilisateur'
    
    def type_transaction_colored(self, obj):
        colors = {
            'DEPOT': 'green',
            'RETRAIT': 'red',
            'COMMISSION': 'blue',
            'ACTIVATION': 'purple',
        }
        color = colors.get(obj.type_transaction, 'black')
        return format_html(
            '<span style="color: {}; font-weight: bold;">{}</span>',
            color,
            obj.get_type_transaction_display()
        )
    type_transaction_colored.short_description = 'Type'
    
    def montant_display(self, obj):
        return f"{obj.montant:,.0f} FCFA"
    montant_display.short_description = 'Montant'
    
    def frais_display(self, obj):
        return f"{obj.frais:,.0f} FCFA"
    frais_display.short_description = 'Frais'
    
    def montant_net_display(self, obj):
        return f"{obj.montant_net:,.0f} FCFA"
    montant_net_display.short_description = 'Montant Net'
    
    # ⭐ NOUVEAU : Affichage du numéro dans la liste
    def numero_paiement(self, obj):
        if obj.type_transaction == 'RETRAIT' and obj.reference_paiement:
            return format_html(
                '<span style="font-weight: bold; color: #d32f2f; font-size: 14px;">📱 {}</span>',
                obj.reference_paiement
            )
        return '-'
    numero_paiement.short_description = 'Numéro de Paiement'
    
    def statut_colored(self, obj):
        colors = {
            'EN_ATTENTE': 'orange',
            'VALIDEE': 'green',
            'REJETEE': 'red',
        }
        color = colors.get(obj.statut, 'gray')
        return format_html(
            '<span style="color: {}; font-weight: bold;">{}</span>',
            color,
            obj.get_statut_display()
        )
    statut_colored.short_description = 'Statut'
    
    def validation_actions(self, obj):
        if obj.type_transaction == 'RETRAIT' and obj.statut == 'EN_ATTENTE':
            validate_url = reverse('admin:validate-withdrawal', args=[obj.pk, 'approve'])
            reject_url = reverse('admin:validate-withdrawal', args=[obj.pk, 'reject'])
            
            return format_html(
                '<a href="{}" style="margin-right: 10px; padding: 5px 10px; background: green; color: white; text-decoration: none; border-radius: 3px;">✓ Valider</a>'
                '<a href="{}" style="padding: 5px 10px; background: red; color: white; text-decoration: none; border-radius: 3px;">✗ Rejeter</a>',
                validate_url,
                reject_url
            )
        elif obj.statut == 'VALIDEE':
            return format_html('<span style="color: green;">✓ Validée le {}</span>', 
                             obj.date_validation.strftime('%d/%m/%Y %H:%M') if obj.date_validation else '-')
        elif obj.statut == 'REJETEE':
            return format_html('<span style="color: red;">✗ Rejetée le {}</span>', 
                             obj.date_validation.strftime('%d/%m/%Y %H:%M') if obj.date_validation else '-')
        return '-'
    validation_actions.short_description = 'Actions'
    
    # ⭐ NOUVEAU : Organisation des champs dans le détail
    fieldsets = (
        ('Informations Générales', {
            'fields': ('utilisateur', 'type_transaction', 'statut', 'description')
        }),
        ('Montants', {
            'fields': ('montant', 'frais', 'montant_net')
        }),
        ('Informations de Paiement', {
            'fields': ('numero_paiement_detail', 'moyen_paiement', 'reference_paiement'),
            'description': '⚠️ Utilisez ces informations pour effectuer le transfert d\'argent au bénéficiaire.'
        }),
        ('Dates et Validation', {
            'fields': ('date_transaction', 'date_validation')
        }),
    )
    
    # ⭐ NOUVEAU : Affichage détaillé et coloré du numéro dans la fiche
    def numero_paiement_detail(self, obj):
        if obj.type_transaction == 'RETRAIT' and obj.reference_paiement:
            return format_html(
                '<div style="background: #ffebee; padding: 20px; border-radius: 8px; border: 2px solid #ef9a9a; margin-bottom: 20px;">'
                '<strong style="color: #c62828; font-size: 20px;">📱 Numéro pour le transfert : {}</strong><br><br>'
                '<span style="color: #555; font-size: 15px;">Moyen de paiement : <strong style="color: #333;">{}</strong></span><br>'
                '<span style="color: #555; font-size: 15px;">Montant net à transférer : <strong style="color: #2e7d32; font-size: 18px;">{} FCFA</strong></span>'
                '</div>',
                obj.reference_paiement,
                obj.get_moyen_paiement_display(),
                f"{obj.montant_net:,.0f}"
            )
        return "Aucun numéro de paiement requis pour cette transaction."
    numero_paiement_detail.short_description = 'Informations de Paiement (Admin)'
    
    def get_urls(self):
        from django.urls import path
        urls = super().get_urls()
        custom_urls = [
            path(
                '<int:pk>/validate/<str:action>/',
                self.admin_site.admin_view(self.validate_withdrawal),
                name='validate-withdrawal',
            ),
        ]
        return custom_urls + urls
    
    def validate_withdrawal(self, request, pk, action):
        from django.http import HttpResponseRedirect
        from django.urls import reverse
        
        try:
            withdrawal = Transaction.objects.get(pk=pk, type_transaction='RETRAIT')
            
            if action == 'approve':
                withdrawal.statut = 'VALIDEE'
                withdrawal.date_validation = timezone.now()
                withdrawal.save()
                
                user = withdrawal.utilisateur
                user.commission_balance -= withdrawal.montant
                user.last_withdrawal_date = timezone.now()
                user.withdrawal_requested = False
                user.save()
                
                self.message_user(
                    request,
                    f'✓ Retrait de {withdrawal.montant:,.0f} FCFA validé avec succès pour {user.full_name}.',
                    messages.SUCCESS
                )
                
            elif action == 'reject':
                withdrawal.statut = 'REJETEE'
                withdrawal.date_validation = timezone.now()
                withdrawal.save()
                
                user = withdrawal.utilisateur
                user.withdrawal_requested = False
                user.save()
                
                self.message_user(
                    request,
                    f'✗ Retrait de {withdrawal.montant:,.0f} FCFA rejeté pour {user.full_name}.',
                    messages.WARNING
                )
            
        except Transaction.DoesNotExist:
            self.message_user(request, 'Transaction non trouvée.', messages.ERROR)
        except Exception as e:
            self.message_user(request, f'Erreur: {str(e)}', messages.ERROR)
        
        return HttpResponseRedirect(reverse('admin:transactions_transaction_changelist'))


# ============ ADMIN DISTRIBUTION COMMISSION ============

@admin.register(DistributionCommission)
class DistributionCommissionAdmin(admin.ModelAdmin):
    """Interface d'administration pour les distributions de commissions."""
    list_display = [
        'id',
        'beneficiaire_link',
        'transaction_source_link',
        'montant_display',
        'pourcentage',
        'niveau',
        'est_paye',
        'date_distribution',
    ]
    list_filter = ['est_paye', 'niveau', 'date_distribution']
    search_fields = [
        'beneficiaire__email',
        'beneficiaire__full_name',
    ]
    readonly_fields = ['date_distribution']
    ordering = ['-date_distribution']
    
    def beneficiaire_link(self, obj):
        url = reverse('admin:accounts_user_change', args=[obj.beneficiaire.pk])
        return format_html('<a href="{}">{}</a>', url, obj.beneficiaire.full_name)
    beneficiaire_link.short_description = 'Bénéficiaire'
    
    def transaction_source_link(self, obj):
        url = reverse('admin:transactions_transaction_change', args=[obj.transaction_source.pk])
        return format_html('<a href="{}">Transaction #{}</a>', url, obj.transaction_source.pk)
    transaction_source_link.short_description = 'Transaction Source'
    
    def montant_display(self, obj):
        return f"{obj.montant:,.0f} FCFA"
    montant_display.short_description = 'Montant'