import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/wallet_card.dart';

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

    // ✅ CORRECTION : Utiliser les données de l'API balance au lieu du profil en cache
    final isActivated = _balance?['is_activated'] ?? false;
    final currentGrade = _balance?['grade'] ?? user?.grade ?? 'APPRENTI';
    final canUpgrade = _balance?['can_upgrade'] ?? false;
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message de bienvenue
                  Text(
                    'Bonjour, ${user?.fullName.split(' ').first ?? 'Membre'} !',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Badge du grade
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getGradeColor(currentGrade).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: _getGradeColor(currentGrade)),
                        ),
                        child: Text(
                          _getGradeDisplay(currentGrade),
                          style: TextStyle(
                            color: _getGradeColor(currentGrade),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                            color: isActivated ? Colors.green : Colors.orange,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActivated ? Icons.check_circle : Icons.cancel,
                              size: 16,
                              color: isActivated ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActivated ? 'Activé' : 'Non activé',
                              style: TextStyle(
                                color:
                                    isActivated ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Bouton d'activation si non activé
                  if (!isActivated)
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Effectuez un dépôt pour activer votre compte et recevoir des commissions',
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
                  const SizedBox(height: 24),

                  // Widget Portefeuille
                  if (_balance != null)
                    WalletCard(
                      solde: (_balance!['solde'] ?? 0).toDouble(),
                      totalDepots: (_balance!['total_depots'] ?? 0).toDouble(),
                      totalRetraits:
                          (_balance!['total_retraits'] ?? 0).toDouble(),
                      totalCommissions:
                          (_balance!['total_commissions'] ?? 0).toDouble(),
                      onRefresh: _loadBalance,
                    ),
                  const SizedBox(height: 32),

                  // Bouton de montée de grade (si disponible)
                  if (isActivated && canUpgrade)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade400,
                            Colors.deepPurple.shade700
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
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
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pushNamed(
                                  context, '/grade-upgrade'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.deepPurple,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Monter de grade',
                                  style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Code de parrainage
                  const Text(
                    'Mon Code de Parrainage',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => Navigator.pushNamed(context, '/referral'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
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
                                icon: const Icon(Icons.copy),
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
                                icon: const Icon(Icons.qr_code),
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
                  const SizedBox(height: 32),

                  // Cartes d'action rapide
                  const Text(
                    'Actions Rapides',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 32),

                  // Statistiques
                  const Text(
                    'Mes Statistiques',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard('Filleuls directs', '0', Icons.people),
                  const SizedBox(height: 8),
                  _buildStatCard(
                    'Commissions gagnées',
                    '${commissionBalance.toStringAsFixed(0)} FCFA',
                    Icons.attach_money,
                  ),
                ],
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
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
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

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple, size: 30),
        title: Text(label),
        trailing: Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
