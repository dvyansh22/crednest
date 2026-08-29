enum UserType { individual, gigWorker, msme }

extension UserTypeX on UserType {
  String get label {
    switch (this) {
      case UserType.individual:
        return 'Individual';
      case UserType.gigWorker:
        return 'Gig Worker';
      case UserType.msme:
        return 'MSME / Business Owner';
    }
  }
}

enum EmploymentType { salaried, selfEmployed, gigWork, businessOwner, unemployed, student }

extension EmploymentTypeX on EmploymentType {
  String get label {
    switch (this) {
      case EmploymentType.salaried:
        return 'Salaried';
      case EmploymentType.selfEmployed:
        return 'Self-employed';
      case EmploymentType.gigWork:
        return 'Gig / Freelance work';
      case EmploymentType.businessOwner:
        return 'Business owner';
      case EmploymentType.unemployed:
        return 'Not currently working';
      case EmploymentType.student:
        return 'Student';
    }
  }
}

enum IncomeCategory { under25k, r25kTo50k, r50kTo100k, r100kTo250k, above250k }

extension IncomeCategoryX on IncomeCategory {
  String get label {
    switch (this) {
      case IncomeCategory.under25k:
        return 'Under ₹25,000 / month';
      case IncomeCategory.r25kTo50k:
        return '₹25,000 – ₹50,000 / month';
      case IncomeCategory.r50kTo100k:
        return '₹50,000 – ₹1,00,000 / month';
      case IncomeCategory.r100kTo250k:
        return '₹1,00,000 – ₹2,50,000 / month';
      case IncomeCategory.above250k:
        return 'Above ₹2,50,000 / month';
    }
  }
}

/// The user's broader financial profile, collected during Profile Setup.
///
/// This is deliberately separate from [UserModel] (auth identity) — auth
/// owns who the user is, this owns how they describe their financial life.
class UserProfileModel {
  final String fullName;
  final String email;
  final String phoneNumber;
  final EmploymentType employmentType;
  final IncomeCategory incomeCategory;
  final UserType userType;
  final bool profileCompleted;
  final DateTime updatedAt;

  const UserProfileModel({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.employmentType,
    required this.incomeCategory,
    required this.userType,
    required this.profileCompleted,
    required this.updatedAt,
  });

  /// First token of [fullName], or '' if the name is blank — callers decide
  /// the fallback ("Hello 👋" vs "Hello, {name} 👋").
  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  UserProfileModel copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    EmploymentType? employmentType,
    IncomeCategory? incomeCategory,
    UserType? userType,
    bool? profileCompleted,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      employmentType: employmentType ?? this.employmentType,
      incomeCategory: incomeCategory ?? this.incomeCategory,
      userType: userType ?? this.userType,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'employmentType': employmentType.name,
        'incomeCategory': incomeCategory.name,
        'userType': userType.name,
        'profileCompleted': profileCompleted,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      employmentType: EmploymentType.values.firstWhere(
        (e) => e.name == json['employmentType'],
        orElse: () => EmploymentType.salaried,
      ),
      incomeCategory: IncomeCategory.values.firstWhere(
        (e) => e.name == json['incomeCategory'],
        orElse: () => IncomeCategory.under25k,
      ),
      userType: UserType.values.firstWhere(
        (e) => e.name == json['userType'],
        orElse: () => UserType.individual,
      ),
      profileCompleted: json['profileCompleted'] as bool? ?? false,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
