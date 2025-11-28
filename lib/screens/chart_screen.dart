import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart';
import 'package:intl/intl.dart';

import '../services/market_service.dart';
import '../services/analysis_service.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../models/user_model.dart';
import '../localization.dart'; // Локализация
import '../widgets/ai_chat_sheet.dart';


class ChartScreen extends StatefulWidget {
  final String ticker;
  final String price;
  final String change;
  final bool isPositive;
  final bool isCrypto;

  const ChartScreen({
    super.key,
    required this.ticker,
    required this.price,
    required this.change,
    required this.isPositive,
    required this.isCrypto,
  });

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final MarketService _marketService = MarketService();
  final AlertService _alertService = AlertService();
  final AuthService _authService = AuthService();
  final WalletService _walletService = WalletService();

  UserModel? _currentUser;

  List<ChartSampleData> _chartData = [];
  late TrackballBehavior _trackballBehavior;
  late ZoomPanBehavior _zoomPanBehavior;

  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedTimeframe = '1H';
  final List<String> _timeframes = ['1M', '5M', '15M', '1H', '4H', '1D', '1W'];

  late String _currentPrice;
  late String _currentChange;
  late Color _currentPriceColor;
  late bool _isChangePositive;
  late String _timeLabel;

  double _rsiValue = 50.0;
  double _smaValue = 0.0;
  String _smaTrend = "Neutral";
  String _volatilityStatus = "Normal";

  List<double> _rsiHistory = [];
  List<double> _smaHistory = [];
  List<double> _volHistory = [];

  @override
  void initState() {
    super.initState();

    _currentPrice = widget.price;
    _currentChange = widget.change;
    _isChangePositive = widget.isPositive;
    _currentPriceColor = widget.isPositive ? Colors.greenAccent : Colors.redAccent;
    _timeLabel = widget.isCrypto ? "(24h)" : AppStrings.t('session');

    _trackballBehavior = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipDisplayMode: TrackballDisplayMode.floatAllPoints,
      tooltipSettings: const InteractiveTooltip(
        enable: true,
        canShowMarker: false,
        format: 'point.x\nO: point.open\nH: point.high\nL: point.low\nC: point.close',
      ),
      hideDelay: 2000,
    );

    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
    );

    _loadCurrentUser();
    _fetchCandles();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) setState(() => _currentUser = user);
  }

  Future<void> _fetchCandles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final results = await Future.wait([
        widget.isCrypto
            ? _marketService.getBinanceCandles(widget.ticker, _selectedTimeframe)
            : _marketService.getMoexCandles(widget.ticker, _selectedTimeframe),
        _marketService.getCurrentPrice(widget.ticker, widget.isCrypto),
      ]);

      List<CandleModel> candles = results[0] as List<CandleModel>;
      double? realTimePrice = results[1] as double?;

      if (mounted) {
        setState(() {
          if (candles.isEmpty) {
            _errorMessage = 'No data available';
          } else {
            _chartData = candles.map((c) => ChartSampleData(
              x: c.date,
              open: c.open,
              high: c.high,
              low: c.low,
              close: c.close,
            )).toList();

            if (_chartData.isNotEmpty) {
              final double actualPrice = realTimePrice ?? _chartData.last.close;
              _currentPrice = actualPrice.toStringAsFixed(actualPrice < 1.0 ? 5 : 2);

              double prevPrice = 0.0;

              if (widget.isCrypto) {
                final yesterday = DateTime.now().subtract(const Duration(hours: 24));
                ChartSampleData? targetCandle;
                for (var i = _chartData.length - 1; i >= 0; i--) {
                  if (_chartData[i].x.isBefore(yesterday)) {
                    targetCandle = _chartData[i];
                    break;
                  }
                }
                prevPrice = targetCandle?.close ?? _chartData.first.close;
                _timeLabel = "(24h)";
              } else {
                ChartSampleData? prevDayCandle;
                final currentDay = _chartData.last.x.day;
                for (var i = _chartData.length - 2; i >= 0; i--) {
                  if (_chartData[i].x.day != currentDay) {
                    prevDayCandle = _chartData[i];
                    break;
                  }
                }
                prevPrice = prevDayCandle?.close ?? _chartData.first.close;
                _timeLabel = AppStrings.t('session');
              }

              double changePct = 0.0;
              if (prevPrice != 0) {
                changePct = ((actualPrice - prevPrice) / prevPrice) * 100;
              }

              final sign = changePct >= 0 ? '+' : '';
              _currentChange = "$sign${changePct.toStringAsFixed(2)}%";
              _isChangePositive = changePct >= 0;
              _currentPriceColor = _isChangePositive ? Colors.greenAccent : Colors.redAccent;

              _calculateRealIndicators();
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Load Error';
        });
      }
    }
  }

  void _calculateRealIndicators() {
    final closes = _chartData.map((e) => e.close).toList();

    _rsiValue = AnalysisService.calculateRSI(closes);
    _rsiHistory = closes.length > 30 ? closes.sublist(closes.length - 30) : closes;

    _smaValue = AnalysisService.calculateSMA(closes, 20);
    _smaTrend = closes.last > _smaValue ? "Bullish" : "Bearish";
    _smaHistory = AnalysisService.calculateSMAHistory(closes, 20);
    if (_smaHistory.length > 30) _smaHistory = _smaHistory.sublist(_smaHistory.length - 30);

    final volFullList = AnalysisService.calculateVolatilityHistory(closes, 10);
    if (volFullList.isNotEmpty) {
      double currentVol = volFullList.last;
      double avgVol = volFullList.reduce((a, b) => a + b) / volFullList.length;
      _volatilityStatus = AnalysisService.getVolatilityStatus(currentVol, avgVol);
      _volHistory = volFullList;
      if (_volHistory.length > 30) _volHistory = _volHistory.sublist(_volHistory.length - 30);
    }
  }

  // --- FIX: TRADE SHEET ---

  void _showTradeSheet({required bool isBuy}) {
    final controller = TextEditingController();
    double price = double.tryParse(_currentPrice.replaceAll(',', '').replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

    if (price == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t('loading_price'))));
      return;
    }

    final String currencySymbol = widget.isCrypto ? "\$" : "₽";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      // ВАЖНО: Переименовываем context в sheetContext
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isBuy ? "${AppStrings.t('buy')} ${widget.ticker}" : "${AppStrings.t('sell')} ${widget.ticker}",
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold,
                        color: isBuy ? Colors.green : Colors.redAccent),
                  ),
                  Text("Price: $currencySymbol$_currentPrice", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),

              // Баланс
              if (isBuy)
                StreamBuilder<double>(
                  stream: _walletService.getBalanceStream(),
                  builder: (context, snapshot) {
                    return Text(
                      "${AppStrings.t('available_balance')}: \$${(snapshot.data ?? 0).toStringAsFixed(2)}",
                      style: const TextStyle(color: Colors.grey),
                    );
                  },
                )
              else
                StreamBuilder<List<AssetModel>>(
                  stream: _walletService.getPortfolioStream(),
                  builder: (context, snapshot) {
                    double assetAmount = 0.0;
                    if (snapshot.hasData) {
                      try {
                        final asset = snapshot.data!.firstWhere(
                                (element) => element.ticker == widget.ticker);
                        assetAmount = asset.amount;
                      } catch (_) {}
                    }
                    return Text(
                      "${AppStrings.t('available_asset')} ${widget.ticker}: ${assetAmount.toStringAsFixed(5)}",
                      style: const TextStyle(color: Colors.grey),
                    );
                  },
                ),

              const SizedBox(height: 10),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isBuy ? AppStrings.t('amount_usd') : "${AppStrings.t('amount_asset')} ${widget.ticker}",
                  border: const OutlineInputBorder(),
                  suffixText: isBuy ? "USD" : widget.ticker,
                ),
              ),
              const SizedBox(height: 20),

              // КНОПКА ПОДТВЕРЖДЕНИЯ
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBuy ? Colors.green : Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    final val = double.tryParse(controller.text.replaceAll(',', '.'));
                    if (val == null || val <= 0) return;

                    try {
                      FocusScope.of(sheetContext).unfocus(); // Используем sheetContext
                      Navigator.pop(sheetContext); // Используем sheetContext для закрытия шторки

                      if (isBuy) {
                        await _walletService.buyAsset(widget.ticker, price, val, widget.isCrypto);

                        if (!mounted) return; // Проверяем, жив ли ChartScreen

                        double priceInUsd = widget.isCrypto ? price : (price / 96.0);
                        String coins = (val / priceInUsd).toStringAsFixed(5);

                        _showSuccessDialog(
                            isBuy: true, amount: coins, ticker: widget.ticker, totalUsd: val.toStringAsFixed(2));

                      } else {
                        await _walletService.sellAsset(widget.ticker, price, val, widget.isCrypto);

                        if (!mounted) return; // Проверяем, жив ли ChartScreen

                        double priceInUsd = widget.isCrypto ? price : (price / 96.0);
                        String usd = (val * priceInUsd).toStringAsFixed(2);

                        _showSuccessDialog(
                            isBuy: false, amount: val.toString(), ticker: widget.ticker, totalUsd: usd);
                      }
                    } catch (e) {
                      if (!mounted) return; // Проверяем перед показом ошибки

                      String err = AppStrings.t('error');
                      if (e.toString().contains("insufficient_funds")) err = AppStrings.t('insufficient_funds');
                      if (e.toString().contains("insufficient_assets")) err = AppStrings.t('insufficient_assets');

                      // Используем глобальный context экрана (не шторки), который жив
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                    }
                  },
                  child: Text(
                      isBuy ? AppStrings.t('buy_action') : AppStrings.t('sell_action'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  // --- OTHER MODALS & UI ---

  void _showSuccessDialog({required bool isBuy, required String amount, required String ticker, required String totalUsd}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.green, size: 40),
              ),
              const SizedBox(height: 20),
              Text(AppStrings.t('transaction_success'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                isBuy
                    ? "${AppStrings.t('you_bought')} $amount $ticker ${AppStrings.t('for_price')} \$$totalUsd"
                    : "${AppStrings.t('you_sold')} $amount $ticker ${AppStrings.t('for_price')} \$$totalUsd",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppStrings.t('awesome'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAlertsModal(BuildContext context, Color cardColor, Color textColor, Color subTextColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) { // Используем sheetContext
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${AppStrings.t('alerts_title')} ${widget.ticker}",
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      ElevatedButton.icon(
                        onPressed: () => _showAddAlertDialog(context),
                        icon: const Icon(Icons.add, size: 18, color: Colors.black),
                        label: Text(AppStrings.t('add'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<AlertModel>>(
                    stream: _alertService.getAlertsStream(ticker: widget.ticker),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text("${AppStrings.t('error')}: ${snapshot.error}", style: TextStyle(color: subTextColor)));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                      final alerts = snapshot.data ?? [];
                      if (alerts.isEmpty) return Center(child: Text(AppStrings.t('no_alerts'), style: TextStyle(color: subTextColor)));

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: alerts.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final alert = alerts[index];
                          final isTriggered = alert.status == AlertStatus.triggered;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: isTriggered ? Border.all(color: Colors.redAccent) : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      // "Price > 50000"
                                      "${AppStrings.t('price_type')} ${alert.condition == AlertCondition.greater ? '>' : '<'} ${alert.value}",
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                    Text(
                                      // "TRIGGERED" / "ACTIVE"
                                      isTriggered ? AppStrings.t('status_triggered') : AppStrings.t('status_active'),
                                      style: TextStyle(
                                          color: isTriggered ? Colors.redAccent : Colors.greenAccent,
                                          fontSize: 12, fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                  onPressed: () => _alertService.deleteAlert(alert.id),
                                )
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddAlertDialog(BuildContext context) {
    AlertCondition condition = AlertCondition.greater;
    final TextEditingController valController = TextEditingController();
    valController.text = _currentPrice.replaceAll(',', '');

    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(AppStrings.t('create_alert_title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppStrings.t('notify_cond'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButton<AlertCondition>(
                    value: condition,
                    dropdownColor: Theme.of(context).cardColor,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(value: AlertCondition.greater, child: Text(AppStrings.t('cond_greater'))),
                      DropdownMenuItem(value: AlertCondition.less, child: Text(AppStrings.t('cond_less'))),
                    ],
                    onChanged: isSubmitting ? null : (val) => setStateDialog(() => condition = val!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: valController,
                    enabled: !isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: AppStrings.t('target_price'), border: const OutlineInputBorder()),
                  )
                ],
              ),
              actions: [
                if (!isSubmitting)
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.t('cancel'))),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    if (valController.text.isNotEmpty) {
                      setStateDialog(() => isSubmitting = true);
                      try {
                        await _alertService.createAlert(
                            ticker: widget.ticker,
                            isCrypto: widget.isCrypto,
                            condition: condition,
                            value: double.parse(valController.text.replaceAll(',', '.'))
                        );
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        if (mounted) {
                          setStateDialog(() => isSubmitting = false);
                          if (e.toString().contains("limit_reached")) {
                            Navigator.pop(context);
                            _showPaywall();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppStrings.t('error')}: $e")));
                          }
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text(AppStrings.t('create'), style: const TextStyle(color: Colors.black)),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showPaywall() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isLoading = false;
        bool isSuccess = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              // Локализация заголовка
              title: isSuccess ? null : Row(children: [const Icon(Icons.star, color: Colors.amber), const SizedBox(width: 10), Text(AppStrings.t('upgrade_pro'))]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading) ...[
                    const CircularProgressIndicator(color: Colors.amber),
                    const SizedBox(height: 20),
                    Text(AppStrings.t('processing_payment')), // Локализация
                  ] else if (isSuccess) ...[
                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
                    const SizedBox(height: 16),
                    Text(AppStrings.t('welcome_club'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Локализация
                  ] else ...[
                    Text(AppStrings.t('unlock_desc')), // Локализация
                    ListTile(leading: const Icon(Icons.check, color: Colors.green), title: Text(AppStrings.t('unlimited_alerts')), dense: true), // Локализация
                    ListTile(leading: const Icon(Icons.check, color: Colors.green), title: Text(AppStrings.t('advanced_analytics')), dense: true), // Локализация
                  ]
                ],
              ),
              actions: isLoading ? [] : [
                if (isSuccess)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () {
                        Navigator.pop(context);
                        _loadCurrentUser();
                      },
                      child: Text(AppStrings.t('lets_go'), style: const TextStyle(color: Colors.white)), // Локализация
                    ),
                  )
                else ...[
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.t('cancel'))), // Локализация
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    onPressed: () async {
                      setStateDialog(() => isLoading = true);
                      await Future.delayed(const Duration(seconds: 2));
                      final uid = _authService.getCurrentUserUid();
                      if (uid != null) await _walletService.deposit(0);
                      setStateDialog(() { isLoading = false; isSuccess = true; });
                    },
                    child: Text(AppStrings.t('subscribe_price'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), // Локализация
                  )
                ]
              ],
            );
          },
        );
      },
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final gridColor = isDark ? Colors.grey[800] : Colors.grey[300];

    double avgPrice = 0.0;
    if (_chartData.isNotEmpty) {
      avgPrice = (_chartData.last.high + _chartData.last.low) / 2;
    } else {
      String cleanPrice = widget.price.replaceAll(RegExp(r'[^0-9.]'), '');
      avgPrice = double.tryParse(cleanPrice) ?? 100.0;
    }

    int decimalPlaces = 2;
    if (avgPrice < 1.0) decimalPlaces = 5;
    else if (avgPrice > 5000) decimalPlaces = 0;

    final NumberFormat axisFormat = NumberFormat.currency(
        locale: 'en_US', symbol: '', decimalDigits: decimalPlaces
    );

    final String currencySymbol = widget.isCrypto ? "\$" : "₽";

    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, currentLang, child) {
          return Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.ticker, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
                  Text(
                    '$_selectedTimeframe • ${widget.isCrypto ? "Binance" : "MOEX"}',
                    style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                  ),
                ],
              ),
              actions: [
                // --- 1. НОВАЯ КНОПКА AI (Фиолетовые звезды) ---
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                  tooltip: "Ask AI",
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => FractionallySizedBox(
                        heightFactor: 0.85,
                        child: AIChatSheet(
                          ticker: widget.ticker,
                          price: _currentPrice,
                          rsi: _rsiValue.toStringAsFixed(2),
                          trend: _smaTrend,
                          volatility: _volatilityStatus,
                        ),
                      ),
                    );
                  },
                ),

                IconButton(
                  icon: const Icon(Icons.notifications_active_outlined),
                  color: textColor,
                  onPressed: () => _showAlertsModal(context, cardColor!, textColor, subTextColor!),
                ),
                StreamBuilder<List<String>>(
                  stream: _marketService.getFavoritesStream(),
                  builder: (context, snapshot) {
                    final favorites = snapshot.data ?? [];
                    final isFavorite = favorites.contains(widget.ticker);
                    return IconButton(
                      icon: Icon(
                        isFavorite ? Icons.star : Icons.star_border,
                        color: isFavorite ? Colors.amber : textColor,
                        size: 28,
                      ),
                      onPressed: () => _marketService.toggleFavorite(widget.ticker),
                    );
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isCrypto ? "$currencySymbol$_currentPrice" : "$_currentPrice $currencySymbol",
                          style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Row(
                          children: [
                            Icon(
                                _isChangePositive ? Icons.arrow_upward : Icons.arrow_downward,
                                color: _currentPriceColor,
                                size: 16
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_currentChange $_timeLabel',
                              style: GoogleFonts.poppins(color: _currentPriceColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Container(
                    height: 400,
                    padding: EdgeInsets.zero,
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: _currentPriceColor))
                        : _errorMessage.isNotEmpty
                        ? Center(child: Text(_errorMessage, style: TextStyle(color: subTextColor)))
                        : SfCartesianChart(
                      backgroundColor: Colors.transparent,
                      plotAreaBorderWidth: 0,
                      trackballBehavior: _trackballBehavior,
                      zoomPanBehavior: _zoomPanBehavior,
                      primaryXAxis: DateTimeAxis(
                        majorGridLines: const MajorGridLines(width: 0),
                        axisLine: const AxisLine(width: 0),
                        labelStyle: TextStyle(color: subTextColor, fontSize: 10),
                      ),
                      primaryYAxis: NumericAxis(
                        opposedPosition: true,
                        labelStyle: TextStyle(color: subTextColor, fontSize: 10),
                        majorGridLines: MajorGridLines(width: 0.5, color: gridColor),
                        axisLine: const AxisLine(width: 0),
                        numberFormat: axisFormat,
                        enableAutoIntervalOnZooming: true,
                      ),
                      series: <CartesianSeries<ChartSampleData, DateTime>>[
                        CandleSeries<ChartSampleData, DateTime>(
                          dataSource: _chartData,
                          xValueMapper: (ChartSampleData sales, _) => sales.x,
                          lowValueMapper: (ChartSampleData sales, _) => sales.low,
                          highValueMapper: (ChartSampleData sales, _) => sales.high,
                          openValueMapper: (ChartSampleData sales, _) => sales.open,
                          closeValueMapper: (ChartSampleData sales, _) => sales.close,
                          bearColor: Colors.redAccent,
                          bullColor: Colors.greenAccent,
                          enableSolidCandles: true,
                          animationDuration: 500,
                        )
                      ],
                    ),
                  ),

                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: _timeframes.map((tf) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tf),
                          selected: _selectedTimeframe == tf,
                          onSelected: (bool selected) {
                            if (selected && _selectedTimeframe != tf) {
                              setState(() => _selectedTimeframe = tf);
                              _fetchCandles();
                            }
                          },
                          selectedColor: isDark ? Colors.blueAccent[700] : Colors.blueAccent[100],
                          backgroundColor: cardColor,
                          labelStyle: TextStyle(
                              color: _selectedTimeframe == tf ? Colors.white : textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
                          showCheckmark: false,
                        ),
                      )).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(AppStrings.t('analytics_signals'), // Локализация
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  ),
                  const SizedBox(height: 10),

                  _buildIndicatorCard(
                    context,
                    title: "RSI (14)", // RSI обычно не переводят
                    value: _rsiValue.toStringAsFixed(1),
                    // Важно: getRsiSentiment возвращает англ. текст.
                    // Хорошо бы локализовать внутри AnalysisService, но пока оставим как есть или добавим маппинг.
                    subValue: AnalysisService.getRsiSentiment(_rsiValue),
                    trendColor: AnalysisService.getRsiColor(_rsiValue),
                    dataPoints: _rsiHistory,
                    cardColor: cardColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),

                  _buildIndicatorCard(
                    context,
                    title: AppStrings.t('trend_sma'), // Локализация
                    value: _smaTrend,
                    // Локализация условий
                    subValue: _smaTrend == "Bullish" ? AppStrings.t('buy_signal') : AppStrings.t('sell_signal'),
                    trendColor: _smaTrend == "Bullish" ? Colors.greenAccent : Colors.redAccent,
                    dataPoints: _smaHistory,
                    cardColor: cardColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),

                  _buildIndicatorCard(
                    context,
                    title: AppStrings.t('volatility'), // Локализация
                    value: _volatilityStatus,
                    subValue: AppStrings.t('risk_level'), // Локализация
                    trendColor: _volatilityStatus == "High Volatility" ? Colors.orangeAccent : Colors.blueAccent,
                    dataPoints: _volHistory,
                    cardColor: cardColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),

                  _buildLockedCard(
                    context,
                    title: AppStrings.t('macd'), // Локализация
                    subtitle: AppStrings.t('professional_grade'), // Локализация
                    cardColor: cardColor,
                    textColor: textColor,
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),

            bottomSheet: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showTradeSheet(isBuy: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(AppStrings.t('sell'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showTradeSheet(isBuy: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(AppStrings.t('buy'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }

  Widget _buildIndicatorCard(
      BuildContext context, {
        required String title,
        required String value,
        required String subValue,
        required Color trendColor,
        required List<double> dataPoints,
        required Color? cardColor,
        required Color textColor,
        required Color? subTextColor,
      }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 90),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
            : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: GoogleFonts.poppins(color: subTextColor, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: trendColor)),
                      const SizedBox(width: 6),
                      Text(subValue, style: GoogleFonts.poppins(fontSize: 10, color: trendColor, fontWeight: FontWeight.w600)),
                    ],
                  )
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: SfSparkLineChart(
                  color: trendColor,
                  data: dataPoints,
                  axisLineColor: Colors.transparent,
                  highPointColor: trendColor,
                  lowPointColor: trendColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required Color? cardColor,
        required Color textColor,
      }) {
    final hasAccess = _currentUser?.isPro ?? false;

    if (hasAccess) {
      return _buildIndicatorCard(context,
          title: title, value: "Bullish Cross", subValue: "Strong Buy",
          trendColor: Colors.amber, dataPoints: [10, 12, 15, 14, 18, 20, 25],
          cardColor: cardColor, textColor: textColor, subTextColor: Colors.grey);
    }

    return GestureDetector(
      onTap: _showPaywall,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minHeight: 90),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                        child: const Text("PRO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.lock_outline, color: Colors.amber, size: 28),
          ],
        ),
      ),
    );
  }
}