import 'dart:math';

import 'package:flutter/material.dart';

// Модель данных для графика (вынесли, чтобы была доступна везде)
class ChartSampleData {
  ChartSampleData({
    required this.x,
    required this.open,
    required this.high,
    required this.low,
    required this.close
  });

  final DateTime x;
  final double open;
  final double high;
  final double low;
  final double close;
}

class AnalysisService {
  // Расчет RSI
  static double calculateRSI(List<double> prices, {int period = 14}) {
    if (prices.length < period + 1) return 50.0;
    double gain = 0.0;
    double loss = 0.0;

    for (int i = 1; i <= period; i++) {
      double change = prices[i] - prices[i - 1];
      if (change > 0) gain += change;
      else loss -= change;
    }

    double avgGain = gain / period;
    double avgLoss = loss / period;

    for (int i = period + 1; i < prices.length; i++) {
      double change = prices[i] - prices[i - 1];
      if (change > 0) {
        avgGain = (avgGain * (period - 1) + change) / period;
        avgLoss = (avgLoss * (period - 1)) / period;
      } else {
        avgGain = (avgGain * (period - 1)) / period;
        avgLoss = (avgLoss * (period - 1) - change) / period;
      }
    }

    if (avgLoss == 0) return 100.0;
    double rs = avgGain / avgLoss;
    return 100.0 - (100.0 / (1.0 + rs));
  }

  // Расчет SMA (Simple Moving Average)
  static double calculateSMA(List<double> prices, int period) {
    if (prices.length < period) return prices.isNotEmpty ? prices.last : 0.0;
    double sum = 0;
    for (int i = prices.length - period; i < prices.length; i++) {
      sum += prices[i];
    }
    return sum / period;
  }

  static List<double> calculateSMAHistory(List<double> prices, int period) {
    List<double> smaList = [];
    if (prices.length < period) return [];

    // Начинаем с period-го элемента
    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1) {
        // Если истории не хватает, можно добавлять null или 0, или просто пропускать
        // Для Sparkline лучше пропускать или дублировать цену
        // smaList.add(prices[i]); // Вариант: пока нет SMA, рисуем цену
        continue;
      }

      // Считаем среднее за последние [period] точек
      double sum = 0;
      for (int j = 0; j < period; j++) {
        sum += prices[i - j];
      }
      smaList.add(sum / period);
    }
    return smaList;
  }


  // 2. VOLATILITY HISTORY (Стандартное отклонение за N свечей)
  static List<double> calculateVolatilityHistory(List<double> prices, int period) {
    List<double> volList = [];
    if (prices.length < period) return [];

    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1) continue;

      // 1. Считаем среднее (SMA)
      double sum = 0;
      for (int j = 0; j < period; j++) {
        sum += prices[i - j];
      }
      double mean = sum / period;

      // 2. Считаем дисперсию
      double sumSquaredDiff = 0;
      for (int j = 0; j < period; j++) {
        double diff = prices[i - j] - mean;
        sumSquaredDiff += diff * diff;
      }

      // 3. Стандартное отклонение
      double stdDev = sqrt(sumSquaredDiff / period);
      volList.add(stdDev);
    }
    return volList;
  }


  // Средний разброс (для волатильности)
  static double calculateAvgRange(List<ChartSampleData> candles, int period) {
    if (candles.length < period) return 0;
    double sumRange = 0;
    for (int i = candles.length - period; i < candles.length; i++) {
      sumRange += (candles[i].high - candles[i].low);
    }
    return sumRange / period;
  }

  static String getRsiSentiment(double rsi) {
    if (rsi > 70) return "Overbought";
    if (rsi < 30) return "Oversold";
    return "Neutral";
  }

  static Color getRsiColor(double rsi) {
    if (rsi > 70) return Colors.redAccent;
    if (rsi < 30) return Colors.greenAccent;
    return Colors.blueAccent;
  }

  static String getVolatilityStatus(double currentVol, double avgVol) {
    if (currentVol > avgVol * 1.5) return "High Volatility";
    if (currentVol < avgVol * 0.7) return "Low Volatility";
    return "Normal";
  }
}
