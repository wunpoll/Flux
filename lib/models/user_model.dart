class UserModel {
  final String uid;
  final String email;
  final String role; // 'guest', 'pro', 'admin'

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
  });

  // Создание объекта из данных Firestore
  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      // Если роли нет, считаем гостем
      role: data['role'] ?? 'guest',
    );
  }

  // Преобразование в Map для записи в базу
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
    };
  }

  // Удобные геттеры для проверки прав
  bool get isPro => role == 'pro' || role == 'admin';
  bool get isAdmin => role == 'admin';
}