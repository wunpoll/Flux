import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- МОДЕЛИ ДАННЫХ ---

class TickerModel {
  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final bool isCrypto;
  final double rsi;

  TickerModel({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.isCrypto,
    double? rsi,
  }) : rsi = rsi ?? _estimateRSI(changePercent);

  // Имитация RSI для сортировки списка
  static double _estimateRSI(double change) {
    double base = 50.0;
    double estimated = base + (change * 4);
    if (estimated > 95) return 95.0;
    if (estimated < 5) return 5.0;
    return estimated;
  }
}

class CandleModel {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;

  CandleModel({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

// --- СЕРВИС ---

class MarketService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==========================================
  // 1. ПОЛУЧЕНИЕ СПИСКОВ (Для Главной)
  // ==========================================

  Future<List<TickerModel>> getMoexStocks() async {
    try {
      // Добавляем rand, чтобы избежать кэширования
      final String cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      final url = Uri.parse('https://iss.moex.com/iss/engines/stock/markets/shares/boards/TQBR/securities.json?rand=$cacheBuster');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final columns = List<String>.from(data['marketdata']['columns']);
        final rows = data['marketdata']['data'] as List;
        final secColumns = List<String>.from(data['securities']['columns']);
        final secRows = data['securities']['data'] as List;

        final idxLast = columns.indexOf('LAST');
        final idxPrev = columns.indexOf('LCURRENTPRICE');
        final idxSecId = columns.indexOf('SECID');
        final idxSecIdInfo = secColumns.indexOf('SECID');
        final idxName = secColumns.indexOf('SHORTNAME');

        Map<String, String> names = {};
        for (var row in secRows) {
          names[row[idxSecIdInfo]] = row[idxName] ?? row[idxSecIdInfo];
        }

        List<TickerModel> stocks = [];
        for (var row in rows) {
          final price = (row[idxLast] ?? 0).toDouble();
          if (price == 0) continue;

          final prevPrice = (row[idxPrev] ?? price).toDouble();
          double change = 0.0;
          if (prevPrice != 0) {
            change = ((price - prevPrice) / prevPrice) * 100;
          }

          stocks.add(TickerModel(
            symbol: row[idxSecId],
            name: names[row[idxSecId]] ?? row[idxSecId],
            price: price,
            changePercent: change,
            isCrypto: false,
          ));
        }
        return stocks;
      }
    } catch (e) {
      print("MOEX Error: $e");
    }
    return [];
  }

  Future<List<TickerModel>> getCryptoStocks() async {
    try {
      final url = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data
            .where((e) => e['symbol'].toString().endsWith('USDT'))
            .take(100)
            .map((e) {
          final price = double.parse(e['lastPrice']);
          final change = double.parse(e['priceChangePercent']);
          final symbol = e['symbol'].toString().replaceAll('USDT', '');
          return TickerModel(
            symbol: symbol,
            name: symbol,
            price: price,
            changePercent: change,
            isCrypto: true,
          );
        }).toList();
      }
    } catch (e) {
      print("Binance Error: $e");
    }
    return [];
  }

  // ==========================================
  // 2. НОВЫЙ МЕТОД: ТОЧНАЯ ЦЕНА (Real-Time)
  // ==========================================

  Future<double?> getCurrentPrice(String ticker, bool isCrypto) async {
    try {
      if (isCrypto) {
        // BINANCE
        final symbol = ticker.toUpperCase().endsWith('USDT') ? ticker : '${ticker}USDT';
        final url = Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=$symbol');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return double.parse(data['price']);
        }
      } else {
        // MOEX
        final upperTicker = ticker.toUpperCase();
        // Запрашиваем конкретную бумагу
        final url = Uri.parse(
            'https://iss.moex.com/iss/engines/stock/markets/shares/boards/TQBR/securities/$upperTicker.json');
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);

          if (jsonResponse['marketdata'] != null) {
            final columns = List<String>.from(jsonResponse['marketdata']['columns']);
            final rows = jsonResponse['marketdata']['data'] as List;

            final idxLast = columns.indexOf('LAST');
            if (idxLast != -1 && rows.isNotEmpty) {
              final val = rows[0][idxLast];
              return (val as num?)?.toDouble();
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching real-time price: $e");
    }
    return null;
  }

  // ==========================================
  // 3. ПОЛУЧЕНИЕ ИСТОРИИ (Свечи)
  // ==========================================

  Future<List<CandleModel>> getMoexCandles(String ticker, String interval) async {
    String moexInterval = '60';
    int durationInDays = 2; // Дефолт

    switch (interval) {
      case '1M': moexInterval = '1'; durationInDays = 5; break; // Берем запас на выходные
      case '5M': moexInterval = '10'; durationInDays = 7; break;
      case '15M': moexInterval = '10'; durationInDays = 10; break;
      case '1H': moexInterval = '60'; durationInDays = 60; break;
      case '4H': moexInterval = '60'; durationInDays = 90; break;
      case '1D': moexInterval = '24'; durationInDays = 365; break;
      case '1W': moexInterval = '7'; durationInDays = 730; break;
    }

    try {
      final upperTicker = ticker.toUpperCase();
      final DateTime startDate = DateTime.now().subtract(Duration(days: durationInDays));
      final String fromDateStr = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";

      final url = Uri.parse(
          'https://iss.moex.com/iss/engines/stock/markets/shares/boards/TQBR/securities/$upperTicker/candles.json?interval=$moexInterval&from=$fromDateStr');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['candles'] != null && jsonResponse['candles']['data'] != null) {
          final List data = jsonResponse['candles']['data'];
          final List<String> columns = List<String>.from(jsonResponse['candles']['columns']);

          final idxOpen = columns.indexOf('open');
          final idxClose = columns.indexOf('close');
          final idxHigh = columns.indexOf('high');
          final idxLow = columns.indexOf('low');
          final idxDate = columns.indexOf('begin');

          if (idxOpen == -1 || idxClose == -1 || idxDate == -1) return [];

          return data.map((e) => CandleModel(
            date: DateTime.parse(e[idxDate]),
            open: (e[idxOpen] as num).toDouble(),
            close: (e[idxClose] as num).toDouble(),
            high: (e[idxHigh] as num).toDouble(),
            low: (e[idxLow] as num).toDouble(),
          )).toList();
        }
      }
    } catch (e) {
      print("MOEX Candles Error: $e");
    }
    return [];
  }

  Future<List<CandleModel>> getBinanceCandles(String ticker, String interval) async {
    String binanceInterval = interval.toLowerCase();
    final symbol = ticker.toUpperCase().endsWith('USDT') ? ticker : '${ticker}USDT';

    try {
      final url = Uri.parse(
          'https://api.binance.com/api/v3/klines?symbol=$symbol&interval=$binanceInterval&limit=100');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List rawData = json.decode(response.body);
        return rawData.map((e) => CandleModel(
          date: DateTime.fromMillisecondsSinceEpoch(e[0]),
          open: double.parse(e[1]),
          high: double.parse(e[2]),
          low: double.parse(e[3]),
          close: double.parse(e[4]),
        )).toList();
      }
    } catch (e) {
      print("Binance Candles Error: $e");
    }
    return [];
  }

  // ==========================================
  // 4. ИЗБРАННОЕ
  // ==========================================

  Stream<List<String>> getFavoritesStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data()!.containsKey('favorites')) {
        return List<String>.from(snapshot.data()!['favorites']);
      }
      return [];
    });
  }

  Future<void> toggleFavorite(String ticker) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();

    if (doc.exists) {
      List<dynamic> favs = doc.data()?['favorites'] ?? [];
      if (favs.contains(ticker)) {
        favs.remove(ticker);
      } else {
        favs.add(ticker);
      }
      await docRef.update({'favorites': favs});
    } else {
      await docRef.set({'favorites': [ticker]}, SetOptions(merge: true));
    }
  }
}