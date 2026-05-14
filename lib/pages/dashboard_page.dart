import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Menambahkan import FirebaseAuth
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _db = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _lightingSub;
  StreamSubscription<DatabaseEvent>? _tanamanSub;

  double lux = 0;
  int dimming = 0;
  String mode = "auto";
  List<FlSpot> luxHistory = [];
  bool isLoadingChart = true;

  @override
  void initState() {
    super.initState();
    _loadDailyData();
    _setupListeners();
  }

  void _setupListeners() {
    // Mengambil data real-time dari sensor Zona A
    _lightingSub = _db.child('lighting_latest/dimmer01').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map && mounted) {
        setState(() {
          lux = double.tryParse(data['lux']?.toString() ?? '0') ?? 0;
          dimming = int.tryParse(data['dimming']?.toString() ?? '0') ?? 0;
        });
      }
    });

    _tanamanSub = _db.child('Tanaman').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map && mounted) {
        setState(() {
          mode = data['mode']?.toString() ?? "auto";
        });
      }
    });
  }

  Future<void> _loadDailyData() async {
    setState(() => isLoadingChart = true);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 1000;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch ~/ 1000;

    try {
      final snapshot = await _db
          .child('lighting_logs/dimmer01')
          .orderByKey()
          .startAt(startOfDay.toString())
          .endAt(endOfDay.toString())
          .get();

      List<FlSpot> tempData = [];
      if (snapshot.value is Map) {
        final Map data = snapshot.value as Map;
        final keys = data.keys.toList()..sort();
        for (var key in keys) {
          final val = data[key];
          if (val is Map && val['lux'] != null) {
            double xPos = (int.parse(key) - startOfDay).toDouble();
            tempData.add(FlSpot(xPos, double.parse(val['lux'].toString())));
          }
        }
      }
      if (mounted) setState(() => luxHistory = tempData);
    } finally {
      if (mounted) setState(() => isLoadingChart = false);
    }
  }

  // SOLUSI DEFINITIF: Mengamankan rute navigasi dari celah async gaps menggunakan referensi navigator lokal
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
              // 1. Ambil instance Navigator halaman utama sebelum await berjalan
              final navigator = Navigator.of(context);
              
              // 2. Tutup dialog box secara aman menggunakan context milik builder dialog
              Navigator.pop(dialogContext);
              
              // 3. Jalankan proses asynchronous Firebase SignOut
              await FirebaseAuth.instance.signOut();
              
              // 4. Eksekusi perpindahan rute langsung dari objek referensi (Bebas dari Warning BuildContext)
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
  void dispose() {
    _lightingSub?.cancel();
    _tanamanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("🌱 Kontrol Cahaya Tanaman"),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Karena dashboard adalah root page
        actions: [
          IconButton(
            onPressed: _showLogoutDialog, // Memanggil fungsi dialog logout yang sudah diperbaiki
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Ringkasan Zona", "Terakhir diperbarui: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}"),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildZoneCard("Zona A", "Sensor 1", lux, dimming, mode, isOptimal: lux >= 3000 && lux <= 4500)),
                const SizedBox(width: 12),
                Expanded(child: _buildInactiveZoneCard("Zona B", "Sensor 2")),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionHeader("Grafik Intensitas Cahaya", ""),
            const SizedBox(height: 12),
            _buildChartCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.grid_view_rounded, size: 20, color: Colors.black87),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildZoneCard(String name, String sensor, double luxVal, int dim, String modeStr, {required bool isOptimal}) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              CircleAvatar(backgroundColor: Colors.green[50], radius: 18, child: const Icon(Icons.eco, color: Colors.green, size: 20)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: isOptimal ? Colors.green[50] : Colors.red[50], borderRadius: BorderRadius.circular(8)),
                child: Text(isOptimal ? "Optimal" : "Peringatan", style: TextStyle(color: isOptimal ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(sensor, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const Divider(height: 20),
          _buildInfoRow(Icons.wb_sunny_outlined, "Lux", luxVal.toStringAsFixed(0)),
          _buildInfoRow(Icons.speed, "Dimmer", "$dim%"),
          _buildInfoRow(Icons.settings_input_component, "Mode", modeStr.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildInactiveZoneCard(String name, String sensor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(backgroundColor: Colors.white, radius: 18, child: Icon(Icons.sensors_off, color: Colors.grey, size: 20)),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
          Text(sensor, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          const Center(child: Text("Belum Terhubung", style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Monitoring Real-time", style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                child: const Text("Target: 4000 Lux", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: isLoadingChart 
              ? const Center(child: CircularProgressIndicator(color: Colors.green)) 
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: luxHistory,
                        isCurved: true,
                        color: Colors.green,
                        barWidth: 3,
                        belowBarData: BarAreaData(show: true, color: Colors.green.withValues(alpha: 0.1)),
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}