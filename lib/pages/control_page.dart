import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dashboard_page.dart';
import 'history_page.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  int _selectedIndex = 0; 

  final List<Widget> _pages = const [
    DashboardPage(),
    _ControlContent(),
    HistoryPage(),
  ];

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();
      if (token != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          DatabaseReference db = FirebaseDatabase.instance.ref();
          await db.child('users/${user.uid}/fcm_token').set(token);
        }
      }
    }
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        selectedItemColor: Colors.green,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Kontrol'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
        ],
      ),
    );
  }
}

class _ControlContent extends StatefulWidget {
  const _ControlContent();

  @override
  State<_ControlContent> createState() => _ControlContentState();
}

class _ControlContentState extends State<_ControlContent> {
  final _db = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _lightingSub;
  StreamSubscription<DatabaseEvent>? _tanamanSub;

  double lux = 0; 
  int digipotPosition = 0;
  int manualValue = 50;
  String mode = "auto";

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _lightingSub = _db.child('lighting_latest/dimmer01').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map && mounted) {
        setState(() {
          lux = double.tryParse(data['lux']?.toString() ?? '0') ?? 0;
          digipotPosition = int.tryParse(data['dimming']?.toString() ?? '0') ?? 0;
        });
      }
    });

    _tanamanSub = _db.child('Tanaman').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map && mounted) {
        setState(() {
          manualValue = int.tryParse(data['manual_value']?.toString() ?? '50') ?? 50;
          mode = data['mode']?.toString() ?? "auto";
        });
      }
    });
  }

  @override
  void dispose() {
    _lightingSub?.cancel();
    _tanamanSub?.cancel();
    super.dispose();
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Reset'),
        content: const Text('Kembalikan sistem ke mode Auto dan dimmer 50%?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              _db.child('Tanaman').update({'command': 'reset'});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perintah reset dikirim')));
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah kamu yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              Navigator.pop(dialogContext);
              await FirebaseAuth.instance.signOut();
              navigator.pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // PENENTU WARNA & TEKS STATUS BERBASIS PARAMETER BARU (3500 - 4500 LUX)
  // =======================================================================
  Color _getStatusColor() {
    if (lux < 3500) return Colors.orange;
    if (lux >= 3500 && lux <= 4500) return Colors.green;
    return Colors.red;
  }

  String _getStatusText() {
    if (lux < 3500) return "⚠️ Kurang Cahaya (Belum Optimal)";
    if (lux >= 3500 && lux <= 4500) return "🟢 Cahaya Optimal untuk Selada";
    return "❌ Kelebihan Cahaya (Tidak Optimal)";
  }

  @override
  Widget build(BuildContext context) {
    final isAuto = mode == "auto";
    final statusColor = _getStatusColor();
    final statusText = _getStatusText();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75.0),
        child: AppBar(
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                  image: const DecorationImage(
                    image: AssetImage('lib/assets/icon/app_icon.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "SMART LIGHT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Control Panel",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green[700]!,
                  Colors.green[500]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white), 
              tooltip: 'Reset Sistem',
              onPressed: _showResetDialog
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20), 
                  tooltip: 'Logout',
                  onPressed: _showLogoutDialog
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Zona A - Sensor 1",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                      ),
                      Icon(Icons.sensors, color: Colors.green[300], size: 20),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(isAuto ? "Mode Otomatis" : "Mode Manual", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(isAuto ? "Target: 4000 Lux" : "Atur dimmer secara manual"),
                    value: isAuto,
                    onChanged: (val) => _db.child('Tanaman').update({'mode': val ? "auto" : "manual"}),
                    activeColor: Colors.green,
                  ),
                  
                  const SizedBox(height: 10),
                  Text(
                    isAuto ? "Dimmer saat ini: $digipotPosition%" : "Level Dimmer: $manualValue%",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.wb_sunny_outlined, size: 14, color: Colors.orange[600]),
                      const SizedBox(width: 6),
                      Text(
                        "Intensitas Cahaya: ${lux.toStringAsFixed(0)} Lux",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ],
                  ),

                  // TAMPILAN MANIPULASI INDIKATOR JIKA DALAM MODE MANUAL
                  if (!isAuto) ...[
                    const SizedBox(height: 24),
                    // Dynamic Badge Banner Status Keoptimalan
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.2),
                      ),
                      child: Text(
                        statusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: statusColor == Colors.orange ? Colors.orange[800] : statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Slider Interaktif dengan warna Track yang sinkron mengikuti sensor Lux
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: statusColor,
                        thumbColor: statusColor,
                        overlayColor: statusColor.withValues(alpha: 0.12),
                      ),
                      child: Slider(
                        value: manualValue.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: "$manualValue%",
                        onChanged: (v) {
                          setState(() => manualValue = v.toInt());
                          _db.child('Tanaman').update({'manual_value': manualValue});
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}