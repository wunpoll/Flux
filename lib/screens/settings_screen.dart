import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../localization.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../services/market_service.dart';
import '../models/user_model.dart';
import 'admin_screen.dart';
import 'chart_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final WalletService _walletService = WalletService();
  final MarketService _marketService = MarketService();

  UserModel? _currentUser;
  bool _isLoadingUser = true;
  List<TickerModel> _marketData = [];
  bool _isMarketLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadMarketPrices();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _loadMarketPrices() async {
    try {
      final moex = await _marketService.getMoexStocks();
      final crypto = await _marketService.getCryptoStocks();
      if (mounted) {
        setState(() {
          _marketData = [...moex, ...crypto];
          _isMarketLoaded = true;
        });
      }
    } catch (e) {
      print("Error loading prices: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = Colors.grey;

    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, currentLang, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppStrings.t('portfolio'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              centerTitle: false,
              actions: [
                IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      _loadMarketPrices();
                      setState(() {});
                    }
                )
              ],
            ),
            body: _isLoadingUser
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTotalBalanceCard(isDark),
                  const SizedBox(height: 24),

                  Text(AppStrings.t('my_assets'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 10),
                  _buildPortfolioList(cardColor, textColor),

                  const SizedBox(height: 30),
                  Divider(color: Colors.grey.withOpacity(0.2)),
                  const SizedBox(height: 10),

                  Text(AppStrings.t('account'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: subTextColor)),
                  const SizedBox(height: 10),
                  _buildProfileCard(cardColor, textColor),

                  const SizedBox(height: 30),

                  Text(AppStrings.t('appearance'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: subTextColor)),
                  const SizedBox(height: 10),

                  // ВНЕШНИЙ ВИД
                  Container(
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ValueListenableBuilder<ThemeMode>(
                          valueListenable: themeNotifier,
                          builder: (context, mode, child) {
                            return SwitchListTile(
                              title: Text(AppStrings.t('dark_theme')),
                              secondary: const Icon(Icons.dark_mode_outlined),
                              value: mode == ThemeMode.dark,
                              activeColor: Colors.amber,
                              onChanged: (val) {
                                themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                              },
                            );
                          },
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey.withOpacity(0.2)),

                        // ЯЗЫК (С красивой кнопкой)
                        ListTile(
                          leading: const Icon(Icons.language),
                          title: Text(AppStrings.t('language')),
                          trailing: GestureDetector(
                            onTap: () => _showLanguageSelector(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    languageNotifier.value == 'ru' ? '🇷🇺' : '🇺🇸',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    languageNotifier.value == 'ru' ? 'Русский' : 'English',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                        fontSize: 13
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down, size: 16, color: subTextColor),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  if (_currentUser?.isAdmin == true) _buildAdminButton(cardColor),

                  _buildLogoutButton(),

                  const SizedBox(height: 20),
                  Center(
                    child: Text("FLUX Analytics v1.0.0 (MVP)", style: TextStyle(color: subTextColor, fontSize: 12)),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }

  // --- WIDGETS ---

  Widget _buildTotalBalanceCard(bool isDark) {
    return StreamBuilder<double>(
      stream: _walletService.getBalanceStream(),
      builder: (context, snapshotBalance) {
        final cashBalance = snapshotBalance.data ?? 0.0;

        return StreamBuilder<List<AssetModel>>(
          stream: _walletService.getPortfolioStream(),
          builder: (context, snapshotAssets) {
            final assets = snapshotAssets.data ?? [];
            double totalPortfolioValue = 0.0;
            double totalPortfolioCost = 0.0;

            if (_isMarketLoaded) {
              for (var asset in assets) {
                final tickerData = _marketData.firstWhere(
                        (t) => t.symbol == asset.ticker,
                    orElse: () => TickerModel(symbol: '', name: '', price: 0, changePercent: 0, isCrypto: true)
                );

                if (tickerData.price > 0) {
                  double currentPriceUsd = tickerData.isCrypto
                      ? tickerData.price
                      : (tickerData.price / 96.0);
                  totalPortfolioValue += (asset.amount * currentPriceUsd);
                  double avgPrice = asset.avgPrice > 0 ? asset.avgPrice : currentPriceUsd;
                  totalPortfolioCost += (asset.amount * avgPrice);
                }
              }
            }

            double netWorth = cashBalance + totalPortfolioValue;
            double totalPnlUsd = totalPortfolioValue - totalPortfolioCost;
            double pnlPercent = totalPortfolioCost > 0
                ? (totalPnlUsd / totalPortfolioCost) * 100
                : 0.0;
            bool isPositive = totalPnlUsd >= 0;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: isDark
                        ? [Colors.blueAccent.shade700, Colors.purpleAccent.shade700]
                        : [Colors.blueAccent, Colors.lightBlueAccent],
                    begin: Alignment.topLeft, end: Alignment.bottomRight
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.t('net_worth'), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                      "\$${netWorth.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)
                  ),
                  if (_isMarketLoaded && assets.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "${isPositive ? '+' : ''}\$${totalPnlUsd.abs().toStringAsFixed(2)} (${pnlPercent.toStringAsFixed(2)}%) ${AppStrings.t('all_time')}", // Добавь ключ all_time в словарь!
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showDepositDialog,
                        icon: const Icon(Icons.add, color: Colors.black, size: 18),
                        label: Text(AppStrings.t('deposit'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${AppStrings.t('cash')} ${cashBalance.toStringAsFixed(2)}', // Добавь ключ cash
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPortfolioList(Color? cardColor, Color textColor) {
    return StreamBuilder<List<AssetModel>>(
      stream: _walletService.getPortfolioStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final assets = snapshot.data!;

        if (assets.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(AppStrings.t('no_assets'), style: const TextStyle(color: Colors.grey)),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            TickerModel? tickerData;
            if (_isMarketLoaded) {
              try {
                tickerData = _marketData.firstWhere((t) => t.symbol == asset.ticker);
              } catch (_) {}
            }

            double priceInUsd = tickerData?.isCrypto == true
                ? (tickerData?.price ?? 0)
                : ((tickerData?.price ?? 0) / 96.0);
            double totalValueUsd = asset.amount * priceInUsd;

            double currentPriceUsd = tickerData?.isCrypto == true
                ? (tickerData?.price ?? 0)
                : ((tickerData?.price ?? 0) / 96.0);

            double avgPrice = asset.avgPrice > 0 ? asset.avgPrice : currentPriceUsd;
            double totalCost = asset.amount * avgPrice;
            double pnlUsd = totalValueUsd - totalCost;
            double pnlPercent = totalCost > 0 ? (pnlUsd / totalCost) * 100 : 0.0;
            bool isPnlPositive = pnlUsd >= 0;
            double change = tickerData?.changePercent ?? 0.0;
            bool isPositive = change >= 0;

            return GestureDetector(
              onTap: () {
                if (tickerData != null) {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (context) => ChartScreen(
                          ticker: tickerData!.symbol,
                          price: tickerData.price.toStringAsFixed(tickerData.isCrypto ? 2 : 2),
                          change: "${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%",
                          isPositive: isPositive,
                          isCrypto: tickerData.isCrypto
                      )
                  ));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Loading market data...")));
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.withOpacity(0.1),
                          child: Text(asset.ticker.substring(0,1), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(asset.ticker, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                            Text(
                                "${asset.amount.toStringAsFixed(4)} coins",
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (currentPriceUsd > 0)
                          Text(
                              "\$${totalValueUsd.toStringAsFixed(2)}",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)
                          )
                        else
                          const Text("Loading...", style: TextStyle(fontSize: 12, color: Colors.grey)),

                        if (currentPriceUsd > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: isPnlPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4)
                            ),
                            child: Text(
                              "${isPnlPositive ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isPnlPositive ? Colors.green : Colors.red
                              ),
                            ),
                          )
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileCard(Color? cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: _getRoleColor().withOpacity(0.2),
            child: Text(
              (_currentUser?.email ?? "U").substring(0, 1).toUpperCase(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _getRoleColor()),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUser?.email ?? "Guest",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _buildRoleBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminButton(Color? cardColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.admin_panel_settings, color: Colors.redAccent),
        title: Text(AppStrings.t('admin_console'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.redAccent),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.redAccent.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          Navigator.of(context).popUntil((route) => route.isFirst);
          await _authService.signOut();
        },
        icon: const Icon(Icons.logout, color: Colors.redAccent),
        label: Text(AppStrings.t('logout'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.t('language'),
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 16),
              _buildLanguageOption(context, 'en', '🇺🇸', 'English', textColor),
              Divider(color: Colors.grey.withOpacity(0.2), indent: 16, endIndent: 16),
              _buildLanguageOption(context, 'ru', '🇷🇺', 'Русский', textColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(BuildContext context, String code, String flag, String name, Color textColor) {
    final isSelected = languageNotifier.value == code;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor)),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.amber)
          : null,
      onTap: () {
        languageNotifier.value = code;
        Navigator.pop(context);
      },
    );
  }

  void _showDepositDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppStrings.t('top_up_title'), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [100, 500, 1000, 5000].map((amount) {
                  return ActionChip(
                    label: Text("\$$amount"),
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    onPressed: () {
                      _walletService.deposit(amount.toDouble());
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppStrings.t('success_deposit')} \$$amount")));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Color _getRoleColor() {
    if (_currentUser?.isAdmin == true) return Colors.redAccent;
    if (_currentUser?.isPro == true) return Colors.amber;
    return Colors.grey;
  }

  Widget _buildRoleBadge() {
    String text = AppStrings.t('guest');
    Color color = Colors.grey;
    IconData icon = Icons.person_outline;
    if (_currentUser?.isAdmin == true) {
      text = AppStrings.t('admin'); color = Colors.redAccent; icon = Icons.verified_user;
    } else if (_currentUser?.isPro == true) {
      text = AppStrings.t('pro_member'); color = Colors.amber; icon = Icons.star;
    }
    if (text == AppStrings.t('guest')) return Text(AppStrings.t('basic_plan'), style: TextStyle(color: Colors.grey[600], fontSize: 12));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10))]),
    );
  }
}