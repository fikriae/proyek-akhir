import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Timer? _chartRefreshTimer;

  double lux = 0;
  int dimming = 0;
  String mode = "auto";
  List<FlSpot> luxHistory = [];
  bool isLoadingChart = true;

  // Menyimpan data unix timestamp batas awal grafik (3 jam lalu dari waktu sekarang)
  int startOfPeriod = 0;

  @override
  void initState() {
    super.initState();
    
    // Pemuatan data pertama kali
    _loadRecentData();
    _setupListeners();

    // Timer untuk memperbarui grafik setiap 1 menit agar waktu sumbu X terus maju (Real-time)
    _chartRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadRecentData();
    });
  }

  void _setupListeners() {
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

  // =======================================================================
  // FILTER DATA DOWN-SAMPLING: 3 JAM TERAKHIR & 5 MENIT SEKALI
  // =======================================================================
  Future<void> _loadRecentData() async {
    final now = DateTime.now();
    // Menentukan batas awal: 3 jam yang lalu dari sekarang
    final threeHoursAgo = now.subtract(const Duration(hours: 3));
    
    // Simpan ke variabel state dalam bentuk detik (Unix Timestamp)
    startOfPeriod = threeHoursAgo.millisecondsSinceEpoch ~/ 1000;
    final endOfPeriod = now.millisecondsSinceEpoch ~/ 1000;

    try {
      final snapshot = await _db
          .child('lighting_logs/dimmer01')
          .orderByKey()
          .startAt(startOfPeriod.toString())
          .endAt(endOfPeriod.toString())
          .get();

      List<FlSpot> tempData = [];
      if (snapshot.value is Map) {
        final Map data = snapshot.value as Map;
        final keys = data.keys.toList()..sort();
        
        int lastAddedMinuteBlock = -1; // Pengunci blok waktu menit

        for (var key in keys) {
          final val = data[key];
          if (val is Map && val['lux'] != null) {
            final int timestamp = int.parse(key);
            final DateTime logTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

            // Membuat pengelompokan per 5 menit (0, 5, 10, 15, dst)
            int currentMinuteBlock = logTime.minute - (logTime.minute % 5);
            
            // ID Unik kombinasi Jam dan Blok Menit agar tidak berbenturan
            int uniqueBlockId = (logTime.hour * 100) + currentMinuteBlock; 

            // Jika belum ada data di blok 5 menit ini, masukkan ke grafik
            if (uniqueBlockId != lastAddedMinuteBlock) {
              double xPos = (timestamp - startOfPeriod).toDouble();
              tempData.add(FlSpot(xPos, double.parse(val['lux'].toString())));
              
              lastAddedMinuteBlock = uniqueBlockId; // Kunci blok menit ini
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          luxHistory = tempData;
          isLoadingChart = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingChart = false);
    }
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

  @override
  void dispose() {
    _lightingSub?.cancel();
    _tanamanSub?.cancel();
    _chartRefreshTimer?.cancel(); // Menghentikan timer agar tidak memori bocor
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    "Dashboard",
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
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _showLogoutDialog,
                  icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                  tooltip: 'Logout',
                ),
              ),
            )
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Ringkasan Zona",
                "Terakhir diperbarui: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}"),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildZoneCard(
                        "Zona A", "Sensor 1", lux, dimming, mode,
                        isOptimal: lux >= 3500 && lux <= 4500)),
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
              CircleAvatar(
                  backgroundColor: Colors.green[50],
                  radius: 18,
                  child: const Icon(Icons.eco, color: Colors.green, size: 20)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: isOptimal ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8)),
                child: Text(isOptimal ? "Optimal" : "Peringatan",
                    style: TextStyle(color: isOptimal ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
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
          const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: Icon(Icons.sensors_off, color: Colors.grey, size: 20)),
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Monitoring Real-time (3 Jam Terakhir)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                child: const Text("Target: 4000 Lux",
                    style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220, 
            child: isLoadingChart
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1000,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.grey.withValues(alpha: 0.15),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          axisNameWidget: const Text("Lux", style: TextStyle(fontSize: 10)),
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: 1000,
                            getTitlesWidget: (v, _) => Text(
                              v >= 1000 ? "${(v / 1000).toStringAsFixed(0)}k" : v.toInt().toString(),
                              style: const TextStyle(fontSize: 9, color: Colors.grey),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: 1800, // Menampilkan label teks per 30 menit sekali (30 menit = 1800 detik)
                            getTitlesWidget: (value, _) {
                              final dt = DateTime.fromMillisecondsSinceEpoch((startOfPeriod + value.toInt()) * 1000);
                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
                                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 4000,
                            color: Colors.orange,
                            strokeWidth: 1.5,
                            dashArray: [5, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              labelResolver: (_) => "Target 4000",
                              style: const TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1),
                          left: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: luxHistory,
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 3,
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.green.withValues(alpha: 0.1),
                          ),
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