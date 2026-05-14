import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Menambahkan import FirebaseAuth
import 'package:firebase_database/firebase_database.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _db = FirebaseDatabase.instance.ref();
  
  // Variabel Pencarian & Filter (Memudahkan User Mencari Data)
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
      nodeSensor = 'dimmer02'; // UNTUK 2 SENSOR NANTI: Jalur data untuk Zona B
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
            // Konversi timestamp key menjadi Jam:Menit format lokal
            final int timestamp = int.tryParse(key.toString()) ?? 0;
            final DateTime logTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            final String formattedTime = "${logTime.hour.toString().padLeft(2, '0')}:${logTime.minute.toString().padLeft(2, '0')}";

            tempLogs.add({
              'time': formattedTime,
              'timestamp': timestamp,
              'lux': value['lux'] ?? 0,
              'dimming': value['dimming'] ?? 0,
              'mode': value['mode'] ?? 'auto', // Mengambil data keterangan mode (default: auto)
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
              primary: Colors.green[600]!, // Warna utama komponen kalender
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchHistoryData(); // Otomatis ambil data baru setelah tanggal diganti
    }
  }

  // PERBAIKAN UTAMA: Menyimpan referensi navigator sebelum celah async berjalan untuk menghapus warning async gaps
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
              
              // 4. Pindah rute menggunakan referensi yang disimpan (Bebas dari Warning Linter)
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
      appBar: AppBar(
        title: const Text('📋 Riwayat Log Sistem'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _showLogoutDialog, // Menghubungkan tombol ke fungsi dialog logout
          ),
        ],
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
                // 1. Dropdown Pilih Zona/Sensor
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
                        _fetchHistoryData(); // Otomatis ambil data baru setelah zona diganti
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // 2. Tombol Kalender Tanggal
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
                          final isAutoMode = log['mode'].toString().toLowerCase() == 'auto';

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
                                    // BADGE LABEL KETERANGAN MODE (AUTO / MANUAL)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isAutoMode ? Colors.blue[50] : Colors.orange[50],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "Mode: ${log['mode'].toString().toUpperCase()}",
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