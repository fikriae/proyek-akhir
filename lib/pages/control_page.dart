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
  // Menjaga halaman pertama saat masuk tetap di Dashboard/Beranda
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

  // PERBAIKAN UTAMA: Menyimpan referensi navigator sebelum celah async berjalan
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
              // 1. Ambil referensi navigator luar sebelum await berjalan
              final navigator = Navigator.of(context);
              
              // 2. Tutup dialog dengan aman
              Navigator.pop(dialogContext);
              
              // 3. Eksekusi celah asynchronous
              await FirebaseAuth.instance.signOut();
              
              // 4. Pindah rute tanpa memanggil context (Bebas dari Warning Linter)
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

  @override
  Widget build(BuildContext context) {
    final isAuto = mode == "auto";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('🎛️ Panel Kontrol'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), 
            tooltip: 'Reset Sistem',
            onPressed: _showResetDialog
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded), 
            tooltip: 'Logout',
            onPressed: _showLogoutDialog
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Kontainer Utama Kontrol
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
                  // Label Zona di dalam kontainer utama kontrol
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
                  
                  // Switch Mode Kontrol
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
                  
                  // Menampilkan Keterangan Intensitas Cahaya Real-time (Lux) saat ini
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

                  if (!isAuto) ...[
                    const SizedBox(height: 16),
                    Slider(
                      value: manualValue.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: "$manualValue%",
                      activeColor: Colors.green,
                      onChanged: (v) {
                        setState(() => manualValue = v.toInt());
                        _db.child('Tanaman').update({'manual_value': manualValue});
                      },
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