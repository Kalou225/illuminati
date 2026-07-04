class UserModel {
  final int id;
  final String email;
  final String phoneNumber;
  final String fullName;
  final String grade;
  final bool isActivated;
  final double activationAmount;
  final double commissionBalance;
  final double pendingCommissions;
  final String? referralCode;
  final DateTime? dateJoined;
  final bool canWithdraw;
  final bool canUpgrade;

  UserModel({
    required this.id,
    required this.email,
    required this.phoneNumber,
    required this.fullName,
    required this.grade,
    this.isActivated = false,
    this.activationAmount = 0.0,
    this.commissionBalance = 0.0,
    this.pendingCommissions = 0.0,
    this.referralCode,
    this.dateJoined,
    this.canWithdraw = false,
    this.canUpgrade = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      fullName: json['full_name'] ?? '',
      grade: json['grade'] ?? 'APPRENTI',
      isActivated: json['is_activated'] ?? false,
      activationAmount: _parseDouble(json['activation_amount']),
      commissionBalance: _parseDouble(json['commission_balance']),
      pendingCommissions: _parseDouble(json['pending_commissions']),
      referralCode: json['referral_code'],
      dateJoined: json['date_joined'] != null
          ? DateTime.parse(json['date_joined'])
          : null,
      canWithdraw: json['can_withdraw'] ?? false,
      canUpgrade: json['can_upgrade'] ?? false,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone_number': phoneNumber,
      'full_name': fullName,
      'grade': grade,
      'is_activated': isActivated,
      'activation_amount': activationAmount,
      'commission_balance': commissionBalance,
      'pending_commissions': pendingCommissions,
      'referral_code': referralCode,
      'date_joined': dateJoined?.toIso8601String(),
      'can_withdraw': canWithdraw,
      'can_upgrade': canUpgrade,
    };
  }

  String get gradeDisplay {
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

  double get walletTotal => activationAmount + commissionBalance;
}
