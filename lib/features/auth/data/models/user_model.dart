class UserModel {
  final String id;
  final String phone;
  final String? email;
  final String? name;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.phone,
    this.email,
    this.name,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'email': email,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}