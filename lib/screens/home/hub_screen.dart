import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart'; // 🚀 Added for Logout
import 'explore_careers_screen.dart';
import 'career_matchmaker_screen.dart';
import 'earn_and_learn_screen.dart';
import 'task_tracker_screen.dart'; 
import '../profile/profile_screen.dart'; 
import '../settings/settings_screen.dart'; // 🚀 Added for Settings
import '../support/support_screen.dart'; // 🚀 Added for Support/Feedback/Bug
import '../help/help_screen.dart'; // 🚀 Added for Help & FAQ

class HubScreen extends StatelessWidget {
  final String userName;
  const HubScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
      builder: (context, snapshot) {
        
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hey $userName,",
                  style: const TextStyle(color: AppTheme.textWhite, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text(
                  "What's your next move?",
                  style: TextStyle(color: AppTheme.primaryAccent, fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),

                // 🚀 GOAL & LIVE PROGRESS METER
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.2)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))]
                  ),
                  child: _buildGoalContent(snapshot),
                ),
                
                const SizedBox(height: 32),
                const Text("Actions", style: TextStyle(color: AppTheme.textWhite, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                _buildActionCard(
                  title: 'Explore Career Paths',
                  subtitle: 'Discover what you can achieve today.',
                  icon: Icons.explore,
                  colors: [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExploreCareersScreen())),
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  title: 'Discover Your Path',
                  subtitle: 'Let AI find your perfect career match.',
                  icon: Icons.psychology_alt,
                  colors: [const Color(0xFF10B981), const Color(0xFF059669)],
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CareerMatchmakerScreen())),
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  title: 'Earn & Learn',
                  subtitle: 'Monetize skills or learn high-income ones.',
                  icon: Icons.monetization_on,
                  colors: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EarnAndLearnScreen())),
                ),

                const SizedBox(height: 40),
                const Text("For You", style: TextStyle(color: AppTheme.textWhite, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // 🚀 THE HERO CAROUSEL
                const _PromoCarousel(),
                
                const SizedBox(height: 40),
                Divider(color: Colors.grey.withValues(alpha: 0.2), thickness: 1),
                const SizedBox(height: 20),

                // 🚀 THE NEW WEB-STYLE QUICK LINKS FOOTER
                _buildQuickLinksFooter(context, isDark),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      }
    );
  }

  // 🚀 QUICK LINKS FOOTER WIDGET
  Widget _buildQuickLinksFooter(BuildContext context, bool isDark) {
    Color linkColor = isDark ? Colors.grey[500]! : Colors.grey[600]!;
    
    return Center(
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 12,
            children: [
              _buildFooterLink('Settings', linkColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
              _buildFooterLink('Help & FAQ', linkColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()))),
              _buildFooterLink('Email Support', linkColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()))),
              _buildFooterLink('Report a Bug', linkColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()))),
              _buildFooterLink('Send Feedback', linkColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()))),
              _buildFooterLink('Logout', Colors.redAccent.withValues(alpha: 0.8), () {
                AuthService().signOut();
                Navigator.of(context).popUntil((route) => route.isFirst);
              }),
            ],
          ),
          const SizedBox(height: 24),
          Text("© ROADMAP", style: TextStyle(color: Colors.grey.withValues(alpha: 0.4), fontSize: 12)),
        ],
      ),
    );
  }

  // 🚀 HELPER FOR FOOTER TEXT BUTTONS
  Widget _buildFooterLink(String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildGoalContent(AsyncSnapshot<DocumentSnapshot> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: CircularProgressIndicator(color: AppTheme.secondaryAccent),
        ),
      );
    }

    String currentGoal = 'No goal set';
    double progress = 0.0;

    if (snapshot.hasData && snapshot.data!.exists) {
      final data = snapshot.data!.data() as Map<String, dynamic>?;
      if (data != null) {
        currentGoal = data['currentGoal'] ?? 'No goal set';
        progress = (data['progress'] ?? 0).toDouble();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Goal:', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                currentGoal, 
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                softWrap: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Your Progress:', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
            Text('${progress.toInt()}%', style: const TextStyle(color: AppTheme.secondaryAccent, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress / 100, 
            backgroundColor: Colors.black.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryAccent),
            minHeight: 10,
          ),
        )
      ],
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required List<Color> colors, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: colors[0].withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 🚀 INTERACTIVE PROMO CAROUSEL STATEFUL WIDGET
// ----------------------------------------------------------------------
class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  // Define the dynamic slides here
  final List<Map<String, dynamic>> _promoItems = [
    {
      "title": "Complete Your Profile",
      "subtitle": "Unlock better AI recommendations by adding your details.",
      "icon": Icons.account_circle,
      "color1": const Color(0xFFF59E0B), // Amber
      "color2": const Color(0xFFD97706),
      "route": const ProfileScreen(),
    },
    {
      "title": "Build a High-Income Skill",
      "subtitle": "Don't know where to start? Check the Learn tab.",
      "icon": Icons.school,
      "color1": const Color(0xFFEC4899), // Purple/Pink
      "color2": const Color(0xFFBE185D),
      "route": const EarnAndLearnScreen(),
    },
    {
      "title": "Maintain Your Streak 🔥",
      "subtitle": "Tick off your daily tasks and build momentum.",
      "icon": Icons.local_fire_department,
      "color1": const Color(0xFFEF4444), // Red
      "color2": const Color(0xFFB91C1C),
      "route": const TaskTrackerScreen(),
    },
    {
      "title": "Explore Top Careers",
      "subtitle": "Discover roadmaps for hundreds of dream jobs.",
      "icon": Icons.map_outlined,
      "color1": const Color(0xFF06B6D4), // Teal/Cyan
      "color2": const Color(0xFF0369A1),
      "route": const ExploreCareersScreen(),
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        if (nextPage >= _promoItems.length) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              _startAutoScroll(); 
            },
            itemCount: _promoItems.length,
            itemBuilder: (context, index) {
              final item = _promoItems[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => item['route']));
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [item['color1'], item['color2']],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: item['color1'].withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Decorative faded icon in background
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: Icon(item['icon'], size: 100, color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(item['icon'], color: Colors.white, size: 24),
                                const SizedBox(width: 8),
                                Expanded(child: Text(item['title'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(item['subtitle'], style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // 🚀 ANIMATED DOT INDICATORS
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _promoItems.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: _currentPage == index ? 24 : 8,
              decoration: BoxDecoration(
                color: _currentPage == index ? AppTheme.primaryAccent : Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}