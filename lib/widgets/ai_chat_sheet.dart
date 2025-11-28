import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/ai_service.dart';

class AIChatSheet extends StatefulWidget {
  final String ticker;
  final String price;
  final String rsi;
  final String trend;
  final String volatility;

  const AIChatSheet({
    super.key,
    required this.ticker,
    required this.price,
    required this.rsi,
    required this.trend,
    required this.volatility,
  });

  @override
  State<AIChatSheet> createState() => _AIChatSheetState();
}

class _AIChatSheetState extends State<AIChatSheet> {
  final AIService _aiService = AIService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _uiMessages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _aiService.initChat(widget.ticker, widget.price, widget.rsi, widget.trend, widget.volatility);
    _sendInitialRequest();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendInitialRequest() async {
    setState(() {
      _uiMessages.add({'role': 'ai', 'text': 'Анализирую рынок по ${widget.ticker}...'});
      _isLoading = true;
    });

    // Первый скрытый промпт тоже можно написать по-русски для контекста, но бот и так поймет
    final response = await _aiService.sendMessage("Дай краткую техническую сводку и рекомендацию.");

    if (mounted) {
      setState(() {
        _uiMessages.removeLast();
        _uiMessages.add({'role': 'ai', 'text': response});
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _handleSend() async {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text.trim();
    _controller.clear();

    setState(() {
      _uiMessages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _scrollToBottom();

    final response = await _aiService.sendMessage(text);

    if (mounted) {
      setState(() {
        _uiMessages.add({'role': 'ai', 'text': response});
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Цвета немного подкрутил под "хакерский/трейдерский" стиль
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final bubbleColorAi = isDark ? const Color(0xFF2C2C2C) : Colors.grey[200];
    const bubbleColorUser = Colors.blueAccent;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // --- HEADER ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                const SizedBox(width: 10),
                Text("FLUX Аналитик",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),

          // --- CHAT ---
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _uiMessages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _uiMessages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent)
                        )
                    ),
                  );
                }

                final msg = _uiMessages[index];
                final isUser = msg['role'] == 'user';
                final msgText = msg['text']?.toString() ?? "";

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    decoration: BoxDecoration(
                      color: isUser ? bubbleColorUser : bubbleColorAi,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    child: isUser
                    // Для сообщения пользователя обычный текст
                        ? Text(msgText,
                        style: const TextStyle(color: Colors.white, fontSize: 15))
                    // Для AI - Markdown (чтобы жирным выделял BUY/SELL)
                        : MarkdownBody(
                      data: msgText,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 15,
                          height: 1.4, // Чуть больше межстрочный интервал для читаемости
                        ),
                        strong: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.purpleAccent : Colors.deepPurple
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // --- INPUT ---
          Padding(
            padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    // Важно для русского языка и нормальной работы клавиатуры
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black
                    ),
                    decoration: InputDecoration(
                      hintText: "Спроси про ${widget.ticker}...",
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isLoading ? Colors.grey : Colors.purpleAccent,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward, color: Colors.white),
                    onPressed: _isLoading ? null : _handleSend,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}