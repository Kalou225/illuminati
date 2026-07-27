import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/transactions/depot_screen.dart';
import 'screens/transactions/retrait_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/network/network_screen.dart';
import 'screens/activation/activation_screen.dart';
import 'screens/grade/grade_upgrade_screen.dart';
import 'screens/admin/withdrawal_requests_screen.dart';
import 'screens/referral/referral_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Illuminati',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          useMaterial3: true,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/depot': (context) => const DepotScreen(),
          '/retrait': (context) => const RetraitScreen(),
          '/history': (context) => const HistoryScreen(),
          '/network': (context) => const NetworkScreen(),
          '/activation': (context) => const ActivationScreen(),
          '/grade-upgrade': (context) => const GradeUpgradeScreen(),
          '/admin/withdrawals': (context) => const WithdrawalRequestsScreen(),
          '/referral': (context) => const ReferralScreen(),
        },
      ),
    );
  }
}
