import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 1. РЕГИСТРАЦИЯ (Create User) ---
  // Используем: createUserWithEmailAndPassword
  Future<User?> signUp(String email, String password) async {
    try {
      print("Попытка РЕГИСТРАЦИИ для: $email"); // Лог для проверки

      // СОЗДАЕМ пользователя в Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );
      User? user = result.user;

      // Если успех - создаем запись в базе данных
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'email': email,
          'role': 'guest', // Обязательное поле!
          'createdAt': DateTime.now().toIso8601String(),
          'favorites': [],
        });
        print("Пользователь успешно создан в БД");
      }
      return user;
    } catch (e) {
      print("ОШИБКА РЕГИСТРАЦИИ: $e");
      rethrow; // Прокидываем ошибку, чтобы экран показал её
    }
  }

  // --- 2. ВХОД (Sign In) ---
  // Используем: signInWithEmailAndPassword
  Future<User?> signIn(String email, String password) async {
    try {
      print("Попытка ВХОДА для: $email");

      // ВХОДИМ в систему
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
      );
      User? user = result.user;

      // САМОЛЕЧЕНИЕ: Если вошли, но в базе нет записи (старый баг) - создаем её
      if (user != null) {
        final userDoc = await _db.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          print("Восстановление потерянной записи в БД...");
          await _db.collection('users').doc(user.uid).set({
            'email': email,
            'role': 'guest',
            'createdAt': DateTime.now().toIso8601String(),
            'favorites': [],
          });
        }
      }

      return user;
    } catch (e) {
      print("ОШИБКА ВХОДА: $e");
      rethrow;
    }
  }

  // Выход
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Получение текущего юзера с данными из БД
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, user.uid);
      }
    } catch (e) {
      print("Ошибка получения данных юзера: $e");
    }
    return null;
  }

  // Сброс пароля
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print("Reset Password Error: $e");
      rethrow;
    }
  }

  // Получение UID (полезно для других сервисов)
  String? getCurrentUserUid() {
    return _auth.currentUser?.uid;
  }
}

