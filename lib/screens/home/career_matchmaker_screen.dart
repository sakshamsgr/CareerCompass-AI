import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../data/models/career_model.dart';
import '../../services/ai_roadmap_service.dart';
import 'explore_careers_screen.dart'; 

// 🚀 HACKATHON GOD-MODE: STATIC RAM CACHE
class _MatchmakerCache {
  static Map<String, dynamic>? userData;
  static List<CareerModel>? recommendedCareers;
}

class CareerMatchmakerScreen extends StatefulWidget {
  const CareerMatchmakerScreen({super.key});

  @override
  State<CareerMatchmakerScreen> createState() => _CareerMatchmakerScreenState();
}

class _CareerMatchmakerScreenState extends State<CareerMatchmakerScreen> {
  final _storyController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (_MatchmakerCache.userData != null) return; // 🚀 FAST-LOAD

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() => _MatchmakerCache.userData = doc.data());
        }
      }
    } catch (e) {
      debugPrint("Error fetching user data in matchmaker: $e");
    }
  }

  Future<void> _analyzeFuture() async {
    if (_storyController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a bit more so the AI can understand you better!'))
      );
      return;
    }

    if (_MatchmakerCache.userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile data is still loading. Please wait a moment.'))
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final careers = await AiRoadmapService.discoverCareersFromInterests(
        _storyController.text.trim(),
        _MatchmakerCache.userData!
      );

      if (!mounted) return; 

      if (careers != null && careers.isNotEmpty) {
        for (var career in careers) {
          try {
            final query = await FirebaseFirestore.instance.collection('pending_requests')
                .where('careerData.name', isEqualTo: career.name)
                .get();
                
            if (query.docs.isEmpty) {
              await FirebaseFirestore.instance.collection('pending_requests').add({
                'requestedBy': FirebaseAuth.instance.currentUser?.uid ?? 'Unknown',
                'requestedAt': DateTime.now(),
                'careerData': career.toJson(),
                'status': 'pending'
              });
            }
          } catch (e) {
            debugPrint("Error auto-submitting: $e");
          }
        }
        
        if (mounted) setState(() => _MatchmakerCache.recommendedCareers = careers);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI failed to generate paths. Please try again.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) {
      debugPrint("Matchmaker AI Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text('Discover Your Path', style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _MatchmakerCache.recommendedCareers != null 
          ? _buildResultsView(isDark, textColor) 
          : _buildInputView(isDark, textColor),
    );
  }

  Widget _buildInputView(bool isDark, Color textColor) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.psychology_alt, size: 60, color: AppTheme.secondaryAccent),
            const SizedBox(height: 16),
            Text(
              "Let's find your calling.",
              style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Forget standard job titles. Tell the AI what you genuinely love doing, what subjects you hate, what your hobbies are, and what kind of life you want to live. We will find 3 high-income matches for you.",
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            
            TextField(
              controller: _storyController,
              maxLines: 8,
              style: TextStyle(color: textColor, fontSize: 16, height: 1.5),
              decoration: InputDecoration(
                hintText: "e.g., I love playing video games and reading about space, but I completely hate math and memorizing historical dates. I want a job where I can travel...",
                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 13) : Colors.black.withValues(alpha: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: AppTheme.primaryAccent.withValues(alpha: 77)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.primaryAccent, width: 2),
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 6, // 🚀 THE FIX: Reduced from 10 to 6 for performance
                  shadowColor: AppTheme.primaryAccent.withValues(alpha: 128),
                ),
                onPressed: _isLoading ? null : _analyzeFuture,
                child: _isLoading 
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                          SizedBox(width: 16),
                          Text('Analyzing your profile...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Analyze My Future', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView(bool isDark, Color textColor) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text("Your Top 3 Matches", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text("Based on your personality and background.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _MatchmakerCache.recommendedCareers!.length,
              itemBuilder: (context, index) {
                final career = _MatchmakerCache.recommendedCareers![index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CareerDetailScreen(career: career, userData: _MatchmakerCache.userData!)));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(career.name, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppTheme.secondaryAccent.withValues(alpha: 51), borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                "#${index + 1}", 
                                style: const TextStyle(color: AppTheme.secondaryAccent, fontWeight: FontWeight.bold)
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(career.expectedIncome, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        Text(career.description, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], height: 1.4)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text("Explore Roadmap ", style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold)),
                            const Icon(Icons.arrow_forward, color: AppTheme.primaryAccent, size: 16),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: TextButton(
              onPressed: () => setState(() {
                _MatchmakerCache.recommendedCareers = null;
                _storyController.clear();
              }),
              child: const Center(child: Text("Try Again with a Different Story", style: TextStyle(color: AppTheme.textMuted))),
            ),
          )
        ],
      ),
    );
  }
}