import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class RetraitScreen extends StatefulWidget {
  const RetraitScreen({super.key});

  @override
  State<RetraitScreen> createState() => _RetraitScreenState();
}

class _RetraitScreenState extends State<RetraitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _phoneController = TextEditingController();
  String _moyenPaiement = 'WAVE';
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _walletInfo;

  final List<String> _moyensPaiement = ['WAVE', 'MTN', 'MOOV', 'ORANGE'];
  final Map<String, String> _moyensLabels = {
    'WAVE': 'Wave CI',
    'MTN': 'MTN Mobile Money',
    'MOOV': 'Moov Money',
    'ORANGE': 'Orange Money',
  };

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletInfo() async {
    try {
      final balance = await ApiService.getBalance();
      setState(() {
        _walletInfo = {
          'commission_balance': (balance['commission_balance'] ?? 0).toDouble(),
          'can_withdraw': balance['can_withdraw'] ?? false,
          'is_activated': balance['is_activated'] ?? false,
        };
      });
    } catch (e) {
      // Ignorer les erreurs
    }
  }

  void _effectuerRetrait() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final montant = double.parse(_montantController.text);

      await ApiService.createRetrait(
        montant: montant,
        moyenPaiement: _moyenPaiement,
        phoneNumber: _phoneController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Demande de retrait soumise avec succès ! Validation sous 24h par l\'administrateur.'),
            backgroundColor: Colors.orange, // ← Orange pour indiquer l'attente
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final commissionBalance =
        (_walletInfo?['commission_balance'] ?? 0).toDouble();
    final canWithdraw = _walletInfo?['can_withdraw'] ?? false;
    final isActivated = _walletInfo?['is_activated'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Effectuer un Retrait'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informations du portefeuille
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade400,
                      Colors.deepPurple.shade700,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.account_balance_wallet,
                        color: Colors.white, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Commissions disponibles',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${commissionBalance.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Message si compte non activé
              if (!isActivated)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Compte non activé',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vous devez activer votre compte avant de pouvoir retirer.',
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Message si pas de commissions
              if (isActivated && commissionBalance <= 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aucune commission disponible',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vous devez accumuler des commissions avant de pouvoir retirer.',
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Message si retrait déjà effectué ce mois
              if (isActivated && commissionBalance > 0 && !canWithdraw)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Retrait déjà effectué ce mois',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vous ne pouvez effectuer qu\'un seul retrait par mois (30 jours).',
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Conditions de retrait
              if (isActivated && commissionBalance > 0 && canWithdraw) ...[
                const Text(
                  'Conditions de retrait',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildConditionRow(
                        Icons.calendar_today,
                        'Fréquence',
                        '1 retrait par mois (30 jours)',
                      ),
                      const SizedBox(height: 12),
                      _buildConditionRow(
                        Icons.percent,
                        'Frais',
                        '25% du montant retiré',
                      ),
                      const SizedBox(height: 12),
                      _buildConditionRow(
                        Icons.access_time,
                        'Validation',
                        'Sous 24 heures par l\'administrateur',
                      ),
                      const SizedBox(height: 12),
                      _buildConditionRow(
                        Icons.monetization_on,
                        'Montant minimum',
                        '1 000 FCFA',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Montant
                const Text(
                  'Montant à retirer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _montantController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant (FCFA)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                    hintText: 'Ex: 50000',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un montant';
                    }
                    final montant = double.tryParse(value);
                    if (montant == null || montant < 1000) {
                      return 'Le montant minimum est de 1 000 FCFA';
                    }
                    if (montant > commissionBalance) {
                      return 'Le montant ne peut pas dépasser vos commissions disponibles';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {}); // Pour afficher le net en temps réel
                  },
                ),
                const SizedBox(height: 16),

                // Affichage du montant net
                if (_montantController.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Montant brut:',
                                style: TextStyle(fontSize: 14)),
                            Text(
                              '${double.parse(_montantController.text).toStringAsFixed(0)} FCFA',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Frais (25%):',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.red)),
                            Text(
                              '-${(double.parse(_montantController.text) * 0.25).toStringAsFixed(0)} FCFA',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Montant net à recevoir:',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${(double.parse(_montantController.text) * 0.75).toStringAsFixed(0)} FCFA',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Numéro de téléphone
                const Text(
                  'Numéro de téléphone',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    hintText: 'Ex: 0700000000',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un numéro de téléphone';
                    }
                    if (value.length < 8) {
                      return 'Le numéro de téléphone n\'est pas valide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Moyen de paiement
                const Text(
                  'Moyen de paiement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _moyenPaiement,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: _moyensPaiement.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(_moyensLabels[value]!),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _moyenPaiement = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Message d'erreur
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!,
                                style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Bouton de retrait
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _effectuerRetrait,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Demander un Retrait',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConditionRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.deepPurple),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
