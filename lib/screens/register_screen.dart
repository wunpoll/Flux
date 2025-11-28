import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import '../localization.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // Функция регистрации
  // Внутри метода _register() в register_screen.dart

  void _register() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      // ... показ ошибки
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ВАЖНО: Вызываем signUp (Регистрация)
      await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        // Успех -> на главную
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      // Обработка ошибок
      String message = 'Ошибка регистрации';
      if (e.toString().contains('email-already-in-use')) {
        message = 'Этот Email уже занят. Попробуйте войти.';
      } else if (e.toString().contains('weak-password')) {
        message = 'Пароль слишком простой (минимум 6 символов)';
      } else if (e.toString().contains('invalid-email')) {
        message = 'Некорректный Email';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Переменные темы
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputFillColor = isDark ? Colors.grey[850] : Colors.grey[200];
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Кнопка "Назад" должна быть видна на любом фоне
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 80,
                  height: 80,
                ),
                Text(
                  'FLUX',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                Text(
                  'Advantage Trading',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[400]),
                ),
                const SizedBox(height: 60),
                Text(
                  AppStrings.t('create_account'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: textColor, // Адаптивный цвет
                  ),
                ),
                const SizedBox(height: 40),

                // Передаем цвета в наш helper-метод
                _buildTextField(
                    _emailController, AppStrings.t('email'), false, inputFillColor!, textColor,
                    hintColor!),
                const SizedBox(height: 16),
                _buildTextField(
                    _passwordController, AppStrings.t('password'), true, inputFillColor,
                    textColor, hintColor),
                const SizedBox(height: 16),
                _buildTextField(
                    _confirmPasswordController, AppStrings.t('confirm_password'), true,
                    inputFillColor, textColor, hintColor),
                const SizedBox(height: 24),

                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent[100],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(AppStrings.t('register'),
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Обновляем метод создания полей
  Widget _buildTextField(TextEditingController controller,
      String hint,
      bool isPassword,
      Color fillColor,
      Color textColor,
      Color hintColor) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: textColor), // Цвет текста
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor),
        // Цвет подсказки
        filled: true,
        fillColor: fillColor,
        // Цвет фона поля
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}