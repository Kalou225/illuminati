import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _balance;
  bool _isLoadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() {
      _isLoadingBalance = true;
    });

    try {
      final balance = await ApiService.getBalance();
      setState(() {
        _balance = {
          'solde': (balance['solde'] ?? 0).toDouble(),
          'total_depots': (balance['total_depots'] ?? 0).toDouble(),
          'total_retraits': (balance['total_retraits'] ?? 0).toDouble(),
          'total_commissions': (balance['total_commissions'] ?? 0).toDouble(),
          'activation_amount': (balance['activation_amount'] ?? 0).toDouble(),
          'commission_balance': (balance['commission_balance'] ?? 0).toDouble(),
          'is_activated': balance['is_activated'] ?? false,
          'grade': balance['grade'] ?? 'APPRENTI',
          'can_withdraw': balance['can_withdraw'] ?? false,
          'can_upgrade': balance['can_upgrade'] ?? false,
        };
        _isLoadingBalance = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingBalance = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur de chargement: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyReferralCode(BuildContext context, String? code) {
    if (code != null) {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copié dans le presse-papier !'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  String _getGradeDisplay(String grade) {
    switch (grade) {
      case 'APPRENTI':
        return 'Apprenti';
      case 'COMPAGNON_N3':
        return 'Compagnon N3';
      case 'COMPAGNON_N2':
        return 'Compagnon N2';
      case 'COMPAGNON_N1':
        return 'Compagnon N1';
      case 'MAITRE_N3':
        return 'Maître N3';
      case 'MAITRE_N2':
        return 'Maître N2';
      case 'MAITRE_N1':
        return 'Maître N1';
      case 'GRAND_MAITRE':
        return 'Grand Maître';
      default:
        return grade;
    }
  }

  String _getCommissionPercentage(String grade) {
    switch (grade) {
      case 'APPRENTI':
        return '2%';
      case 'COMPAGNON_N3':
        return '3%';
      case 'COMPAGNON_N2':
        return '4%';
      case 'COMPAGNON_N1':
        return '5%';
      case 'MAITRE_N3':
        return '6%';
      case 'MAITRE_N2':
        return '7%';
      case 'MAITRE_N1':
        return '8%';
      case 'GRAND_MAITRE':
        return '0% (Reçoit le reste)';
      default:
        return '2%';
    }
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'APPRENTI':
        return Colors.grey;
      case 'COMPAGNON_N3':
        return Colors.blue;
      case 'COMPAGNON_N2':
        return Colors.green;
      case 'COMPAGNON_N1':
        return Colors.teal;
      case 'MAITRE_N3':
        return Colors.purple;
      case 'MAITRE_N2':
        return Colors.deepPurple;
      case 'MAITRE_N1':
        return Colors.indigo;
      case 'GRAND_MAITRE':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    final isActivated = _balance?['is_activated'] ?? false;
    final currentGrade = _balance?['grade'] ?? user?.grade ?? 'APPRENTI';
    final canUpgrade = _balance?['can_upgrade'] ?? false;
    final activationAmount = (_balance?['activation_amount'] ?? 0).toDouble();
    final commissionBalance = (_balance?['commission_balance'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de Bord'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: _isLoadingBalance
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBalance,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête : Bienvenue et Badges
                    Text(
                      'Bonjour, ${user?.fullName.split(' ').first ?? 'Membre'} !',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Badge du grade
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                _getGradeColor(currentGrade).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: _getGradeColor(currentGrade)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getGradeDisplay(currentGrade),
                                style: TextStyle(
                                  color: _getGradeColor(currentGrade),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getGradeColor(currentGrade),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _getCommissionPercentage(currentGrade),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge "Activé" ou "Non activé"
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActivated
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    isActivated ? Colors.green : Colors.orange),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isActivated ? Icons.check_circle : Icons.cancel,
                                size: 16,
                                color:
                                    isActivated ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isActivated ? 'Activé' : 'Non activé',
                                style: TextStyle(
                                  color: isActivated
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // === NOUVEAU : Affichage des DEUX soldes séparés ===
                    if (isActivated) ...[
                      // 1. Solde d'activation (Bloqué)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blueGrey.shade700,
                              Colors.blueGrey.shade900
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.blueGrey.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lock_outline,
                                    color: Colors.white70, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Solde d\'activation (Bloqué)',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${activationAmount.toStringAsFixed(0)} FCFA',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Détermine votre grade actuel. Non retirable.',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Solde de commissions (Disponible)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade600,
                              Colors.green.shade800
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet,
                                    color: Colors.white70, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Solde de commissions (Disponible)',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${commissionBalance.toStringAsFixed(0)} FCFA',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Disponible pour retrait ou montée en grade.',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Message d'activation si non activé
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.lock_outline,
                                size: 48, color: Colors.orange),
                            const SizedBox(height: 12),
                            const Text(
                              'Activez votre compte pour commencer',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Effectuez un dépôt pour activer votre compte, obtenir votre grade et recevoir des commissions.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/activation'),
                                icon: const Icon(Icons.lock_open),
                                label: const Text('Activer mon compte'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Bouton de montée de grade (si disponible)
                    if (isActivated && canUpgrade)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.amber.shade400,
                            Colors.amber.shade700
                          ]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.arrow_upward,
                                color: Colors.white, size: 32),
                            const SizedBox(height: 8),
                            const Text(
                              'Vous pouvez monter de grade !',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Utilisez vos commissions pour augmenter votre solde d\'activation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pushNamed(
                                    context, '/grade-upgrade'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.amber.shade800,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Monter de grade maintenant',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Code de parrainage
                    const Text(
                      'Mon Code de Parrainage',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/referral'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepPurple.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(
                              user?.referralCode ?? 'Génération en cours...',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _copyReferralCode(
                                      context, user?.referralCode),
                                  icon: const Icon(Icons.copy, size: 18),
                                  label: const Text('Copier'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      Navigator.pushNamed(context, '/referral'),
                                  icon: const Icon(Icons.qr_code, size: 18),
                                  label: const Text('QR Code'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.deepPurple,
                                    side: const BorderSide(
                                        color: Colors.deepPurple),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Cartes d'action rapide
                    const Text(
                      'Actions Rapides',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            context,
                            Icons.account_balance_wallet,
                            'Déposer',
                            Colors.green,
                            () => Navigator.pushNamed(context, '/depot'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionCard(
                            context,
                            Icons.money_off,
                            'Retirer',
                            Colors.red,
                            () => Navigator.pushNamed(context, '/retrait'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.deepPurple,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_tree), label: 'Réseau'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: 'Historique'),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, '/network');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/history');
          }
        },
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
