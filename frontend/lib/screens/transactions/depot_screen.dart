import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class DepotScreen extends StatefulWidget {
  const DepotScreen({super.key});

  @override
  State<DepotScreen> createState() => _DepotScreenState();
}

class _DepotScreenState extends State<DepotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _referenceController = TextEditingController();
  String _moyenPaiement = 'WAVE';
  bool _isLoading = false;
  String? _error;
  String? _success;

  final List<String> _moyensPaiement = ['WAVE', 'MTN', 'MOOV', 'ORANGE'];
  final Map<String, String> _moyensLabels = {
    'WAVE': 'Wave CI',
    'MTN': 'MTN Mobile Money',
    'MOOV': 'Moov Money',
    'ORANGE': 'Orange Money',
  };

  @override
  void dispose() {
    _montantController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _effectuerDepot() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final result = await ApiService.createDepot(
        montant: double.parse(_montantController.text),
        moyenPaiement: _moyenPaiement,
        referencePaiement: _referenceController.text.isNotEmpty
            ? _referenceController.text
            : null,
      );

      setState(() {
        _success = 'Dépôt effectué avec succès !';
        _isLoading = false;
      });

      // Recharger le profil pour mettre à jour les statistiques
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).loadProfile();
      }

      // Vider le formulaire après 2 secondes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _montantController.clear();
          _referenceController.clear();
          setState(() {
            _success = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Effectuer un Dépôt'),
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
              const Text(
                'Montant à déposer',
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
                  hintText: 'Ex: 10000',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un montant';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Veuillez entrer un montant valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
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
              const Text(
                'Référence de paiement (Optionnel)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Référence',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt),
                  hintText: 'Numéro de transaction',
                ),
              ),
              const SizedBox(height: 24),
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
              if (_success != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_success!,
                              style: const TextStyle(color: Colors.green))),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _effectuerDepot,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Effectuer le Dépôt',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
