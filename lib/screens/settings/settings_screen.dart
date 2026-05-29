import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';

  void _resetProgress() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.isDark(context) ? AppTheme.backgroundDark : Colors.white,
        title: Text('Reset Progress?', style: TextStyle(color: AppTheme.isDark(context) ? AppTheme.textWhite : AppTheme.textDark)),
        content: Text('Are you sure you want to reset your goal progress back to 0%? This cannot be undone.', 
            style: TextStyle(color: AppTheme.isDark(context) ? AppTheme.textMuted : AppTheme.textMutedLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              // Reset progress in Firebase
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
                  {'progress': 0}, SetOptions(merge: true)
                );
              }
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress reset to 0%')));
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Notifications
          SwitchListTile(
            activeThumbColor: AppTheme.primaryAccent,
            title: Text('Notifications', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            subtitle: Text('Receive team updates & alerts', style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
          ),
          const Divider(),

          // Theme Toggle
          SwitchListTile(
            activeThumbColor: AppTheme.primaryAccent,
            title: Text('Dark Mode', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            subtitle: Text('Switch between dark and bright themes', style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
            value: AppTheme.themeNotifier.value == ThemeMode.dark,
            onChanged: (val) {
              AppTheme.themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          const Divider(),

          // Language
          ListTile(
            title: Text('Language', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            trailing: DropdownButton<String>(
              value: _selectedLanguage,
              dropdownColor: isDark ? AppTheme.backgroundDark : Colors.white,
              style: TextStyle(color: textColor),
              underline: const SizedBox(),
              items: ['English', 'Hindi'].map((lang) => DropdownMenuItem(value: lang, child: Text(lang))).toList(),
              onChanged: (val) {
                setState(() => _selectedLanguage = val!);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Language set to $val')));
              },
            ),
          ),
          const Divider(),

          // Reset Progress
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.orange),
            title: Text('Reset Progress', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            onTap: _resetProgress,
          ),
          const Divider(),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () {
              AuthService().signOut();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}