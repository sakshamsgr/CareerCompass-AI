import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart'; // 🚀 IMPORT ADDED
import 'services/auth_service.dart';
import 'services/notification_service.dart'; 
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart';
import 'core/theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // 1. 🚀 CAPTURE BINDINGS & PRESERVE SPLASH SCREEN
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 2. LOAD BACKEND
  await dotenv.load(fileName: ".env"); 
  await Firebase.initializeApp();
  await NotificationService.init(); // INITIALIZE ALARMS
  
  // 3. 🚀 REMOVE SPLASH SCREEN (This unfreezes the app!)
  FlutterNativeSplash.remove();

  runApp(const RoadmapApp());
}
