import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  bool _copied = false;

  void _copyReferralCode() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.referralCode != null) {
      Clipboard.setData(ClipboardData(text: user!.referralCode!));
      setState(() {
        _copied = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copié dans le presse-papier !'),
          backgroundColor: Colors.green,
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _copied = false;
          });
        }
      });
    }
  }

  void _shareViaWhatsApp() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.referralCode != null) {
      final message =
          '🎯 Rejoins Illuminati avec mon code de parrainage : ${user!.referralCode}\n\n'
          '💰 Active ton compte et commence à gagner des commissions !\n'
          '📱 Télécharge l\'application maintenant.';

      Share.share(message);
    }
  }

  void _shareViaSMS() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.referralCode != null) {
      final message =
          'Rejoins Illuminati avec mon code : ${user!.referralCode}\n'
          'Active ton compte et gagne des commissions !';

      Share.share(message);
    }
  }

  void _shareGeneric() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.referralCode != null) {
      final message =
          '🎯 Illuminati - Code de parrainage : ${user!.referralCode}\n\n'
          'Rejoins-nous et commence à gagner !';

      Share.share(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final referralCode = user?.referralCode ?? 'Non disponible';
    final fullName = user?.fullName ?? 'Membre';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Parrainage'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // En-tête
            const Text(
              'Partagez votre code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'et gagnez des commissions sur chaque activation',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // Carte QR Code
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade400,
                    Colors.deepPurple.shade700,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: 'ILLUMINATI-$referralCode',
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Code de parrainage
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          referralCode,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: _copyReferralCode,
                          child: Icon(
                            _copied ? Icons.check_circle : Icons.copy,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Comment ça marche
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Comment ça marche ?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStep('1',
                      'Partagez votre code QR ou votre code de parrainage'),
                  const SizedBox(height: 8),
                  _buildStep(
                      '2', 'Votre filleul s\'inscrit et active son compte'),
                  const SizedBox(height: 8),
                  _buildStep(
                      '3', 'Vous recevez automatiquement vos commissions'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Boutons de partage
            const Text(
              'Partager via',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildShareButton(
                  Icons.message,
                  'SMS',
                  Colors.green,
                  _shareViaSMS,
                ),
                const SizedBox(width: 16),
                _buildShareButton(
                  Icons.chat,
                  'WhatsApp',
                  Colors.green.shade700,
                  _shareViaWhatsApp,
                ),
                const SizedBox(width: 16),
                _buildShareButton(
                  Icons.share,
                  'Autre',
                  Colors.blue,
                  _shareGeneric,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bouton copier
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _copyReferralCode,
                icon: Icon(_copied ? Icons.check_circle : Icons.copy),
                label: Text(_copied ? 'Copié !' : 'Copier le code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildShareButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
