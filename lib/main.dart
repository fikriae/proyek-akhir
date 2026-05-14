import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Tambahan import FCM
import 'firebase_options.dart';

import 'pages/control_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';

// FUNGSI BACKGROUND HANDLER (TIDAK BOLEH DI DALAM CLASS)
// Bertugas menangkap notifikasi saat aplikasi ditutup/minimize
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Pastikan Firebase diinisialisasi agar bisa memproses data di background
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Notifikasi masuk saat background/ditutup: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Mendaftarkan fungsi background handler ke sistem Android/iOS
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Menangkap notifikasi jika sedang membuka aplikasi (Foreground)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("Notifikasi masuk saat aplikasi terbuka: ${message.notification?.title}");
    // Anda bisa menambahkan logika tambahan di sini nanti, 
    // seperti menampilkan SnackBar atau Dialog.
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kontrol Cahaya Tanaman',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/control': (context) => const ControlPage(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const ControlPage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}