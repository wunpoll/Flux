import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../localization.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  // Безопасный запрос с тайм-аутом
  Future<QuerySnapshot?> _safeGet(Query query) async {
    try {
      // Пытаемся получить данные.
      // Firestore по умолчанию попытается взять из кэша, если сети нет.
      // Тайм-аут нужен на случай, если и кэша нет, чтобы не висеть вечно.
      return await query.get().timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, currentLang, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppStrings.t('admin_console'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              bottom: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: AppStrings.t('user_management')),
                  Tab(text: AppStrings.t('system_analytics')),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(),
                _buildSystemAnalytics(),
              ],
            ),
          );
        }
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("${AppStrings.t('error')}: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final uid = users[index].id;
            final email = userData['email'] ?? AppStrings.t('no_email');
            final role = userData.containsKey('role') ? userData['role'] : 'guest';
            final isPro = role == 'pro';
            final isAdmin = role == 'admin';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAdmin ? Colors.red : (isPro ? Colors.amber : Colors.grey),
                  child: Icon(
                    isAdmin ? Icons.admin_panel_settings : (isPro ? Icons.star : Icons.person),
                    color: Colors.white,
                  ),
                ),
                title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${AppStrings.t('role_label')}: ${role.toUpperCase()}"),
                trailing: isAdmin
                    ? Text(AppStrings.t('master_role'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                    : Switch(
                  value: isPro,
                  activeColor: Colors.amber,
                  onChanged: (val) {
                    _db.collection('users').doc(uid).update({'role': val ? 'pro' : 'guest'});
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 2: АНАЛИТИКА (С ПРОВЕРКОЙ КЭША) ---
  Widget _buildSystemAnalytics() {
    return FutureBuilder(
      future: Future.wait([
        _safeGet(_db.collection('users')),       // [0]
        _safeGet(_db.collectionGroup('alerts')), // [1]
        _checkInternetConnection(),              // [2]
      ]),
      builder: (context, snapshot) {
        int totalUsers = 0;
        int proUsers = 0;
        int totalAlerts = 0;
        int activeAlerts = 0;

        bool isApiOnline = false;

        // Три состояния БД: Healthy (Green), Cached (Orange), Error (Red)
        String dbStatusText = AppStrings.t('status_error');
        Color dbStatusColor = Colors.red;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          final data = snapshot.data!;
          isApiOnline = data[2] as bool;

          final usersSnapshot = data[0] as QuerySnapshot?;
          final alertsSnapshot = data[1] as QuerySnapshot?;

          if (usersSnapshot != null && alertsSnapshot != null) {
            // ПРОВЕРКА КЭША
            // Если данные пришли из кэша, значит соединения с сервером БД нет
            final isFromCache = usersSnapshot.metadata.isFromCache;

            if (isFromCache) {
              dbStatusText = AppStrings.t('status_cached'); // "Кэш (Офлайн)"
              dbStatusColor = Colors.orange;
            } else {
              dbStatusText = AppStrings.t('status_healthy');
              dbStatusColor = Colors.green;
            }

            final usersDocs = usersSnapshot.docs;
            final alertsDocs = alertsSnapshot.docs;

            totalUsers = usersDocs.length;
            proUsers = usersDocs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final role = d.containsKey('role') ? d['role'] : 'guest';
              return role == 'pro' || role == 'admin';
            }).length;

            totalAlerts = alertsDocs.length;
            activeAlerts = alertsDocs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return d['status'] == 'AlertStatus.active';
            }).length;
          } else {
            // Если null (тайм-аут)
            dbStatusText = AppStrings.t('status_error');
            dbStatusColor = Colors.red;
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.t('platform_health'), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              Row(
                children: [
                  _statCard(AppStrings.t('total_users'), totalUsers.toString(), Colors.blue),
                  _statCard(AppStrings.t('pro_members'), proUsers.toString(), Colors.amber),
                ],
              ),
              Row(
                children: [
                  _statCard(AppStrings.t('total_alerts'), totalAlerts.toString(), Colors.purple),
                  _statCard(AppStrings.t('active_triggers'), activeAlerts.toString(), Colors.green),
                ],
              ),

              const SizedBox(height: 30),
              const Divider(),

              // DB STATUS (Умный)
              ListTile(
                leading: const Icon(Icons.storage),
                title: Text(AppStrings.t('db_status')),
                trailing: Text(
                  dbStatusText,
                  style: TextStyle(
                      color: dbStatusColor,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),

              // API STATUS
              ListTile(
                leading: const Icon(Icons.api),
                title: Text(AppStrings.t('api_status')),
                trailing: Text(
                  isApiOnline ? AppStrings.t('status_online') : AppStrings.t('status_offline'),
                  style: TextStyle(
                      color: isApiOnline ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}