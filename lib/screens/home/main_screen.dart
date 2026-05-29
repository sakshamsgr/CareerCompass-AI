import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';

import '../profile/profile_screen.dart';
import '../ai/ai_chat_screen.dart';
import '../settings/settings_screen.dart';
import '../help/help_screen.dart';
import '../support/support_screen.dart';
import '../notifications/notifications_screen.dart';
import '../notes/notes_screen.dart';

import 'hub_screen.dart';
import 'your_goals_screen.dart';
import 'task_tracker_screen.dart';

import '../forum/forum_feed_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialPage;

  const MainScreen({
    super.key,
    this.initialPage = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  String _userName = 'User';
  String? _profileImageUrl;

  int _profileCompletion = 0;
  int _currentStreak = 0;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialPage;

    _listenToUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage('assets/images/app_header.png'),
        context,
      );
    });
  }

  void _listenToUserData() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!mounted || !doc.exists) return;

      final data = doc.data()!;

      int completed = 0;
      const int totalFields = 6;

      if (data['name'] != null &&
          data['name'].toString().isNotEmpty) {
        completed++;
      }

      if (data['age'] != null) completed++;
      if (data['profileImage'] != null) completed++;
      if (data['education'] != null) completed++;
      if (data['financialCondition'] != null) completed++;

      if (data['assets'] != null &&
          (data['assets'] as List).isNotEmpty) {
        completed++;
      }

      final newCompletion =
          ((completed / totalFields) * 100).toInt();

      setState(() {
        _userName = data['name'] ?? 'User';
        _profileImageUrl = data['profileImage'];
        _currentStreak = data['currentStreak'] ?? 0;
        _profileCompletion = newCompletion.clamp(0, 100);
      });
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppTheme.isDark(context);

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,

      appBar: AppBar(
        toolbarHeight: 80,
        elevation: 0,
        centerTitle: true,

        backgroundColor: isDark
            ? AppTheme.backgroundDark
            : AppTheme.backgroundLight,

        leading: Builder(
          builder: (context) {
            return IconButton(
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryAccent,
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: _profileImageUrl == null
                    ? const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            );
          },
        ),

        title: Image.asset(
          'assets/images/app_header.png',
          height: 50,
          fit: BoxFit.contain,
        ),

        actions: [
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('notifications')
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                final unreadCount =
                    snapshot.data?.docs.length ?? 0;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_none,
                        color: isDark
                            ? AppTheme.textWhite
                            : AppTheme.textDark,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const NotificationsScreen(),
                          ),
                        );
                      },
                    ),

                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.secondaryAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const TaskTrackerScreen(),
                ),
              );
            },
            child: Container(
              margin:
                  const EdgeInsets.symmetric(vertical: 15),

              padding:
                  const EdgeInsets.symmetric(horizontal: 12),

              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),

                borderRadius: BorderRadius.circular(20),

                border: Border.all(
                  color: Colors.orange.withOpacity(0.5),
                  width: 1.5,
                ),
              ),

              child: Center(
                child: Text(
                  _currentStreak > 0
                      ? "🔥 $_currentStreak"
                      : "🔥",

                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),

      drawer: _buildDrawer(context),

      // ✅ OPTIMIZED BODY
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HubScreen(userName: _userName),
          const YourGoalsScreen(),
          const ForumFeedScreen(),
        ],
      ),

      // ✅ MULTI FAB
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Tooltip(
            message: 'My Notes',
            child: FloatingActionButton(
              heroTag: 'notes_fab',

              backgroundColor:
                  const Color(0xFFF59E0B),

              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const NotesScreen(),
                  ),
                );
              },

              child: const Icon(
                Icons.edit_note_rounded,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Tooltip(
            message: 'Ask Question?',
            child: FloatingActionButton(
              heroTag: 'ai_chat_fab',

              backgroundColor:
                  AppTheme.secondaryAccent,

              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const AiChatScreen(),
                  ),
                );
              },

              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,

        backgroundColor: isDark
            ? const Color(0xFF1E293B)
            : Colors.white,

        selectedItemColor:
            AppTheme.primaryAccent,

        unselectedItemColor: isDark
            ? AppTheme.textMuted
            : AppTheme.textMutedLight,

        currentIndex: _currentIndex,

        onTap: _onItemTapped,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Your Goals',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.forum),
            label: 'Community',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final bool isDark = AppTheme.isDark(context);

    final Color textColor = isDark
        ? AppTheme.textWhite
        : AppTheme.textDark;

    return Drawer(
      backgroundColor: isDark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,

      child: ListView(
        padding: EdgeInsets.zero,

        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppTheme.primaryAccent,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              mainAxisAlignment:
                  MainAxisAlignment.end,

              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,

                  backgroundImage:
                      _profileImageUrl != null
                          ? NetworkImage(
                              _profileImageUrl!,
                            )
                          : null,

                  child: _profileImageUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 40,
                          color:
                              AppTheme.primaryAccent,
                        )
                      : null,
                ),

                const SizedBox(height: 10),

                Text(
                  _userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          ListTile(
            leading: Icon(
              Icons.account_circle,
              color: textColor,
            ),

            title: Text(
              'Personal Details',
              style: TextStyle(color: textColor),
            ),

            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ProfileScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: Icon(
              Icons.settings,
              color: textColor,
            ),

            title: Text(
              'Settings',
              style: TextStyle(color: textColor),
            ),

            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const SettingsScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: Icon(
              Icons.help_outline,
              color: textColor,
            ),

            title: Text(
              'Help',
              style: TextStyle(color: textColor),
            ),

            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const HelpScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: Icon(
              Icons.support_agent,
              color: textColor,
            ),

            title: Text(
              'Support',
              style: TextStyle(color: textColor),
            ),

            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const SupportScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.redAccent,
            ),

            title: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.redAccent,
              ),
            ),

            onTap: () {
              AuthService().signOut();
            },
          ),
        ],
      ),
    );
  }
}