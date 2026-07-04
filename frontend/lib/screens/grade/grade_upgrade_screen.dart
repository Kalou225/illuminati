import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class GradeUpgradeScreen extends StatefulWidget {
  const GradeUpgradeScreen({super.key});

  @override
  State<GradeUpgradeScreen> createState() => _GradeUpgradeScreenState();
}

class _GradeUpgradeScreenState extends State<GradeUpgradeScreen> {
  bool _isLoading = false;
  String? _error;
  String? _success;
  Map<String, dynamic>? _gradeInfo;

  @override
  void initState() {
    super.initState();
    _loadGradeInfo();
  }

  void _loadGradeInfo() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      setState(() {
        _gradeInfo = {
          'current_grade': user.grade,
          'current_grade_display': _getGradeDisplay(user.grade),
          'next_grade': _getNextGrade(user.grade),
          'next_grade_display': _getNextGradeDisplay(user.grade),
          'wallet_total': user.walletTotal,
          'commission_balance': user.commissionBalance,
          'activation_amount': user.activationAmount,
          'threshold': _getNextGradeThreshold(user.grade),
        };
      });
    }
  }

  String _getGradeDisplay(String grade) {
    switch (grade) {
      case 'APPRENTI':
        return 'Apprenti';
      case 'COMPAGNON_N3':
        return 'Compagnon Niveau 3';
      case 'COMPAGNON_N2':
        return 'Compagnon Niveau 2';
      case 'COMPAGNON_N1':
        return 'Compagnon Niveau 1';
      case 'MAITRE_N3':
        return 'Maître Niveau 3';
      case 'MAITRE_N2':
        return 'Maître Niveau 2';
      case 'MAITRE_N1':
        return 'Maître Niveau 1';
      case 'GRAND_MAITRE':
        return 'Grand Maître';
      default:
        return grade;
    }
  }

  String? _getNextGrade(String currentGrade) {
    final grades = [
      'APPRENTI',
      'COMPAGNON_N3',
      'COMPAGNON_N2',
      'COMPAGNON_N1',
      'MAITRE_N3',
      'MAITRE_N2',
      'MAITRE_N1',
      'GRAND_MAITRE',
    ];

    final currentIndex = grades.indexOf(currentGrade);
    if (currentIndex >= 0 && currentIndex < grades.length - 1) {
      return grades[currentIndex + 1];
    }
    return null;
  }

  String _getNextGradeDisplay(String currentGrade) {
    final nextGrade = _getNextGrade(currentGrade);
    if (nextGrade != null) {
      return _getGradeDisplay(nextGrade);
    }
    return 'Grade maximum atteint';
  }

  double _getNextGradeThreshold(String currentGrade) {
    final thresholds = {
      'APPRENTI': 201000.0,
      'COMPAGNON_N3': 401000.0,
      'COMPAGNON_N2': 601000.0,
      'COMPAGNON_N1': 801000.0,
      'MAITRE_N3': 1001000.0,
      'MAITRE_N2': 2100000.0,
      'MAITRE_N1': 20000000.0,
      'GRAND_MAITRE': 0.0,
    };
    return thresholds[currentGrade] ?? 0.0;
  }

  void _upgradeGrade() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final result = await ApiService.upgradeGrade();

      setState(() {
        _success =
            'Félicitations ! Vous êtes maintenant ${result['nouveau_grade']}';
        _isLoading = false;
      });

      // Recharger le profil
      if (mounted) {
        await Provider.of<AuthProvider>(context, listen: false).loadProfile();
        _loadGradeInfo();
      }

      // Rediriger vers le tableau de bord après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
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
        title: const Text('Montée de Grade'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _gradeInfo == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grade actuel
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
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
                        const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Grade Actuel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _gradeInfo!['current_grade_display'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Flèche de progression
                  Center(
                    child: Icon(
                      Icons.arrow_upward,
                      size: 40,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Grade suivant
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade400,
                          Colors.green.shade700,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Grade Suivant',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _gradeInfo!['next_grade_display'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Informations du portefeuille
                  const Text(
                    'Votre Portefeuille',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          'Montant d\'activation',
                          '${_gradeInfo!['activation_amount'].toStringAsFixed(0)} FCFA',
                          Icons.lock,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Commissions',
                          '${_gradeInfo!['commission_balance'].toStringAsFixed(0)} FCFA',
                          Icons.attach_money,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          'Total Portefeuille',
                          '${_gradeInfo!['wallet_total'].toStringAsFixed(0)} FCFA',
                          Icons.account_balance_wallet,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Seuil requis
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Condition de montée',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Seuil requis : ${_gradeInfo!['threshold'].toStringAsFixed(0)} FCFA',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Après montée, vos commissions repartiront à 0',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
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

                  // Bouton de montée de grade
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _upgradeGrade,
                      icon: const Icon(Icons.arrow_upward),
                      label: const Text('Monter de Grade',
                          style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon,
      {bool bold = false}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: Colors.blue.shade900,
          ),
        ),
      ],
    );
  }
}
