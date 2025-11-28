import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import '../services/auth_service.dart';
import '../localization.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  // Поля для тестирования (Dependency Injection)
  final AuthService? authService;
  final Widget? nextScreen; // Куда переходить после входа (для тестов подменим на заглушку)

  const LoginScreen({
    super.key,
    this.authService,
    this.nextScreen
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthService _authService; // Используем late, чтобы инициализировать в initState
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Если сервис передали (в тесте) - используем его, иначе создаем реальный
    _authService = widget.authService ?? AuthService();
  }

  // Метод входа
  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        // ЕСЛИ УСПЕХ:
        // Используем widget.nextScreen если он есть (для тестов), иначе HomeScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => widget.nextScreen ?? const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = AppStrings.t('error');
        // Простая обработка ошибок для пользователя
        if (e.toString().contains('user-not-found')) {
          message = AppStrings.t('user_not_found');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Диалог сброса пароля (оставляем без изменений)
  void _showResetPasswordDialog() {
    final resetEmailController = TextEditingController();
    if (_emailController.text.isNotEmpty) {
      resetEmailController.text = _emailController.text;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(AppStrings.t('reset_password_title'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppStrings.t('reset_password_desc'), style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: AppStrings.t('email'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppStrings.t('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isEmpty) return;
                try {
                  Navigator.pop(dialogContext);
                  await _authService.resetPassword(email);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppStrings.t('link_sent')), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  // Обработка ошибок сброса
                }
              },
              child: Text(AppStrings.t('send_link'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final inputFillColor = isDark ? Colors.grey[850] : Colors.grey[200];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/images/logo.png', width: 80, height: 80),
                Text(
                  AppStrings.t('app_name'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 2, color: textColor),
                ),
                Text(
                  AppStrings.t('slogan'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 16, color: subTextColor),
                ),
                const SizedBox(height: 60),

                // Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: AppStrings.t('email'),
                    hintStyle: TextStyle(color: subTextColor),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // Пароль
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: AppStrings.t('password'),
                    hintStyle: TextStyle(color: subTextColor),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),

                // Кнопка
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent[100],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  child: Text(AppStrings.t('login')),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                      },
                      child: Text(AppStrings.t('register'), style: TextStyle(color: subTextColor)),
                    ),
                    TextButton(
                      onPressed: _showResetPasswordDialog,
                      child: Text(AppStrings.t('forgot_password'), style: TextStyle(color: subTextColor)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}