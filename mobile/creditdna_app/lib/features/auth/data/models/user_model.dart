class UserModel {
  final String id;
  final String? email;
  final String? name;
  final DateTime createdAt;

  UserModel({
    required this.id,
    this.email,
    this.name,
    required this.createdAt,
  });
}