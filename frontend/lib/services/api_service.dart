import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============ AUTHENTIFICATION ============

  static Future<Map<String, dynamic>> register({
    required String email,
    required String fullName,
    required String phoneNumber,
    required String password,
    required String passwordConfirm,
    String? referralCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/accounts/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'password': password,
        'password_confirm': passwordConfirm,
        'referral_code': referralCode,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await saveToken(data['access']);
      return data;
    } else {
      throw Exception(jsonDecode(response.body));
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/accounts/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['access']);
      return data;
    } else {
      throw Exception('Email ou mot de passe incorrect');
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/accounts/profile/'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la récupération du profil');
    }
  }

  // ============ TRANSACTIONS ============

  static Future<Map<String, dynamic>> createDepot({
    required double montant,
    required String moyenPaiement,
    String? referencePaiement,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions/depot/'),
      headers: await getAuthHeaders(),
      body: jsonEncode({
        'montant': montant.toString(),
        'moyen_paiement': moyenPaiement,
        'reference_paiement': referencePaiement ?? '',
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error.toString());
    }
  }

  static Future<Map<String, dynamic>> createRetrait({
    required double montant,
    required String moyenPaiement,
    required String phoneNumber,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions/retrait/'),
      headers: await getAuthHeaders(),
      body: jsonEncode({
        'montant': montant.toString(),
        'moyen_paiement': moyenPaiement,
        'phone_number': phoneNumber,
        'phone_number_confirm': phoneNumber,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error.toString());
    }
  }

  static Future<List<dynamic>> getTransactions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/transactions/'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la récupération des transactions');
    }
  }

  static Future<List<dynamic>> getCommissions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/commissions/'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la récupération des commissions');
    }
  }

  // ============ SOLDE ============

  static Future<Map<String, dynamic>> getBalance() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/balance/'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la récupération du solde');
    }
  }

  static Future<Map<String, dynamic>> getSponsoredUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/accounts/sponsored/'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la récupération des filleuls');
    }
  }

  static Future<Map<String, dynamic>> activateAccount({
    required double montant,
    required String moyenPaiement,
    String? referencePaiement,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions/activation/'),
      headers: await getAuthHeaders(),
      body: jsonEncode({
        'montant': montant.toString(),
        'moyen_paiement': moyenPaiement,
        'reference_paiement': referencePaiement ?? '',
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error.toString());
    }
  }

  static Future<Map<String, dynamic>> upgradeGrade() async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions/grade-upgrade/'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error.toString());
    }
  }

  static Future<Map<String, dynamic>> getWithdrawalRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/withdrawal-requests/'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
          error['detail'] ?? 'Erreur lors de la récupération des demandes');
    }
  }

  static Future<Map<String, dynamic>> validateWithdrawal({
    required int withdrawalId,
    required String action, // 'approve' ou 'reject'
  }) async {
    final response = await http.post(
      Uri.parse(
          '$baseUrl/transactions/withdrawal-requests/$withdrawalId/validate/'),
      headers: await getAuthHeaders(),
      body: jsonEncode({'action': action}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Erreur lors de la validation');
    }
  }

  static Future<Map<String, dynamic>> getNetwork() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/network/'),
      headers: await getAuthHeaders(),
    );

    print('Network API - Status: ${response.statusCode}');
    print('Network API - Body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      // Token invalide ou expiré
      throw Exception('Le type de jeton fourni n\'est pas valide');
    } else if (response.statusCode == 403) {
      throw Exception('Accès refusé. Permissions insuffisantes.');
    } else if (response.statusCode == 500) {
      throw Exception('Erreur serveur. Veuillez réessayer plus tard.');
    } else {
      // Essayer de parser le JSON, sinon retourner un message générique
      try {
        final error = jsonDecode(response.body);
        throw Exception(
            error['detail'] ?? 'Erreur lors de la récupération du réseau');
      } catch (e) {
        throw Exception(
            'Erreur ${response.statusCode} lors de la récupération du réseau');
      }
    }
  }

  // ============ HISTORIQUE SÉPARÉ ============

  static Future<Map<String, dynamic>> getMesTransactions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/mes-transactions/'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Le type de jeton fourni n\'est pas valide');
    } else {
      throw Exception('Erreur lors de la récupération des transactions');
    }
  }

  static Future<Map<String, dynamic>> getMesCommissions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/mes-commissions/'),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Le type de jeton fourni n\'est pas valide');
    } else {
      throw Exception('Erreur lors de la récupération des commissions');
    }
  }
}
