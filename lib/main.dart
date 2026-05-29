import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart'; 
import 'services/auth_service.dart';
import 'services/notification_service.dart'; 
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart';
import 'core/theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  //  LOAD BACKEND
  await dotenv.load(fileName: ".env"); 
  await Firebase.initializeApp();
  await NotificationService.init(); // INITIALIZE ALARMS
  
  FlutterNativeSplash.remove();

  runApp(const RoadmapApp());
}


class RoadmapApp extends StatelessWidget {
  const RoadmapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Roadmap',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: StreamBuilder<User?>(
            stream: AuthService().userStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  backgroundColor: currentMode == ThemeMode.dark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
                  body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
                );
              }
              
              if (snapshot.hasData && snapshot.data != null) {
                return Gatekeeper(user: snapshot.data!, currentMode: currentMode);
              }
              
              return const LoginScreen();
            },
          ),
        );
      }
    );
  }
}

class Gatekeeper extends StatelessWidget {
  final User user;
  final ThemeMode currentMode;

  const Gatekeeper({super.key, required this.user, required this.currentMode});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: currentMode == ThemeMode.dark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
            body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
          );
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final isBanned = data?['isBanned'] ?? false;

          if (isBanned) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This account has been suspended.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.redAccent,
                  )
                );
              }
            });
            return Scaffold(
              backgroundColor: currentMode == ThemeMode.dark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
              body: const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
            );
          }
          return const MainScreen();
        }
        return const MainScreen();
      }
    );
  }
}