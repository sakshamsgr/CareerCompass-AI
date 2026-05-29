import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';
import '../../data/models/career_model.dart';
import '../../services/ai_earn_service.dart';
import '../profile/profile_screen.dart';
import 'explore_careers_screen.dart'; 

// 🚀 HACKATHON GOD-MODE: STATIC RAM CACHE
class _EarnLearnCache {
  static Map<String, dynamic>? userData;
  static Map<String, dynamic>? aiData;
  static List<CareerModel>? verifiedSkills;
  static List<CareerModel>? pendingSkills;
  static List<CareerModel>? verifiedGigs;
  static List<CareerModel>? pendingGigs;
}

class EarnAndLearnScreen extends StatefulWidget {
  const EarnAndLearnScreen({super.key});

  @override
  State<EarnAndLearnScreen> createState() => _EarnAndLearnScreenState();
}

class _EarnAndLearnScreenState extends State<EarnAndLearnScreen> with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  bool _isLoading = true;
  bool _isGeneratingSkill = false;
  bool _isGeneratingGig = false;
  bool _hasRequiredProfileData = false;
  final TextEditingController _searchController = TextEditingController();
  
  String _skillSearchQuery = '';
  StreamSubscription<QuerySnapshot>? _activeCareersSub;
  StreamSubscription<QuerySnapshot>? _pendingRequestsSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAndAnalyze();
    _listenToGlobalEconomyData();
  }

  @override
  void dispose() {
    _activeCareersSub?.cancel();
    _pendingRequestsSub?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToGlobalEconomyData() {
    _activeCareersSub = FirebaseFirestore.instance.collection('active_careers').snapshots().listen((snapshot) {
      if (mounted) {
        List<CareerModel> vSkills = [];
        List<CareerModel> vGigs = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final type = (data['type'] ?? 'career').toString().toLowerCase();
          if (type == 'skill') {
            vSkills.add(CareerModel.fromJson(data, id: doc.id));
          } else if (type == 'gig') {
            vGigs.add(CareerModel.fromJson(data, id: doc.id));
          }
        }
        setState(() {
          _EarnLearnCache.verifiedSkills = vSkills;
          _EarnLearnCache.verifiedGigs = vGigs;
        });
      }
    });

    _pendingRequestsSub = FirebaseFirestore.instance.collection('pending_requests').snapshots().listen((snapshot) {
      if (mounted) {
        List<CareerModel> pSkills = [];
        List<CareerModel> pGigs = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final type = (data['type'] ?? 'career').toString().toLowerCase();
          if (type == 'skill' && data['careerData'] != null) {
            pSkills.add(CareerModel.fromJson(data['careerData'], isTemporary: true));
          } else if (type == 'gig' && data['careerData'] != null) {
            pGigs.add(CareerModel.fromJson(data['careerData'], isTemporary: true));
          }
        }
        setState(() {
          _EarnLearnCache.pendingSkills = pSkills;
          _EarnLearnCache.pendingGigs = pGigs;
        });
      }
    });
  }

  Future<void> _fetchAndAnalyze({bool forceRefresh = false}) async {
    // 🚀 INSTANT LOAD: If data is already in RAM, show it immediately!
    if (_EarnLearnCache.aiData != null && !forceRefresh) {
      setState(() {
        _hasRequiredProfileData = true;
        _isLoading = false;
      });
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final doc = await docRef.get();
        
        if (doc.exists) {
          _EarnLearnCache.userData = doc.data();
          
          List<dynamic>? assets = _EarnLearnCache.userData!['assets'];
          String? time = _EarnLearnCache.userData!['timeCommitment'];
          String? budget = _EarnLearnCache.userData!['financialCondition'];
          
          if (assets != null && assets.isNotEmpty && time != null) {
            _hasRequiredProfileData = true;

            String currentSignature = "${assets.join(',')}_${time}_${budget ?? ''}";
            Map<String, dynamic>? cachedData = _EarnLearnCache.userData!['cachedEarnLearnData'];
            String? cachedSignature = _EarnLearnCache.userData!['cachedEarnLearnSignature'];

            if (cachedData != null && cachedSignature == currentSignature && !forceRefresh) {
              _EarnLearnCache.aiData = cachedData;
            } else {
              _EarnLearnCache.aiData = await AiEarnService.discoverGigsAndSkills(_EarnLearnCache.userData!);
              if (!mounted) return;
              if (_EarnLearnCache.aiData != null) {
                await docRef.update({
                  'cachedEarnLearnData': _EarnLearnCache.aiData,
                  'cachedEarnLearnSignature': currentSignature,
                });
              }
            }
          } else {
            _hasRequiredProfileData = false;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching earn and learn: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateGig(String gigName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _EarnLearnCache.userData == null) return;

    setState(() => _isGeneratingGig = true);
    String expectedName = "Executing $gigName";

    try {
      final query = await FirebaseFirestore.instance.collection('pending_requests')
          .where('requestedBy', isEqualTo: user.uid)
          .get();

      final existingDocs = query.docs.where((doc) {
        final data = doc.data();
        return data['careerData'] != null && data['careerData']['name'] == expectedName;
      }).toList();

      if (existingDocs.isNotEmpty) {
        final cachedData = existingDocs.first.data()['careerData'];
        final cachedRoadmap = CareerModel.fromJson(cachedData, isTemporary: true);
        if (mounted) {
          setState(() => _isGeneratingGig = false);
          _navigateToEconomyDetail(cachedRoadmap);
        }
        return;
      }

      final gigRoadmap = await AiEarnService.generateGigRoadmap(gigName);
      if (!mounted) return;

      if (gigRoadmap != null) {
        await FirebaseFirestore.instance.collection('pending_requests').add({
          'requestedBy': user.uid,
          'requestedAt': DateTime.now(),
          'careerData': gigRoadmap.toJson(),
          'status': 'pending',
          'type': 'gig' 
        });
        if (mounted) _navigateToEconomyDetail(gigRoadmap);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate execution plan. Try again.')));
      }
    } catch (e) {
      debugPrint("❌ Error generating gig: $e");
    } finally {
      if (mounted) setState(() => _isGeneratingGig = false);
    }
  }

  Future<void> _generateSkillWithAI(String skillName) async {
    if (_EarnLearnCache.userData == null) return;
    
    setState(() => _isGeneratingSkill = true);
    try {
      final generatedSkillRoadmap = await AiEarnService.generateSkillRoadmap(skillName);
      if (!mounted) return;

      if (generatedSkillRoadmap != null) {
        await FirebaseFirestore.instance.collection('pending_requests').add({
          'requestedBy': FirebaseAuth.instance.currentUser?.uid ?? 'Unknown',
          'requestedAt': DateTime.now(),
          'careerData': generatedSkillRoadmap.toJson(),
          'status': 'pending',
          'type': 'skill' 
        });

        if (mounted) {
          _searchController.clear();
          _skillSearchQuery = '';
          _navigateToEconomyDetail(generatedSkillRoadmap);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate roadmap. Try again.')));
      }
    } catch (e) {
       debugPrint("❌ Error generating skill: $e");
    } finally {
      if (mounted) setState(() => _isGeneratingSkill = false);
    }
  }

  void _navigateToEconomyDetail(CareerModel item) {
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => CareerDetailScreen(career: item, userData: _EarnLearnCache.userData!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text('Earn & Learn', style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          if (_hasRequiredProfileData)
            IconButton(icon: const Icon(Icons.refresh, color: AppTheme.primaryAccent), onPressed: () => _fetchAndAnalyze(forceRefresh: true)),
        ],
        bottom: _hasRequiredProfileData ? TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.secondaryAccent,
          labelColor: AppTheme.secondaryAccent,
          unselectedLabelColor: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
          tabs: const [
            Tab(icon: Icon(Icons.payments_outlined), text: "EARN NOW"),
            Tab(icon: Icon(Icons.school_outlined), text: "LEARN SKILLS"),
          ],
        ) : null,
      ),
      body: _isLoading 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(color: AppTheme.secondaryAccent),
                SizedBox(height: 24),
                Text("Optimizing the Matrix...", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500))
              ],
            )
          )
        : !_hasRequiredProfileData
            ? _buildLockedState(isDark, textColor)
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildEarnTab(isDark, textColor),
                  _buildLearnTab(isDark, textColor),
                ],
              ),
    );
  }

  Widget _buildLockedState(bool isDark, Color textColor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person_rounded, size: 100, color: AppTheme.secondaryAccent),
            const SizedBox(height: 24),
            Text("Unlock the Matrix", style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              "We need to know your tools to find your gigs.\nUpdate your assets, budget, and time availability in your profile to unlock personalized earning opportunities.",
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryAccent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) => _fetchAndAnalyze());
              },
              child: const Text('Update Profile Assets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEarnTab(bool isDark, Color textColor) {
    List<dynamic> basicGigs = (_EarnLearnCache.aiData != null && _EarnLearnCache.aiData!['earn'] != null) ? _EarnLearnCache.aiData!['earn'] : [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Immediate Opportunities", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Based on the tools you own right now.", style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
          const SizedBox(height: 20),
          
          if (_isGeneratingGig)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 16),
                    Text("AI is building your execution roadmap...", style: TextStyle(color: Colors.grey))
                  ],
                ),
              ),
            )
          else ...[
            ...basicGigs.map((gig) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () => _generateGig(gig['title']),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gig['title'], 
                          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                          softWrap: true,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(gig['payout'], style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(height: 12),
                        Text(gig['whyItFits'], style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, height: 1.4, fontSize: 14)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 16, color: AppTheme.secondaryAccent),
                            const SizedBox(width: 8),
                            Expanded(child: Text("Requires: ${gig['requiredAsset']}", style: const TextStyle(color: AppTheme.secondaryAccent, fontWeight: FontWeight.bold, fontSize: 13))),
                            const Icon(Icons.arrow_forward, size: 16, color: Colors.green),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],

          if ((_EarnLearnCache.verifiedGigs ?? []).isNotEmpty) ...[
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.verified, color: Colors.blueAccent, size: 20),
                SizedBox(width: 8),
                Text("Premium Verified Gigs", style: TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ..._EarnLearnCache.verifiedGigs!.map((gig) => _buildEconomyCard(gig, isDark, textColor, isVerified: true, isGig: true)),
          ],

          if ((_EarnLearnCache.pendingGigs ?? []).isNotEmpty) ...[
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.group, color: AppTheme.secondaryAccent, size: 20),
                SizedBox(width: 8),
                Text("Community Explored Gigs", style: TextStyle(color: AppTheme.secondaryAccent, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text("Generated by AI. Sent to Admin for verification.", style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, fontSize: 12)),
            const SizedBox(height: 16),
            ..._EarnLearnCache.pendingGigs!.map((gig) => _buildEconomyCard(gig, isDark, textColor, isVerified: false, isGig: true)),
          ],
        ],
      ),
    );
  }

  Widget _buildLearnTab(bool isDark, Color textColor) {
    List<CareerModel> displayVerified = (_EarnLearnCache.verifiedSkills ?? [])
        .where((s) => s.name.toLowerCase().contains(_skillSearchQuery.toLowerCase()))
        .toList();
    List<CareerModel> displayPending = (_EarnLearnCache.pendingSkills ?? [])
        .where((s) => s.name.toLowerCase().contains(_skillSearchQuery.toLowerCase()))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Search for any skill (e.g. Video Editing)...',
              hintStyle: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
              prefixIcon: const Icon(Icons.search, color: AppTheme.secondaryAccent),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (val) {
              setState(() {
                _skillSearchQuery = val;
              });
            },
          ),
          const SizedBox(height: 24),

          if (_isGeneratingSkill)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppTheme.secondaryAccent),
                    SizedBox(height: 16),
                    Text("AI is building your 30-day skill roadmap...", style: TextStyle(color: Colors.grey))
                  ],
                ),
              ),
            )
          else if (_skillSearchQuery.isNotEmpty && displayVerified.isEmpty && displayPending.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    const Icon(Icons.auto_awesome, size: 60, color: AppTheme.secondaryAccent),
                    const SizedBox(height: 16),
                    Text("Skill Not Found", style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Saakhi AI can build a custom 30-day roadmap for "$_skillSearchQuery".',
                      textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: () => _generateSkillWithAI(_skillSearchQuery),
                        icon: const Icon(Icons.bolt, color: Colors.white),
                        label: const Text('Generate with AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
            )
          else ...[
            if (displayVerified.isNotEmpty) ...[
              const Row(
                children: [
                  Icon(Icons.verified, color: Colors.blueAccent, size: 20),
                  SizedBox(width: 8),
                  Text("Premium Verified Skills", style: TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              ...displayVerified.map((skill) => _buildEconomyCard(skill, isDark, textColor, isVerified: true, isGig: false)),
              const SizedBox(height: 24),
            ],

            if (displayPending.isNotEmpty) ...[
              const Row(
                children: [
                  Icon(Icons.group, color: AppTheme.secondaryAccent, size: 20),
                  SizedBox(width: 8),
                  Text("Community Explored Skills", style: TextStyle(color: AppTheme.secondaryAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text("Generated by AI. Sent to Admin for verification.", style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, fontSize: 12)),
              const SizedBox(height: 16),
              ...displayPending.map((skill) => _buildEconomyCard(skill, isDark, textColor, isVerified: false, isGig: false)),
            ],

            if ((_EarnLearnCache.verifiedSkills ?? []).isEmpty && (_EarnLearnCache.pendingSkills ?? []).isEmpty && _skillSearchQuery.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40.0),
                  child: Text("No skills mapped yet. Search for a skill above to generate the first roadmap!", textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, height: 1.5)),
                ),
              )
          ]
        ],
      ),
    );
  }

  Widget _buildEconomyCard(CareerModel item, bool isDark, Color textColor, {required bool isVerified, required bool isGig}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isVerified ? Colors.blueAccent : AppTheme.primaryAccent).withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.primaryAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(
              isGig ? "💰 ${item.salaryBeginner.isNotEmpty ? item.salaryBeginner : item.expectedIncome}" : "⏱️ ~30 Days", 
              style: TextStyle(color: isGig ? Colors.green : AppTheme.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12)
            ),
          ),
          
          const SizedBox(height: 12),
          Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, height: 1.4, fontSize: 14)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isVerified ? Colors.blueAccent : AppTheme.secondaryAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () => _navigateToEconomyDetail(item),
              icon: Icon(Icons.bolt, color: isVerified ? Colors.blueAccent : AppTheme.secondaryAccent),
              label: Text(
                isGig ? "Open Execution Roadmap" : "Open Learning Roadmap", 
                style: TextStyle(color: isVerified ? Colors.blueAccent : AppTheme.secondaryAccent, fontWeight: FontWeight.bold)
              ),
            ),
          )
        ],
      ),
    );
  }
}