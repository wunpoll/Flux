import 'package:flutter/material.dart';
import 'package:flux/screens/signals_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chart_screen.dart';
import 'settings_screen.dart';
import '../localization.dart'; // ВАЖНО: Импорт локализации
import '../services/market_service.dart';
import '../services/alert_service.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;
  final AlertService _alertService = AlertService();
  Timer? _bgTimer;

  @override
  void initState() {
    super.initState();
    _pages = [
      const MarketPage(),
      const SignalsScreen(),
      const SettingsScreen(),
    ];

    _alertService.checkAlertsAndTrigger();

    _bgTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      print("Background Check: Checking alerts...");
      _alertService.checkAlertsAndTrigger();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _bgTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Оборачиваем в слушатель языка
    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, currentLang, child) {
          return Scaffold(
            body: _pages[_selectedIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              items: [
                BottomNavigationBarItem(
                    icon: const Icon(Icons.bar_chart_rounded),
                    label: AppStrings.t('market')
                ),
                BottomNavigationBarItem(
                  icon: StreamBuilder<List<AlertModel>>(
                    stream: _alertService.getAlertsStream(),
                    builder: (context, snapshot) {
                      bool hasUnread = false;
                      if (snapshot.hasData) {
                        hasUnread = snapshot.data!.any((alert) =>
                        alert.status == AlertStatus.triggered && !alert.isRead);
                      }

                      return Badge(
                        isLabelVisible: hasUnread,
                        backgroundColor: Colors.redAccent,
                        smallSize: 10,
                        child: const Icon(Icons.bolt_rounded),
                      );
                    },
                  ),
                  label: AppStrings.t('signals'),
                ),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.settings),
                    label: AppStrings.t('settings')
                ),
              ],
            ),
          );
        }
    );
  }
}

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MarketService _marketService = MarketService();
  Timer? _refreshTimer;

  List<TickerModel> _allMoex = [];
  List<TickerModel> _allCrypto = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _sortBy = 'alphabet';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();

    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadData(silent: true);
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    final moex = await _marketService.getMoexStocks();
    final crypto = await _marketService.getCryptoStocks();

    if (mounted) {
      setState(() {
        _allMoex = moex;
        _allCrypto = crypto;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Также оборачиваем в слушатель языка
    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, currentLang, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final inputFillColor = isDark ? Colors.grey[900] : Colors.grey[200];
          final textColor = isDark ? Colors.white : Colors.black;

          return Scaffold(
            appBar: AppBar(
              title: _buildSearchBar(inputFillColor!, textColor),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).primaryColor,
                labelColor: textColor,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: AppStrings.t('moex')),
                  Tab(text: AppStrings.t('crypto')),
                ],
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: Icon(Icons.sort, color: textColor),
                  onSelected: (value) => setState(() => _sortBy = value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                        value: 'alphabet', child: Text(AppStrings.t('sort_alphabet'))), // Локализация
                    PopupMenuItem(
                        value: 'change_asc', child: Text(AppStrings.t('sort_loss'))), // Локализация
                    PopupMenuItem(
                        value: 'change_desc', child: Text(AppStrings.t('sort_gain'))), // Локализация
                    PopupMenuItem(value: 'rsi_desc', child: Text(AppStrings.t('sort_rsi_overbought'))), // Локализация
                    PopupMenuItem(value: 'rsi_asc', child: Text(AppStrings.t('sort_rsi_oversold'))), // Локализация
                  ],
                ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<String>>(
              stream: _marketService.getFavoritesStream(),
              builder: (context, snapshot) {
                final favorites = snapshot.data ?? [];

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_allMoex, favorites),
                    _buildList(_allCrypto, favorites),
                  ],
                );
              },
            ),
          );
        }
    );
  }

  Widget _buildSearchBar(Color fillColor, Color textColor) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: AppStrings.t('search_hint'), // Локализация
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
            onPressed: () => _searchController.clear(),
          )
              : null,
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<TickerModel> allItems, List<String> favorites) {
    List<TickerModel> visibleItems;

    if (_searchQuery.isEmpty) {
      visibleItems = allItems.where((item) => favorites.contains(item.symbol)).toList();

      if (visibleItems.isEmpty) {
        return Center(
          child: Text(
            AppStrings.t('favorites_empty_hint'), // Локализация
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        );
      }
    } else {
      visibleItems = allItems.where((item) {
        return item.symbol.toLowerCase().contains(_searchQuery) ||
            item.name.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Сортировка
    if (_sortBy == 'alphabet') {
      visibleItems.sort((a, b) => a.symbol.compareTo(b.symbol));
    } else if (_sortBy == 'change_asc') {
      visibleItems.sort((a, b) => a.changePercent.compareTo(b.changePercent));
    } else if (_sortBy == 'change_desc') {
      visibleItems.sort((a, b) => b.changePercent.compareTo(a.changePercent));
    } else if (_sortBy == 'rsi_desc') {
      visibleItems.sort((a, b) => b.rsi.compareTo(a.rsi));
    } else if (_sortBy == 'rsi_asc') {
      visibleItems.sort((a, b) => a.rsi.compareTo(b.rsi));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visibleItems.length,
      itemBuilder: (context, index) {
        final item = visibleItems[index];
        return _buildTickerCard(item, favorites.contains(item.symbol));
      },
    );
  }

  Widget _buildTickerCard(TickerModel item, bool isFavorite) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final isPositive = item.changePercent >= 0;
    final changeColor = isPositive ? Colors.green : Colors.red;
    final changeBg = isPositive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChartScreen(
                  ticker: item.symbol,
                  price: item.price.toStringAsFixed(
                      item.isCrypto && item.price < 1.0 ? 4 : 2),
                  change: '${item.changePercent.toStringAsFixed(2)}%',
                  isPositive: isPositive,
                  isCrypto: item.isCrypto,
                ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? null : [
            BoxShadow(color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  item.symbol.substring(0, 1),
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.symbol,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor),
                  ),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.price.toStringAsFixed(
                      item.isCrypto && item.price < 1.0 ? 4 : 2),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: textColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: changeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${isPositive ? '+' : ''}${item.changePercent
                            .toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(width: 12),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : Colors.grey,
              ),
              onPressed: () {
                _marketService.toggleFavorite(item.symbol);
              },
            )
          ],
        ),
      ),
    );
  }
}