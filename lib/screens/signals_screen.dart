import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/alert_service.dart';
import 'chart_screen.dart';
import '../localization.dart'; // Добавил импорт

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  final AlertService _alertService = AlertService();

  @override
  void initState() {
    super.initState();
    _checkSignals();
    _alertService.markAllAsRead();
  }

  Future<void> _checkSignals() async {
    await _alertService.checkAlertsAndTrigger();
  }

  @override
  Widget build(BuildContext context) {
    // Оборачиваем в ValueListenableBuilder для мгновенной смены языка
    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, currentLang, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardColor = isDark ? Colors.grey[900] : Colors.white;
          final textColor = isDark ? Colors.white : Colors.black;

          return Scaffold(
            appBar: AppBar(
              title: Text(AppStrings.t('active_signals'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() {});
                    _checkSignals();
                  },
                )
              ],
            ),
            body: StreamBuilder<List<AlertModel>>(
              stream: _alertService.getAlertsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final alerts = snapshot.data!;
                if (alerts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(AppStrings.t('no_signals'), style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Text(AppStrings.t('set_alerts_hint'), style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                alerts.sort((a, b) {
                  if (a.status == AlertStatus.triggered && b.status != AlertStatus.triggered) return -1;
                  if (a.status != AlertStatus.triggered && b.status == AlertStatus.triggered) return 1;
                  return b.createdAt.compareTo(a.createdAt);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return _buildSignalCard(alert, cardColor!, textColor);
                  },
                );
              },
            ),
          );
        }
    );
  }

  Widget _buildSignalCard(AlertModel alert, Color cardColor, Color textColor) {
    final isTriggered = alert.status == AlertStatus.triggered;

    final statusColor = isTriggered ? Colors.redAccent : Colors.greenAccent;
    final statusBg = isTriggered ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1);

    // Локализация статуса
    final statusText = isTriggered ? AppStrings.t('status_triggered') : AppStrings.t('status_pending');
    final icon = isTriggered ? Icons.notifications_active : Icons.hourglass_empty;

    // Локализация типа условия (Price/RSI)
    final typeText = alert.type == AlertType.price ? AppStrings.t('price_type') : 'RSI';

    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _alertService.deleteAlert(alert.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChartScreen(
            ticker: alert.ticker,
            price: alert.value.toString(),
            change: AppStrings.t('loading'), // Локализация загрузки
            isPositive: true,
            isCrypto: alert.isCrypto,
          )));
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: isTriggered ? Border.all(color: Colors.redAccent.withOpacity(0.5)) : null,
            boxShadow: isTriggered
                ? [BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    alert.ticker.substring(0, min(3, alert.ticker.length)),
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(alert.ticker, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            children: [
                              Icon(icon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // "Condition: Price > 50000"
                      "${AppStrings.t('condition_label')} $typeText ${alert.condition == AlertCondition.greater ? '>' : '<'} ${alert.value}",
                      style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;
}