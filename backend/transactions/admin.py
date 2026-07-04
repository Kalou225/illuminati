from django.contrib import admin
from .models import Transaction, DistributionCommission
from django.utils.html import format_html
from django.urls import reverse
from django.utils import timezone
from datetime import timedelta

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
        'statut_colored',
        'date_transaction',
        'validation_actions',
    ]
    list_filter = ['type_transaction', 'statut', 'date_transaction']
    search_fields = ['utilisateur__email', 'utilisateur__full_name', 'reference_paiement']
    readonly_fields = ['date_transaction', 'date_validation']
    ordering = ['-date_transaction']
    list_per_page = 20
    
    def utilisateur_link(self, obj):
        """Lien vers l'utilisateur."""
        url = reverse('admin:accounts_user_change', args=[obj.utilisateur.pk])
        return format_html('<a href="{}">{}</a>', url, obj.utilisateur.full_name)
    utilisateur_link.short_description = 'Utilisateur'
    
    def type_transaction_colored(self, obj):
        """Affichage coloré du type de transaction."""
        colors = {
            'DEPOT': 'green',
            'RETRAIT': 'red',
            'COMMISSION': 'blue',
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
    
    def statut_colored(self, obj):
        """Affichage coloré du statut."""
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
        """Boutons de validation pour les retraits en attente."""
        if obj.type_transaction == 'RETRAIT' and obj.statut == 'EN_ATTENTE':
            # Bouton Valider
            validate_url = reverse('admin:validate-withdrawal', args=[obj.pk, 'approve'])
            # Bouton Rejeter
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
    
    def get_urls(self):
        """Ajouter des URLs personnalisées pour la validation."""
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
        """Valider ou rejeter un retrait."""
        from django.contrib import messages
        from django.http import HttpResponseRedirect
        from django.urls import reverse
        
        try:
            withdrawal = Transaction.objects.get(pk=pk, type_transaction='RETRAIT')
            
            if action == 'approve':
                # Valider le retrait
                withdrawal.statut = 'VALIDEE'
                withdrawal.date_validation = timezone.now()
                withdrawal.save()
                
                # Déduire le montant des commissions
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
                # Rejeter le retrait
                withdrawal.statut = 'REJETEE'
                withdrawal.date_validation = timezone.now()
                withdrawal.save()
                
                # Réinitialiser le flag
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