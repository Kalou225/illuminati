import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _referenceController = TextEditingController();
  String _moyenPaiement = 'WAVE';
  bool _isLoading = false;
  String? _error;
  String? _success;
  String? _gradeEstime;
  String? _gradeDisplay;

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
    _checkIfAlreadyActivated();
  }

  void _checkIfAlreadyActivated() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null && user.isActivated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Compte déjà activé'),
            content: const Text(
              'Votre compte est déjà activé. Vous ne pouvez pas effectuer une nouvelle activation.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/home');
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _updateGradeEstimate(String value) {
    setState(() {
      final montant = double.tryParse(value);
      if (montant != null) {
        final result = _getGradeFromAmount(montant);
        _gradeEstime = result['grade'];
        _gradeDisplay = result['gradeDisplay'];
      } else {
        _gradeEstime = null;
        _gradeDisplay = null;
      }
    });
  }

  Map<String, String> _getGradeFromAmount(double montant) {
    if (montant >= 20000000) {
      return {'grade': 'GRAND_MAITRE', 'gradeDisplay': 'Grand Maître'};
    } else if (montant >= 2100000) {
      return {'grade': 'MAITRE_N1', 'gradeDisplay': 'Maître Niveau 1'};
    } else if (montant >= 1001000) {
      return {'grade': 'MAITRE_N2', 'gradeDisplay': 'Maître Niveau 2'};
    } else if (montant >= 801000) {
      return {'grade': 'MAITRE_N3', 'gradeDisplay': 'Maître Niveau 3'};
    } else if (montant >= 601000) {
      return {'grade': 'COMPAGNON_N1', 'gradeDisplay': 'Compagnon Niveau 1'};
    } else if (montant >= 401000) {
      return {'grade': 'COMPAGNON_N2', 'gradeDisplay': 'Compagnon Niveau 2'};
    } else if (montant >= 201000) {
      return {'grade': 'COMPAGNON_N3', 'gradeDisplay': 'Compagnon Niveau 3'};
    } else if (montant >= 1) {
      return {'grade': 'APPRENTI', 'gradeDisplay': 'Apprenti'};
    }
    return {'grade': '', 'gradeDisplay': ''};
  }

  void _activerCompte() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final result = await ApiService.activateAccount(
        montant: double.parse(_montantController.text),
        moyenPaiement: _moyenPaiement,
        referencePaiement: _referenceController.text.isNotEmpty
            ? _referenceController.text
            : null,
      );

      setState(() {
        _success =
            'Compte activé avec succès ! Grade : ${result['grade_display']}';
        _isLoading = false;
      });

      // Recharger le profil pour mettre à jour les informations
      if (mounted) {
        await Provider.of<AuthProvider>(context, listen: false).loadProfile();
      }

      // Rediriger vers le tableau de bord après 2 secondes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
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
        title: const Text('Activer mon Compte'),
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
              // Message d'information
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(height: 8),
                    Text(
                      'Activation de votre compte',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Effectuez un dépôt pour activer votre compte et obtenir votre grade. Le grade est attribué automatiquement selon le montant déposé.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tableau des grades
              const Text(
                'Tableau des grades',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Grade')),
                      DataColumn(label: Text('Plage')),
                    ],
                    rows: const [
                      DataRow(cells: [
                        DataCell(Text('Apprenti')),
                        DataCell(Text('1 - 200 000 FCFA'))
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Compagnon N3')),
                        DataCell(Text('201 000 - 400 000 FCFA'))
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Compagnon N2')),
                        DataCell(Text('401 000 - 600 000 FCFA'))
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Compagnon N1')),
                        DataCell(Text('601 000 - 800 000 FCFA'))
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Maître N3')),
                        DataCell(Text('801 000 - 1M FCFA'))
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Maître N2')),
                        DataCell(Text('1M - 2M FCFA'))
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Maître N1')),
                        DataCell(Text('2.1M - 10M FCFA'))
                      ]),
                      DataRow(cells: [
                        DataCell(Text('Grand Maître')),
                        DataCell(Text('20M+ FCFA'))
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Montant
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
                  hintText: 'Ex: 340000',
                ),
                onChanged: _updateGradeEstimate,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un montant';
                  }
                  final montant = double.tryParse(value);
                  if (montant == null || montant < 1) {
                    return 'Le montant minimum est de 1 FCFA';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Grade estimé
              if (_gradeDisplay != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Grade estimé',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              _gradeDisplay!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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

              // Référence de paiement
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

              // Messages d'erreur et de succès
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

              // Bouton d'activation
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _activerCompte,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Activer mon Compte',
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
