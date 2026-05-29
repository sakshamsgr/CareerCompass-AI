import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Listen to auth state changes (automatically route to Home or Login)
  Stream<User?> get userStream => _auth.authStateChanges();

  // Generate and Send OTP via roadmap.admin@gmail.com
  Future<String> sendOtpEmail(String recipientEmail) async {
    final random = Random();
    final otp = (100000 + random.nextInt(900000)).toString();

    String username = 'roadmap.admin@gmail.com';
    String password = dotenv.env['GMAIL_APP_PASSWORD'] ?? ''; 

    if (password.isEmpty) {
      throw Exception("Gmail App Password not found in .env file.");
    }

    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = Address(username, 'ROADMAP Security')
      ..recipients.add(recipientEmail)
      ..subject = 'Your ROADMAP Verification Code'
      ..html = """
        <div style="font-family: sans-serif; color: #333;">
          <h2>Welcome to ROADMAP!</h2>
          <p>Please verify your email address to begin mapping your career.</p>
          <p>Your 6-digit verification code is: <h1 style="color: #4CAF50;">$otp</h1></p>
          <p>If you did not request this, please ignore this email.</p>
        </div>
      """;

    try {
      await send(message, smtpServer);
      return otp; 
    } catch (e) {
      throw Exception("Failed to send OTP email. Please check your email address.");
    }
  }

  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
    required int age,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (cred.user != null) {
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'uid': cred.user!.uid,
          'name': name,
          'age': age,
          'email': email,
          'role': 'user', 
          'isBanned': false, // 🚀 NEW: Initialize ban status to false
          'createdAt': DateTime.now(),
        });
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Security Check for the CMS Website
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return doc.data()?['role'] == 'admin';
    }
    return false;
  }
}