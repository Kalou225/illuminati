import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  Map<String, dynamic>? _networkData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNetwork();
  }

  Future<void> _loadNetwork() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getNetwork();
      setState(() {
        _networkData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
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

  String _getNiveauLabel(int niveau) {
    if (niveau == 1) return 'Filleul Direct';
    return 'Niveau $niveau';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Réseau'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNetwork,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Si erreur de token, déconnecter et reconnecter
                          if (_error!.contains('jeton') || _error!.contains('token')) {
                            Provider.of<AuthProvider>(context, listen: false).logout();
                            Navigator.pushReplacementNamed(context, '/login');
                          } else {
                            _loadNetwork();
                          }
                        },
                        child: Text(_error!.contains('jeton') || _error!.contains('token')
                            ? 'Se reconnecter'
                            : 'Réessayer'),
                      ),
                    ],
                  ),
                )
              : _networkData == null || _networkData!['descendants'].isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun filleul pour le moment',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Partagez votre code de parrainage',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNetwork,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Statistiques
                            _buildStatsCard(),
                            const SizedBox(height: 24),

                            // Titre de la liste
                            const Text(
                              'Mon Arborescence Complète',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Liste des descendants
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _networkData!['descendants'].length,
                              itemBuilder: (context, index) {
                                final descendant = _networkData!['descendants'][index];
                                return _buildDescendantCard(descendant);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildStatsCard() {
    final totalDescendants = _networkData!['total_descendants'] ?? 0;
    final totalActivated = _networkData!['total_activated'] ?? 0;
    final totalPending = _networkData!['total_pending'] ?? 0;
    final totalCommissions = (_networkData!['total_commissions_generated'] ?? 0.0).toDouble();

    return Container(
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
          Row(
            children: [
              _buildStatItem(
                Icons.people,
                '$totalDescendants',
                'Filleuls',
                Colors.white,
              ),
              const SizedBox(width: 16),
              _buildStatItem(
                Icons.check_circle,
                '$totalActivated',
                'Activés',
                Colors.green.shade300,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(
                Icons.pending,
                '$totalPending',
                'En attente',
                Colors.orange.shade300,
              ),
              const SizedBox(width: 16),
              _buildStatItem(
                Icons.attach_money,
                '${totalCommissions.toStringAsFixed(0)}',
                'Commissions',
                Colors.amber.shade300,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescendantCard(Map<String, dynamic> descendant) {
    final grade = descendant['grade'] ?? 'APPRENTI';
    final isActivated = descendant['is_activated'] ?? false;
    final walletTotal = (descendant['wallet_total'] ?? 0.0).toDouble();
    final commissionsGenerees = (descendant['commissions_generees'] ?? 0.0).toDouble();
    final dateJoined = DateTime.parse(descendant['date_joined']);
    final niveau = descendant['niveau'] ?? 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec niveau et statut
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getNiveauLabel(niveau),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        descendant['full_name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        descendant['email'],
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActivated ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActivated ? Icons.check_circle : Icons.pending,
                        size: 16,
                        color: isActivated ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActivated ? 'Activé' : 'En attente',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isActivated ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Grade et date d'inscription
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getGradeColor(grade).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getGradeColor(grade)),
                  ),
                  child: Text(
                    _getGradeDisplay(grade),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getGradeColor(grade),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd/MM/yyyy').format(dateJoined),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Portefeuille et commissions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Portefeuille',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${walletTotal.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Commissions générées',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${commissionsGenerees.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}