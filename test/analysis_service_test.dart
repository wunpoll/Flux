import 'package:flutter_test/flutter_test.dart';
import 'package:flux/services/analysis_service.dart'; // Убедись, что путь правильный (название твоего проекта)

void main() {
  group('AnalysisService Tests', () {

    // --- ТЕСТЫ SMA (Simple Moving Average) ---

    test('Calculate SMA should return correct average for simple numbers', () {
      // Подготовка: 5 чисел
      final prices = [10.0, 20.0, 30.0, 40.0, 50.0];

      // Действие: Считаем SMA с периодом 5
      final result = AnalysisService.calculateSMA(prices, 5);

      // Проверка: (10+20+30+40+50) / 5 = 30
      expect(result, 30.0);
    });

    test('Calculate SMA should handle period larger than data length', () {
      // Если данных меньше, чем период, мы договорились возвращать последнюю цену
      final prices = [100.0, 105.0];
      final result = AnalysisService.calculateSMA(prices, 14);

      expect(result, 105.0);
    });

    test('Calculate SMA return 0 for empty list', () {
      final result = AnalysisService.calculateSMA([], 14);
      expect(result, 0.0);
    });

    // --- ТЕСТЫ RSI (Relative Strength Index) ---

    test('RSI should return 50.0 if not enough data', () {
      // Для RSI нужно минимум (period + 1) точек
      final prices = [100.0, 101.0, 102.0];

      final result = AnalysisService.calculateRSI(prices, period: 14);

      expect(result, 50.0);
    });

    test('RSI should be 100 for constantly rising price (Ideal Bull run)', () {
      // Генерируем список, где цена только растет
      List<double> prices = [];
      for (int i = 0; i < 30; i++) {
        prices.add(100.0 + i * 5); // 100, 105, 110...
      }

      final result = AnalysisService.calculateRSI(prices, period: 14);

      // В идеальном росте без откатов RSI должен стремиться к 100
      expect(result, closeTo(100.0, 0.1));
    });

    test('RSI Sentiment returns correct text', () {
      expect(AnalysisService.getRsiSentiment(80.0), "Overbought");
      expect(AnalysisService.getRsiSentiment(20.0), "Oversold");
      expect(AnalysisService.getRsiSentiment(50.0), "Neutral");
    });

    // --- ТЕСТЫ ВОЛАТИЛЬНОСТИ ---

    test('Volatility Status detects High Volatility', () {
      // Текущая волатильность (10) сильно больше средней (5)
      final status = AnalysisService.getVolatilityStatus(10.0, 5.0);
      expect(status, "High Volatility");
    });

    test('Volatility Status detects Low Volatility', () {
      // Текущая волатильность (2) сильно меньше средней (10)
      final status = AnalysisService.getVolatilityStatus(2.0, 10.0);
      expect(status, "Low Volatility");
    });

    test('Volatility Status detects Normal', () {
      // Примерно одинаково
      final status = AnalysisService.getVolatilityStatus(5.5, 5.0);
      expect(status, "Normal");
    });

  });
}