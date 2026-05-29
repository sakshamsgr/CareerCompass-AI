import 'package:flutter/material.dart';
import '../../core/theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Help & FAQ', style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFaqItem(
            context,
            'How does ROADMAP work?',
            'ROADMAP acts as a gamified life simulator. By entering your current education and assets, the app maps out realistic career paths, actionable steps, and immediate earning opportunities tailored specifically for you.',
          ),
          _buildFaqItem(
            context,
            'How do I track my goals?',
            'Once you select a career path or skill to learn, it will appear on your Home Dashboard. You can check off interactive milestones to watch your progress meter increase towards 100%.',
          ),
          _buildFaqItem(
            context,
            'What is the Earn & Learn section?',
            'This section helps you monetize what you already have. Based on the assets (like a bike or laptop) and skills you added in your profile, we suggest immediate gigs or highly profitable skills you can start learning today.',
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    bool isDark = AppTheme.isDark(context);
    return Card(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(question, style: TextStyle(color: isDark ? AppTheme.textWhite : AppTheme.textDark, fontWeight: FontWeight.bold)),
        iconColor: AppTheme.primaryAccent,
        collapsedIconColor: isDark ? AppTheme.textWhite : AppTheme.textDark,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(answer, style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, height: 1.5)),
          )
        ],
      ),
    );
  }
}