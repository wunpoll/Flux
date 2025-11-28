import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/screens/login_screen.dart';
import 'package:flux/services/auth_service.dart';
import 'package:flux/localization.dart';
import 'package:flux/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ФЕЙКОВЫЙ СЕРВИС
// Используем implements, чтобы не запускать реальный Firebase
class MockAuthService implements AuthService {
  bool signInCalled = false;

  @override
  Future<User?> signIn(String email, String password) async {
    signInCalled = true;
    await Future.delayed(const Duration(seconds: 2)); // Имитация сети
    return null;
  }

  // Заглушки для остальных методов (обязательны при implements)
  @override
  Future<User?> signUp(String email, String password) async => null;
  @override
  Future<void> signOut() async {}
  @override
  Future<UserModel?> getCurrentUser() async => null;
  @override
  String? getCurrentUserUid() => "test_uid";
  @override
  Future<void> resetPassword(String email) async {}
}

void main() {
  testWidgets('Login Flow Integration Test', (WidgetTester tester) async {
    // 1. Создаем мок
    final mockAuthService = MockAuthService();

    // 2. Запускаем LoginScreen с подменой:
    // - authService: наш фейковый сервис
    // - nextScreen: ПРОСТОЙ ЭКРАН (Scaffold), чтобы не грузить реальный HomeScreen с Firebase
    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(
        authService: mockAuthService,
        nextScreen: const Scaffold(body: Center(child: Text("Home Stub"))),
      ),
    ));

    // --- ПРОВЕРКА UI ---
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text(AppStrings.t('login')), findsOneWidget);

    // --- ЭМУЛЯЦИЯ ---
    await tester.enterText(find.byType(TextField).first, 'test@flux.com');
    await tester.enterText(find.byType(TextField).at(1), '123456');

    // Находим кнопку и жмем
    final loginButton = find.widgetWithText(ElevatedButton, AppStrings.t('login'));
    await tester.tap(loginButton);

    // --- ПРОВЕРКА ЗАГРУЗКИ ---
    await tester.pump(); // Запускаем анимацию
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(mockAuthService.signInCalled, isTrue);

    // --- ПРОВЕРКА НАВИГАЦИИ ---
    // Ждем окончания всех таймеров и анимаций
    await tester.pumpAndSettle();

    // Проверяем, что мы ушли с экрана логина и видим "Home Stub"
    expect(find.text("Home Stub"), findsOneWidget);
  });
}