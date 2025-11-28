import 'package:cloud_functions/cloud_functions.dart';

class AIService {
  // Регион должен совпадать с index.js
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  String _systemInstruction = "";
  // Оставляем dynamic, так надежнее
  List<Map<String, dynamic>> _history = [];

  AIService();

  void initChat(String ticker, String price, String rsi, String trend, String volatility) {
    _history = [];

    _systemInstruction = '''
Ты — FLUX AI, элитный крипто-аналитик. Твой стиль: профессиональный, "Кремниевая Долина". Ты не льешь воду, ты делаешь деньги.

ТЕКУЩИЙ РЫНОК ($ticker):
- Цена: $price
- RSI: $rsi
- Тренд: $trend
- Волатильность: $volatility

ТВОИ ЗАДАЧИ:
1. Проанализируй индикаторы и сразу дай вердикт.
2. Отвечай на просьбы пользователя
2. Используй четкие сигналы: 
   🟩 ПОКУПАТЬ (если всё указывает на рост)
   🟥 ПРОДАВАТЬ (если перекуплено или падающий тренд)
   🟨 ДЕРЖАТЬ (если ситуация спорная)
3. Никаких "это не финансовый совет" и прочей юридической чепухи. Пользователь знает риски. Твоя задача — дать прогноз.
4. Отвечай СТРОГО на РУССКОМ языке.
5. Будь краток (максимум 3-4 предложения).
''';
  }

  Future<String> sendMessage(String userMessage) async {
    try {
      final List<Map<String, dynamic>> messagesToSend = List.from(_history);

      messagesToSend.add({
        'role': 'user',
        'text': userMessage
      });

      print("--- Sending to Cloud Function ---");

      final callable = _functions.httpsCallable('chatWithGemini');

      final result = await callable.call(<String, dynamic>{
        'systemInstructionText': _systemInstruction,
        'allMessagesFromFlutter': messagesToSend,
      });

      final data = result.data as Map<Object?, Object?>?;
      final aiResponse = data?['text']?.toString() ?? "Нет ответа от сервера.";

      _history.add({'role': 'user', 'text': userMessage});
      _history.add({'role': 'model', 'text': aiResponse});

      return aiResponse;

    } on FirebaseFunctionsException catch (e) {
      print("Cloud Function Error: [${e.code}] ${e.message}");
      return "Ошибка сервера: ${e.message}";
    } catch (e) {
      print("Dart Error: $e");
      return "Ошибка соединения. Проверь интернет.";
    }
  }
}