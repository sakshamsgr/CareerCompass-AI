import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _feedbackController = TextEditingController();

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'roadmap.admin@gmail.com', // Updated to match your admin email!
      queryParameters: {'subject': 'ROADMAP App Support Request'}
    );
    if (!await launchUrl(emailLaunchUri)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email client.')));
    }
  }

  Future<void> _submitFeedback(String type) async {
    final feedbackText = _feedbackController.text.trim();
    if (feedbackText.isEmpty) return;
    
    // Close the dialog immediately so the user isn't stuck waiting
    Navigator.pop(context);

    try {
      final user = FirebaseAuth.instance.currentUser;

      // 🚀 THE FIX: Push the data to the 'feedback' collection
      await FirebaseFirestore.instance.collection('feedback').add({
        'uid': user?.uid ?? 'anonymous',
        'email': user?.email ?? 'Unknown',
        'type': type, // e.g., 'Report Bug' or 'Send Feedback'
        'message': feedbackText,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'open', // Useful for your Admin CMS later!
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$type submitted successfully! Thank you.'), 
            backgroundColor: AppTheme.secondaryAccent
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit. Please try again.'), 
            backgroundColor: Colors.redAccent
          )
        );
      }
      debugPrint('Error submitting feedback: $e');
    } finally {
      _feedbackController.clear();
    }
  }

  void _openFormDialog(String title) {
    bool isDark = AppTheme.isDark(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.backgroundDark : Colors.white,
        title: Text(title, style: TextStyle(color: isDark ? AppTheme.textWhite : AppTheme.textDark)),
        content: TextField(
          controller: _feedbackController,
          maxLines: 4,
          style: TextStyle(color: isDark ? AppTheme.textWhite : AppTheme.textDark),
          decoration: AppTheme.inputDecoration('Please describe the details here...', Icons.edit, context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _feedbackController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
            onPressed: () => _submitFeedback(title),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
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
        title: Text('Support', style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Icon(Icons.headset_mic, size: 80, color: AppTheme.primaryAccent.withValues(alpha: 0.8 * 255)),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text('How can we help you?', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),

          _buildSupportCard(
            context,
            title: 'Email Support',
            subtitle: 'roadmap.admin@gmail.com',
            icon: Icons.email,
            onTap: _launchEmail,
          ),
          const SizedBox(height: 16),
          _buildSupportCard(
            context,
            title: 'Report a Bug',
            subtitle: 'Found a glitch? Let us know.',
            icon: Icons.bug_report,
            onTap: () => _openFormDialog('Report Bug'),
          ),
          const SizedBox(height: 16),
          _buildSupportCard(
            context,
            title: 'Send Feedback',
            subtitle: 'Tell us how we can improve.',
            icon: Icons.rate_review,
            onTap: () => _openFormDialog('Send Feedback'),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    bool isDark = AppTheme.isDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05 * 255) : Colors.black.withValues(alpha: 0.05 * 255),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.2 * 255)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withValues(alpha: 0.2 * 255),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryAccent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isDark ? AppTheme.textWhite : AppTheme.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, fontSize: 14)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, size: 16),
          ],
        ),
      ),
    );
  }
}