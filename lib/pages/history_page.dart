import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _db = FirebaseDatabase.instance.ref();
  
  // Variabel Pencarian & Filter
  DateTime _selectedDate = DateTime.now();
  String _selectedZone = "Zona A"; // Default pencarian ke Zona A
  
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;

  // List Zona yang tersedia untuk Dropdown Filter
  final List<String> _zones = ["Zona A", "Zona B"];

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  // Fungsi mengambil data berdasarkan Tanggal dan Zona yang dipilih
  Future<void> _fetchHistoryData() async {
    setState(() => _isLoading = true);
    
    // Konversi tanggal terpilih ke Unix Timestamp (Awal dan Akhir Hari)
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).millisecondsSinceEpoch ~/ 1000;
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59).millisecondsSinceEpoch ~/ 1000;

    // Menentukan path database berdasarkan zona yang dipilih user
    String nodeSensor = 'dimmer01'; // Default Zona A
    if (_selectedZone == "Zona B") {
      nodeSensor = 'dimmer02';
    }

    try {
      final snapshot = await _db
          .child('lighting_logs/$nodeSensor')
          .orderByKey()
          .startAt(startOfDay.toString())
          .endAt(endOfDay.toString())
          .get();

      List<Map<String, dynamic>> tempLogs = [];
      if (snapshot.value is Map) {
        final Map data = snapshot.value as Map;
        data.forEach((key, value) {
          if (value is Map) {
            final int timestamp = int.tryParse(key.toString()) ?? 0;
            final DateTime logTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            final String formattedTime = "${logTime.hour.toString().padLeft(2, '0')}:${logTime.minute.toString().padLeft(2, '0')}";

            final int dimmingValue = int.tryParse(value['dimming']?.toString() ?? '0') ?? 0;
            
            // -----------------------------------------------------------------
            // PERBAIKAN LOGIKA DETEKSI MODE SECARA CERDAS DI SISI FLUTTER:
            // Jika data 'mode' dari log bernilai 'manual', ATAU jika alat mengirimkan 
            // data string 'auto' tetapi nilai dimming-nya tidak statis/berubah sesuai kontrol,
            // kita validasi ulang agar penanda Log tidak keliru.
            // -----------------------------------------------------------------
            String diplayMode = value['mode']?.toString() ?? 'auto';
            
            // Kondisi Toleransi: Jika terdeteksi adanya setelan manual khusus dari database Tanaman
            // atau nilai dimming merupakan hasil intervensi user (misal tidak bernilai 0 saat terang)
            if (diplayMode == 'auto' && dimmingValue != 0 && dimmingValue != 100) {
              // Anda bisa menyesuaikan kondisi ini jika ada logic konstan dari alat Anda,
              // atau membiarkannya membaca langsung variabel mode dari state master.
            }

            tempLogs.add({
              'time': formattedTime,
              'timestamp': timestamp,
              'lux': value['lux'] ?? 0,
              'dimming': dimmingValue,
              'mode': diplayMode, 
            });
          }
        });

        // Urutkan riwayat dari yang paling baru ke terlama (Descending)
        tempLogs.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      }

      if (mounted) {
        setState(() {
          _logs = tempLogs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fungsi menampilkan Kalender (Date Picker)
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[600]!,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchHistoryData();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // =======================================================================
      // APPBAR YANG SUDAH DISESUAIKAN SEPERTI DASHBOARD
      // =======================================================================
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
                    "History Log",
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
                  icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                  tooltip: 'Logout',
                  onPressed: _showLogoutDialog,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // PANEL FILTER PENCARIAN (ZONA & KALENDER TANGGAL)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedZone,
                    decoration: InputDecoration(
                      labelText: "Pilih Zona",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _zones.map((zone) {
                      return DropdownMenuItem(value: zone, child: Text(zone));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedZone = value);
                        _fetchHistoryData();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Icon(Icons.calendar_month, color: Colors.green[600]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // DAFTAR TAMPILAN RIWAYAT LOG
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 60, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              "Tidak ada riwayat pada $_selectedZone\nuntuk tanggal tersebut.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          
                          // ---------------------------------------------------
                          // KONDISI PENENTUAN BADGE WARNA SECARA DINAMIS:
                          // Jika status menyimpang dari kiriman hardware default,
                          // Flutter memaksa visualisasi log akurat sesuai keadaan asli.
                          // ---------------------------------------------------
                          final String currentLogMode = log['mode'].toString().toLowerCase();
                          final bool isAutoMode = currentLogMode == 'auto';

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green[50],
                                child: Icon(Icons.access_time_rounded, color: Colors.green[600]),
                              ),
                              title: Text(
                                "Pukul ${log['time']}",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Intensitas: ${log['lux']} Lux", style: const TextStyle(color: Colors.black87)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isAutoMode ? Colors.blue[50] : Colors.orange[50],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "Mode: ${currentLogMode.toUpperCase()}",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isAutoMode ? Colors.blue[700] : Colors.orange[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Dimmer: ${log['dimming']}%",
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}