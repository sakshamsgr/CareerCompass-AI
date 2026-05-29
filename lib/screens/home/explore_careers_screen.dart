import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../data/models/career_model.dart';
import '../../services/ai_roadmap_service.dart';
import '../profile/profile_screen.dart';
import 'interactive_roadmap_screen.dart'; 
import 'main_screen.dart'; 

// 🚀 HACKATHON GOD-MODE: STATIC RAM CACHE
class _ExploreCache {
  static Map<String, dynamic>? userData;
  static List<CareerModel>? allCareers;
  static List<CareerModel>? pendingCareers;
}

class ExploreCareersScreen extends StatefulWidget {
  const ExploreCareersScreen({super.key});

  @override
  State<ExploreCareersScreen> createState() => _ExploreCareersScreenState();
}

class _ExploreCareersScreenState extends State<ExploreCareersScreen> {
  bool _isLoading = true;
  bool _isGeneratingAi = false;
  String _searchQuery = '';
  
  bool _showPersonalized = true;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _fetchData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    // 🚀 INSTANT LOAD: If data is already in RAM, show it immediately!
    if (_ExploreCache.allCareers != null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) _ExploreCache.userData = doc.data();
      }

      final snapshot = await FirebaseFirestore.instance.collection('active_careers').get();
      List<CareerModel> loadedCareers = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          String docType = data['type']?.toString().toLowerCase() ?? '';
          if (docType != 'skill' && docType != 'gig') {
            loadedCareers.add(CareerModel.fromJson(data, id: doc.id));
          }
        } catch (parseError) {
          debugPrint("⚠️ FAILED TO PARSE CAREER '${doc.id}': $parseError");
        }
      }
      _ExploreCache.allCareers = loadedCareers;

      if (user != null) {
        final pendingSnapshot = await FirebaseFirestore.instance
            .collection('pending_requests')
            .where('requestedBy', isEqualTo: user.uid)
            .get();
            
        List<CareerModel> loadedPending = [];
        for (var doc in pendingSnapshot.docs) {
          try {
            final data = doc.data();
            String docType = data['type']?.toString() ?? '';
            String docName = data['careerData']?['name']?.toString() ?? '';
            
            bool isSkillOrGig = docType == 'skill' || docType == 'gig' || 
                                docName.startsWith('Mastering') || 
                                docName.startsWith('Executing');

            if (!isSkillOrGig && data['careerData'] != null) {
              loadedPending.add(CareerModel.fromJson(data['careerData'], id: doc.id, isTemporary: true));
            }
          } catch (e) {}
        }
        _ExploreCache.pendingCareers = loadedPending;
      }

    } catch (e) {
      debugPrint("Error fetching careers: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isProfileComplete() {
    if (_ExploreCache.userData == null) return false;
    return (_ExploreCache.userData!['name'] != null && _ExploreCache.userData!['age'] != null && _ExploreCache.userData!['education'] != null);
  }

  List<CareerModel> _getFilteredList(List<CareerModel> sourceList, bool personalized) {
    List<CareerModel> filtered = sourceList.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    if (_searchQuery.isNotEmpty) return filtered;
    if (!personalized) return filtered;
    if (_ExploreCache.userData == null || _ExploreCache.userData!['education'] == null) return filtered;

    String education = _ExploreCache.userData!['education'];
    String stream = _ExploreCache.userData!['stream'] ?? '';
    bool isOver10th = ['Class 11', 'Class 12', 'Diploma', 'Undergraduate', 'Postgraduate'].contains(education);

    if (isOver10th && stream.isNotEmpty) {
      filtered = filtered.where((c) {
        if (c.requiredStreams.any((s) => s.toLowerCase() == 'any')) return true;
        return c.requiredStreams.any((s) => s.toLowerCase() == stream.toLowerCase());
      }).toList();
    }
    return filtered;
  }

  Future<void> _triggerAiGeneration() async {
    setState(() => _isGeneratingAi = true);
    try {
      final generatedCareer = await AiRoadmapService.generateCareerRoadmap(_searchQuery);
      if (!mounted) return; 

      if (generatedCareer != null) {
        final query = await FirebaseFirestore.instance.collection('pending_requests')
            .where('careerData.name', isEqualTo: generatedCareer.name)
            .get();
            
        if (query.docs.isEmpty) {
          await FirebaseFirestore.instance.collection('pending_requests').add({
            'requestedBy': FirebaseAuth.instance.currentUser?.uid ?? 'Unknown',
            'requestedAt': DateTime.now(),
            'careerData': generatedCareer.toJson(),
            'status': 'pending',
            'type': 'career' 
          });
          
          setState(() {
            _ExploreCache.pendingCareers?.add(generatedCareer);
          });
        }
        
        if (mounted) {
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => CareerDetailScreen(career: generatedCareer, userData: _ExploreCache.userData!))
          );
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate roadmap. Try again.')));
      }
    } catch (e) {
      debugPrint("Error auto-submitting: $e");
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  void _onToggleSwitch(bool isPersonalized) {
    setState(() => _showPersonalized = isPersonalized);
    _pageController.animateToPage(isPersonalized ? 0 : 1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
      );
    }

    if (!_isProfileComplete()) return _buildIncompleteProfileState(isDark, textColor);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(title: Text('Explore Careers', style: TextStyle(color: textColor)), iconTheme: IconThemeData(color: textColor)),
      body: Column(
        children: [
          _buildSearchBar(isDark, textColor),
          _buildToggleSwitch(isDark),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _showPersonalized = index == 0),
              children: [
                _buildTabContent(true, isDark, textColor),  
                _buildTabContent(false, isDark, textColor), 
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTabContent(bool personalized, bool isDark, Color textColor) {
    final displayPublished = _getFilteredList(_ExploreCache.allCareers ?? [], personalized);
    final displayPending = _getFilteredList(_ExploreCache.pendingCareers ?? [], personalized);

    if (displayPublished.isEmpty && displayPending.isEmpty && _searchQuery.isNotEmpty) {
      return _buildAiTriggerState(textColor, isDark);
    } else if (displayPublished.isEmpty && displayPending.isEmpty && _searchQuery.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            personalized 
              ? "No careers match your current educational stream yet.\nTry searching to map a new one with AI, or check out 'All Careers'!"
              : "No careers have been published by the Admin yet.",
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, height: 1.5),
          ),
        )
      );
    } 
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (displayPublished.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text("Published Careers", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildCareerGrid(displayPublished, isDark, textColor),
          ],
          if (displayPending.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text("Your Pending AI Maps", style: TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            _buildCareerGrid(displayPending, isDark, textColor),
          ]
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: TextField(
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: 'Search careers...',
          hintStyle: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryAccent),
          filled: true,
          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildToggleSwitch(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(25)),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _onToggleSwitch(true), 
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(color: _showPersonalized ? AppTheme.primaryAccent : Colors.transparent, borderRadius: BorderRadius.circular(25)),
                  alignment: Alignment.center,
                  child: Text('For You', style: TextStyle(color: _showPersonalized ? Colors.white : (isDark ? AppTheme.textMuted : AppTheme.textMutedLight), fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _onToggleSwitch(false), 
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(color: !_showPersonalized ? AppTheme.primaryAccent : Colors.transparent, borderRadius: BorderRadius.circular(25)),
                  alignment: Alignment.center,
                  child: Text('All Careers', style: TextStyle(color: !_showPersonalized ? Colors.white : (isDark ? AppTheme.textMuted : AppTheme.textMutedLight), fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareerGrid(List<CareerModel> careers, bool isDark, Color textColor) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85),
      itemCount: careers.length,
      itemBuilder: (context, index) {
        final career = careers[index];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CareerDetailScreen(career: career, userData: _ExploreCache.userData!))),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: career.isTemporary ? Colors.orange.withValues(alpha: 0.5) : AppTheme.primaryAccent.withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(career.isTemporary ? Icons.auto_awesome : Icons.work_outline_rounded, size: 40, color: career.isTemporary ? Colors.orange : AppTheme.primaryAccent), 
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(child: Text(career.name, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(career.expectedIncome, style: const TextStyle(color: AppTheme.secondaryAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiTriggerState(Color textColor, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 80, color: AppTheme.secondaryAccent),
            const SizedBox(height: 20),
            Text('Uncharted Territory', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Saakhi AI can map a custom roadmap for "$_searchQuery" in real-time.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _isGeneratingAi ? null : _triggerAiGeneration,
                child: _isGeneratingAi ? const CircularProgressIndicator(color: Colors.white) : const Text('Map it with AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildIncompleteProfileState(bool isDark, Color textColor) {
    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(title: Text('Explore Careers', style: TextStyle(color: textColor))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle_outlined, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              Text('Profile Incomplete', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Complete your profile to see personalized roadmaps.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                child: const Text('Complete Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// THE CAREER DETAIL SCREEN 
// ----------------------------------------------------------------------
class CareerDetailScreen extends StatefulWidget {
  final CareerModel career;
  final Map<String, dynamic> userData;

  const CareerDetailScreen({super.key, required this.career, required this.userData});

  @override
  State<CareerDetailScreen> createState() => _CareerDetailScreenState();
}

class _CareerDetailScreenState extends State<CareerDetailScreen> {
  bool _isSettingGoal = false;
  bool _goalSet = false;

  @override
  void initState() {
    super.initState();
    if (widget.userData['currentGoal'] == widget.career.name) {
      _goalSet = true;
    }
  }

  String _calculateTimeToComplete() {
    int currentAge = widget.userData['age'] ?? 18;
    int yearsLeft = widget.career.baseGraduationAge - currentAge;
    if (yearsLeft <= 0) return 'Variable (Based on effort)';
    return '~$yearsLeft Years';
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  Future<void> _toggleGoal() async {
    setState(() => _isSettingGoal = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (_goalSet) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'currentGoal': FieldValue.delete(), 
            'progress': 0, 
            'completed_roadmap_steps': FieldValue.delete(), 
            'goal_dashboard_data': FieldValue.delete(), 
          });
          if (mounted) setState(() => _goalSet = false);
        } else {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'currentGoal': widget.career.name,
            'progress': 0, 
            'completed_roadmap_steps': FieldValue.delete(), 
            'goal_dashboard_data': FieldValue.delete(), 
          });
          if (mounted) setState(() => _goalSet = true);
        }
      }
    } finally {
      if (mounted) setState(() => _isSettingGoal = false);
    }
  }

  Widget _buildGoalButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60, 
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _goalSet ? AppTheme.secondaryAccent.withValues(alpha: 0.15) : AppTheme.primaryAccent, 
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: _goalSet ? const BorderSide(color: AppTheme.secondaryAccent, width: 2) : BorderSide.none,
              ),
              elevation: _goalSet ? 0 : 4,
              shadowColor: AppTheme.primaryAccent.withValues(alpha: 0.5),
            ),
            onPressed: _isSettingGoal ? null : _toggleGoal,
            child: _isSettingGoal 
                ? const CircularProgressIndicator(color: AppTheme.primaryAccent) 
                : FittedBox( 
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_goalSet) ...[
                          const Icon(Icons.check_circle, color: AppTheme.secondaryAccent),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _goalSet ? 'Target Locked (Tap to Remove)' : 'Set as Your Goal', 
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: _goalSet ? AppTheme.secondaryAccent : Colors.white
                          )
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        
        if (_goalSet) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 55,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.orangeAccent, Colors.deepOrange]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context, 
                    MaterialPageRoute(builder: (context) => const MainScreen(initialPage: 1)), 
                    (route) => false
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: FittedBox( 
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Go to your goal! ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(title: Text(widget.career.name, style: TextStyle(color: textColor))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.career.isTemporary) ...[
              _buildAiBanner(isDark),
              const SizedBox(height: 20),
            ],
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(widget.career.name, style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(widget.career.expectedIncome.split(' ')[0], style: const TextStyle(color: AppTheme.secondaryAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Est. Time: ${_calculateTimeToComplete()}', style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, fontSize: 12)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 24),

            _buildGoalButton(),
            const SizedBox(height: 30),

            Text('Overview', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.career.description, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 16, height: 1.5)),
            const SizedBox(height: 30),

            _buildInteractiveRoadmapButton(isDark, textColor),
            const SizedBox(height: 30),

            if (widget.career.coreSkills.isNotEmpty) ...[
              Text('Core Skills Required', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.career.coreSkills.map((skill) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.secondaryAccent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    skill, 
                    style: const TextStyle(color: AppTheme.secondaryAccent, fontWeight: FontWeight.bold, fontSize: 13)
                  ),
                )).toList(),
              ),
              const SizedBox(height: 30),
            ],

            if (widget.career.pros.isNotEmpty || widget.career.cons.isNotEmpty) ...[
              Text('The Reality Check', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3))
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.thumb_up, color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text("The Perks", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...widget.career.pros.map((pro) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("• ", style: TextStyle(color: Colors.green)),
                                Expanded(child: Text(pro, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 13))),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3))
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text("The Grind", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...widget.career.cons.map((con) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("• ", style: TextStyle(color: Colors.red)),
                                Expanded(child: Text(con, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 13))),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],

            Text('Salary Breakdown', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(child: _buildSalaryCard('Beginner', widget.career.salaryBeginner, Colors.green, cardColor, textColor)),
                const SizedBox(width: 8),
                Expanded(child: _buildSalaryCard('Mid-Level', widget.career.salaryMid, Colors.orange, cardColor, textColor)),
                const SizedBox(width: 8),
                Expanded(child: _buildSalaryCard('High-Level', widget.career.salaryHigh, Colors.purple, cardColor, textColor)),
              ],
            ),
            const SizedBox(height: 30),

            if (widget.career.topCompanies.isNotEmpty) ...[
              Text('Top Hiring Companies', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.career.topCompanies.map((company) => Chip(
                  label: Text(company, style: const TextStyle(color: Colors.white)),
                  backgroundColor: AppTheme.primaryAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide.none,
                )).toList(),
              ),
              const SizedBox(height: 30),
            ],

            _buildExamSection(isDark, textColor, cardColor),
            const SizedBox(height: 30),

            if (widget.career.branches.isNotEmpty) ...[
              Text('Specialization Branches', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...widget.career.branches.map((branch) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.2))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(branch.name, style: const TextStyle(color: AppTheme.primaryAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(branch.description, style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, height: 1.4)),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveRoadmapButton(bool isDark, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryAccent, AppTheme.secondaryAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryAccent.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          )
        ]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => InteractiveRoadmapScreen(career: widget.career))
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.account_tree_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("See Detailed Roadmap", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Explore the interactive step-by-step path", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.auto_awesome, color: Colors.orange),
        const SizedBox(width: 12),
        Expanded(child: Text("Generated by AI. Sent to Admin for verification.", style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[800], fontSize: 12))),
      ]),
    );
  }

  Widget _buildSalaryCard(String level, String amount, Color color, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      decoration: BoxDecoration(
        color: cardColor, 
        borderRadius: BorderRadius.circular(12), 
        border: Border(bottom: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
      ),
      child: Column(
        children: [
          Text(level, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildExamSection(bool isDark, Color textColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.school, color: AppTheme.primaryAccent),
            const SizedBox(width: 8),
            Text('Required Stream:', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.career.requiredStreams.join(' or '), style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight))),
          ]),
          const Divider(height: 24),
          Row(children: [
            const Icon(Icons.assignment, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Major Exams:', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.career.examsNeeded, style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight))),
          ]),
          if (widget.career.examLink.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _launchUrl(widget.career.examLink),
              child: Text('🔗 ${widget.career.examLinkName}', style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
            ),
          ]
        ],
      ),
    );
  }
}