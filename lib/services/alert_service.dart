import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'market_service.dart'; // Нужно для проверки цен (имитация бэкенда)

// --- ENUMS ---
enum AlertType { price }
enum AlertCondition { greater, less }
enum AlertStatus { active, triggered }

// --- MODEL ---
class AlertModel {
  final String id;
  final String ticker;
  final bool isCrypto;
  final AlertType type;
  final AlertCondition condition;
  final double value;
  final AlertStatus status;
  final bool isRead;
  final DateTime createdAt;

  AlertModel({
    required this.id,
    required this.ticker,
    required this.isCrypto,
    required this.type,
    required this.condition,
    required this.value,
    required this.status,
    required this.isRead,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'ticker': ticker,
      'isCrypto': isCrypto,
      'type': type.toString(),
      'condition': condition.toString(),
      'value': value,
      'status': status.toString(),
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AlertModel.fromMap(String id, Map<String, dynamic> map) {
    return AlertModel(
      id: id,
      ticker: map['ticker'],
      isCrypto: map['isCrypto'],
      type: AlertType.values.firstWhere(
            (e) => e.toString() == map['type'],
        orElse: () => AlertType.price,
      ),
      condition: AlertCondition.values.firstWhere(
            (e) => e.toString() == map['condition'],
        orElse: () => AlertCondition.greater,
      ),
      value: (map['value'] as num).toDouble(),
      status: AlertStatus.values.firstWhere(
            (e) => e.toString() == map['status'],
        orElse: () => AlertStatus.active,
      ),
      isRead: map['isRead'] ?? true,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

// --- SERVICE ---
class AlertService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. СОЗДАТЬ УВЕДОМЛЕНИЕ (С ПРОВЕРКОЙ РОЛИ)
  Future<void> createAlert({
    required String ticker,
    required bool isCrypto,
    required AlertCondition condition,
    required double value,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // --- НАЧАЛО БЛОКА ПРОВЕРКИ ---

    // А. Получаем роль пользователя
    final userDoc = await _db.collection('users').doc(uid).get();
    final role = userDoc.data()?['role'] ?? 'guest';
    final isPro = role == 'pro' || role == 'admin';

    // Б. Считаем, сколько у него уже есть алертов
    final alertsSnapshot = await _db.collection('users').doc(uid).collection('alerts').get();
    final currentCount = alertsSnapshot.docs.length;

    // В. Если он НЕ Pro и уже 5 алертов -> Выдаем ошибку
    if (!isPro && currentCount >= 3) {
      throw Exception("limit_reached");
      // Эту ошибку мы ловим в UI (chart_screen) и показываем окно оплаты
    }

    // --- КОНЕЦ БЛОКА ПРОВЕРКИ ---

    // Если всё ок, создаем алерт
    final newAlert = AlertModel(
      id: '',
      ticker: ticker,
      isCrypto: isCrypto,
      type: AlertType.price,
      condition: condition,
      value: value,
      status: AlertStatus.active,
      isRead: true,
      createdAt: DateTime.now(),
    );

    await _db.collection('users').doc(uid).collection('alerts').add(newAlert.toMap());
  }

  // 2. ПОЛУЧИТЬ ПОТОК (С СОРТИРОВКОЙ НА КЛИЕНТЕ)
  Stream<List<AlertModel>> getAlertsStream({String? ticker}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    Query query = _db.collection('users').doc(uid).collection('alerts');

    if (ticker != null) {
      query = query.where('ticker', isEqualTo: ticker);
    }

    return query.snapshots().map((snapshot) {
      final alerts = snapshot.docs.map((doc) {
        return AlertModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      // Сортируем тут, чтобы не создавать индексы в Firebase Console
      alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return alerts;
    });
  }

  // 3. УДАЛИТЬ УВЕДОМЛЕНИЕ
  Future<void> deleteAlert(String alertId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('alerts').doc(alertId).delete();
  }

  // 4. ПОМЕТИТЬ ВСЕ КАК ПРОЧИТАННЫЕ
  Future<void> markAllAsRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await _db.collection('users').doc(uid).collection('alerts')
        .where('status', isEqualTo: AlertStatus.triggered.toString())
        .where('isRead', isEqualTo: false)
        .get();

    WriteBatch batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // 5. ПРОВЕРКА ЦЕН (ИМИТАЦИЯ БЭКЕНДА)
  Future<void> checkAlertsAndTrigger() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Получаем только активные
    final snapshot = await _db.collection('users').doc(uid).collection('alerts')
        .where('status', isEqualTo: AlertStatus.active.toString())
        .get();

    final alerts = snapshot.docs.map((doc) => AlertModel.fromMap(doc.id, doc.data())).toList();
    if (alerts.isEmpty) return;

    // Получаем текущие цены
    final MarketService marketService = MarketService();
    // В реальном проекте тут лучше batch запрос, но для MVP качаем списки
    final allCrypto = await marketService.getCryptoStocks();
    final allMoex = await marketService.getMoexStocks();

    WriteBatch batch = _db.batch();
    bool batchHasUpdates = false;

    for (var alert in alerts) {
      double currentPrice = 0.0;

      // Ищем текущую цену актива
      if (alert.isCrypto) {
        final item = allCrypto.firstWhere(
              (e) => e.symbol == alert.ticker,
          orElse: () => TickerModel(symbol: '', name: '', price: 0, changePercent: 0, isCrypto: true),
        );
        currentPrice = item.price;
      } else {
        final item = allMoex.firstWhere(
              (e) => e.symbol == alert.ticker,
          orElse: () => TickerModel(symbol: '', name: '', price: 0, changePercent: 0, isCrypto: false),
        );
        currentPrice = item.price;
      }

      if (currentPrice == 0) continue;

      // Проверяем условие
      bool isTriggered = false;
      if (alert.condition == AlertCondition.greater && currentPrice >= alert.value) isTriggered = true;
      if (alert.condition == AlertCondition.less && currentPrice <= alert.value) isTriggered = true;

      if (isTriggered) {
        // Если сработало: меняем статус и ставим "не прочитано"
        batch.update(_db.collection('users').doc(uid).collection('alerts').doc(alert.id), {
          'status': AlertStatus.triggered.toString(),
          'isRead': false,
        });
        batchHasUpdates = true;
      }
    }

    if (batchHasUpdates) {
      await batch.commit();
    }
  }
}