import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const double RUB_TO_USD_RATE = 96.0;

class AssetModel {
  final String ticker;
  final double amount;
  final double avgPrice; // <--- НОВОЕ ПОЛЕ (Средняя цена покупки в USD)

  AssetModel({
    required this.ticker,
    required this.amount,
    required this.avgPrice,
  });
}

class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<double> getBalanceStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0.0);

    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data()!.containsKey('balance')) {
        return (snapshot.data()!['balance'] as num).toDouble();
      }
      return 0.0;
    });
  }

  // Чтение портфеля с avgPrice
  Stream<List<AssetModel>> getPortfolioStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db.collection('users').doc(uid).collection('portfolio').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AssetModel(
          ticker: doc.id,
          amount: (data['amount'] as num).toDouble(),
          // Если поле старое и avgPrice нет, ставим 0
          avgPrice: (data['avgPrice'] as num?)?.toDouble() ?? 0.0,
        );
      }).where((asset) => asset.amount > 0).toList();
    });
  }

  Future<void> deposit(double amount) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'balance': FieldValue.increment(amount)
    }, SetOptions(merge: true));
  }

  // --- КУПИТЬ (С пересчетом средней цены) ---
  Future<void> buyAsset(String ticker, double rawPrice, double amountInUsd, bool isCrypto) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("Auth required");

    final userRef = _db.collection('users').doc(uid);
    final assetRef = userRef.collection('portfolio').doc(ticker);

    // Цена покупки всегда приводится к USD для расчетов портфеля
    double priceInUsd = isCrypto ? rawPrice : (rawPrice / RUB_TO_USD_RATE);

    await _db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final assetSnapshot = await transaction.get(assetRef);

      // 1. Проверка баланса
      double currentBalance = 0.0;
      if (userSnapshot.exists && userSnapshot.data()!.containsKey('balance')) {
        currentBalance = (userSnapshot.data()!['balance'] as num).toDouble();
      }
      if (currentBalance < amountInUsd - 0.00000001) {
        throw Exception("insufficient_funds");
      }

      // 2. Данные актива
      double currentAmount = 0.0;
      double currentAvgPrice = 0.0;

      if (assetSnapshot.exists) {
        final data = assetSnapshot.data()!;
        currentAmount = (data['amount'] as num).toDouble();
        currentAvgPrice = (data['avgPrice'] as num?)?.toDouble() ?? 0.0;
      }

      // 3. Вычисляем сколько купили
      double boughtAmount = amountInUsd / priceInUsd;

      // 4. МАТЕМАТИКА СРЕДНЕЙ ЦЕНЫ (Weighted Average)
      // НоваяСредняя = ((СтароеКолво * СтараяЦена) + (НовоеКолво * НоваяЦена)) / ОбщееКолво
      double totalCostOld = currentAmount * currentAvgPrice;
      double totalCostNew = boughtAmount * priceInUsd; // это равно amountInUsd

      double newTotalAmount = currentAmount + boughtAmount;
      double newAvgPrice = (totalCostOld + totalCostNew) / newTotalAmount;

      // 5. Запись
      transaction.update(userRef, {'balance': FieldValue.increment(-amountInUsd)});

      transaction.set(assetRef, {
        'amount': newTotalAmount,
        'avgPrice': newAvgPrice, // Сохраняем новую среднюю
      }, SetOptions(merge: true));
    });
  }

  // --- ПРОДАТЬ (Средняя цена НЕ меняется) ---
  Future<void> sellAsset(String ticker, double rawPrice, double amountInAsset, bool isCrypto) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("Auth required");

    final userRef = _db.collection('users').doc(uid);
    final assetRef = userRef.collection('portfolio').doc(ticker);

    double priceInUsd = isCrypto ? rawPrice : (rawPrice / RUB_TO_USD_RATE);

    await _db.runTransaction((transaction) async {
      final assetSnapshot = await transaction.get(assetRef);

      double currentAmount = 0.0;
      if (assetSnapshot.exists) {
        currentAmount = (assetSnapshot.data()!['amount'] as num).toDouble();
      }

      const double epsilon = 0.00000001;
      if (currentAmount < amountInAsset - epsilon) {
        throw Exception("insufficient_assets");
      }

      double usdAmount = amountInAsset * priceInUsd;
      double newAmount = currentAmount - amountInAsset;
      if (newAmount < epsilon) newAmount = 0;

      // При продаже avgPrice мы НЕ трогаем (FIFO/Weighted logic - цена входа остается прежней)
      transaction.update(assetRef, {'amount': newAmount});
      transaction.update(userRef, {'balance': FieldValue.increment(usdAmount)});
    });
  }
}