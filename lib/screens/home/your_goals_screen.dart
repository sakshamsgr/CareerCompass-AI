import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';
import '../../services/ai_roadmap_service.dart';
import '../../data/models/career_model.dart';
import 'explore_careers_screen.dart'; 
import 'task_tracker_screen.dart'; 

class YourGoalsScreen extends StatefulWidget {
  const YourGoalsScreen({super.key});

  @override
  State<YourGoalsScreen> createState() => _YourGoalsScreenState();
}

class _YourGoalsScreenState extends State<YourGoalsScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  
  // State Trackers
  bool _isGeneratingDashboard = false;
  bool _isLoadingCareer = false;
  bool _isChecklistExpanded = false; 
  
  String? _lastGoal; 
  CareerModel? _targetCareer;

  // 🚀 FAST CHECKLIST STATE (Local Buffering)
  List<dynamic>? _localCompletedSteps;
  bool _isSaving = false;

  Future<void> _checkAndGenerateDashboard(String goal, Map<String, dynamic> userData) async {
    if (userData['goal_dashboard_data'] != null && userData['goal_dashboard_data']['targetGoal'] == goal) return;

    setState(() => _isGeneratingDashboard = true);
    final dashboardData = await AiRoadmapService.generateGoalDashboardData(goal, userData);
    
    if (dashboardData != null && _uid != null) {
      dashboardData['targetGoal'] = goal; 
      
      List<dynamic> existingTasks = userData['tasks'] ?? [];
      List<dynamic> newAiHabits = dashboardData['habits'] ?? [];
      List<dynamic> mergedTasks = [...existingTasks];
      for (var habit in newAiHabits) {
        if (!mergedTasks.any((t) => t is Map && t['name'] == habit['name'])) mergedTasks.add(habit);
      }

      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'goal_dashboard_data': dashboardData,
        'tasks': mergedTasks, 
      });
    }
    if (mounted) setState(() => _isGeneratingDashboard = false);
  }

  Future<void> _loadCareerRoadmap(String goalName, Map<String, dynamic> userData) async {
    setState(() => _isLoadingCareer = true);

    final activeQuery = await FirebaseFirestore.instance.collection('active_careers').where('name', isEqualTo: goalName).limit(1).get();
    if (activeQuery.docs.isNotEmpty) {
      _targetCareer = CareerModel.fromJson(activeQuery.docs.first.data(), id: activeQuery.docs.first.id);
    } else {
      final pendingQuery = await FirebaseFirestore.instance.collection('pending_requests').where('careerData.name', isEqualTo: goalName).limit(1).get();
      if (pendingQuery.docs.isNotEmpty) {
        _targetCareer = CareerModel.fromJson(pendingQuery.docs.first.data()['careerData'], isTemporary: true);
      }
    }

    if (_targetCareer != null && _uid != null) {
      List<dynamic> completedSteps = List.from(userData['completed_roadmap_steps'] ?? []);
      bool changed = false;

      if (completedSteps.isEmpty) {
        String edu = userData['education'] ?? '';
        int eduRank = _getEducationRank(edu); 
        
        for (var step in _targetCareer!.roadmapSteps) {
          String label = step.label.toString().toLowerCase();
          if (eduRank >= 5 && label.contains('10th')) { completedSteps.add(step.id); changed = true; }
          if (eduRank >= 7 && (label.contains('12th') || label.contains('diploma'))) { completedSteps.add(step.id); changed = true; }
          if (eduRank >= 8 && label.contains('undergraduate')) { completedSteps.add(step.id); changed = true; }
        }
        
        if (changed) {
          int totalRequired = _calculateRequiredSteps(_targetCareer!.roadmapSteps);
          double newProgress = (completedSteps.length / totalRequired) * 100;
          if (newProgress > 100) newProgress = 100;

          await FirebaseFirestore.instance.collection('users').doc(_uid).update({
            'completed_roadmap_steps': completedSteps,
            'progress': newProgress,
          });
        }
      }
    }
    
    if (mounted) setState(() => _isLoadingCareer = false);
  }

  int _getEducationRank(String edu) {
    if (edu == 'Class 11' || edu == 'Class 12' || edu == 'Diploma') return 7;
    if (edu == 'Undergraduate') return 8;
    if (edu == 'Postgraduate') return 9;
    return 5; 
  }

  int _calculateRequiredSteps(List<RoadmapNode> steps) {
    int required = steps.length;
    int pathOptionsCount = steps.where((s) => s.label.toLowerCase().contains('path ')).length;
    
    if (pathOptionsCount > 1) {
      required -= (pathOptionsCount - 1); 
    }
    return required > 0 ? required : 1; 
  }

  void _toggleRoadmapStepLocally(String stepId, List<dynamic> dbCompleted) {
    setState(() {
      _localCompletedSteps ??= List.from(dbCompleted); 
      
      if (_localCompletedSteps!.contains(stepId)) {
        _localCompletedSteps!.remove(stepId);
      } else {
        _localCompletedSteps!.add(stepId);
      }
    });
  }

  Future<void> _saveProgress() async {
    if (_uid == null || _targetCareer == null || _localCompletedSteps == null) return;
    
    setState(() => _isSaving = true);

    int totalRequired = _calculateRequiredSteps(_targetCareer!.roadmapSteps);
    double newProgress = (_localCompletedSteps!.length / totalRequired) * 100;
    if (newProgress > 100) newProgress = 100; 

    await FirebaseFirestore.instance.collection('users').doc(_uid).update({
      'completed_roadmap_steps': _localCompletedSteps,
      'progress': newProgress,
    });

    if (mounted) {
      setState(() {
        _isSaving = false;
        _localCompletedSteps = null; 
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Progress safely secured! 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ));
    }
  }

  Future<void> _navigateToCareerPage(Map<String, dynamic> userData) async {
    if (_targetCareer != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => CareerDetailScreen(career: _targetCareer!, userData: userData)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Career data not available yet.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting && _lastGoal == null) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent));
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          String? currentGoal = data?['currentGoal'];

          if (currentGoal == null || currentGoal.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_outlined, size: 80, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
                  const SizedBox(height: 16),
                  Text('No Dream Chosen', style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Go to Home to map your dream career.', style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
                ],
              ),
            );
          }

          if (currentGoal != _lastGoal) {
            _lastGoal = currentGoal;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkAndGenerateDashboard(currentGoal, data!);
              _loadCareerRoadmap(currentGoal, data);
            });
          }

          final dashData = data?['goal_dashboard_data'];
          
          final List<dynamic> dbCompletedSteps = data?['completed_roadmap_steps'] ?? [];
          final List<dynamic> activeCompletedSteps = _localCompletedSteps ?? dbCompletedSteps;
          final bool hasUnsavedChanges = _localCompletedSteps != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Target', style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(currentGoal, style: const TextStyle(color: AppTheme.primaryAccent, fontSize: 28, fontWeight: FontWeight.bold)),
                
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryAccent, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: () => _navigateToCareerPage(data!),
                    icon: const Icon(Icons.map, color: AppTheme.primaryAccent),
                    label: const Text("Go to Career Page ->", style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                
                const SizedBox(height: 30),

                // 🚀 INTERACTIVE DROPDOWN PROGRESS MARKER
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3))
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isChecklistExpanded = !_isChecklistExpanded),
                                child: Row(
                                  children: [
                                    const Icon(Icons.checklist_rtl_rounded, color: AppTheme.secondaryAccent, size: 24),
                                    const SizedBox(width: 8),
                                    // 🚀 FIXED: Wrapped in Expanded to prevent pixel overflow!
                                    Expanded(
                                      child: Text(
                                        "Mission Progress", 
                                        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            if (hasUnsavedChanges) ...[
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: _isSaving ? null : _saveProgress,
                                style: TextButton.styleFrom(
                                  backgroundColor: AppTheme.secondaryAccent.withValues(alpha: 0.15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                ),
                                child: _isSaving 
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondaryAccent))
                                    : const Text("Save", style: TextStyle(color: AppTheme.secondaryAccent, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                            ],

                            InkWell(
                              onTap: () => setState(() => _isChecklistExpanded = !_isChecklistExpanded),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: AppTheme.primaryAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: Icon(_isChecklistExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppTheme.primaryAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // The Expandable List
                      if (_isChecklistExpanded) ...[
                        const Divider(height: 1),
                        if (_isLoadingCareer)
                           const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
                        else if (_targetCareer == null)
                           Padding(padding: const EdgeInsets.all(20), child: Text("Roadmap data unavailable.", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600])))
                        else 
                           Padding(
                             padding: const EdgeInsets.symmetric(vertical: 8.0),
                             child: Column(
                               children: _targetCareer!.roadmapSteps.map((step) {
                                 bool isDone = activeCompletedSteps.contains(step.id);
                                 return CheckboxListTile(
                                   value: isDone,
                                   activeColor: AppTheme.secondaryAccent,
                                   checkColor: Colors.white,
                                   title: Text(
                                     step.label, 
                                     style: TextStyle(
                                       color: isDone ? Colors.grey : textColor,
                                       decoration: isDone ? TextDecoration.lineThrough : null,
                                       fontWeight: isDone ? FontWeight.normal : FontWeight.w600
                                     )
                                   ),
                                   onChanged: (val) => _toggleRoadmapStepLocally(step.id, dbCompletedSteps),
                                 );
                               }).toList(),
                             ),
                           ),
                      ]
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                if (_isGeneratingDashboard || dashData == null) ...[
                  const Center(child: Column(children: [CircularProgressIndicator(color: AppTheme.secondaryAccent), SizedBox(height: 16), Text("AI is building your personalized coaching dashboard...", style: TextStyle(color: Colors.grey))]))
                ] else ...[
                  
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.orangeAccent, Colors.deepOrange]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 5))]
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskTrackerScreen())),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                                child: const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Open My Habit Matrix", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 4),
                                    Text("Complete your daily tasks!", style: TextStyle(color: Colors.white70, fontSize: 14)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.format_quote_rounded, color: AppTheme.primaryAccent, size: 40),
                        const SizedBox(height: 8),
                        Text('"${dashData['expertQuote']}"', style: TextStyle(color: textColor, fontSize: 16, fontStyle: FontStyle.italic, height: 1.5)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const CircleAvatar(radius: 16, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white, size: 20)),
                            const SizedBox(width: 12),
                            Expanded(child: Text("- ${dashData['expertName']}", style: const TextStyle(color: AppTheme.secondaryAccent, fontWeight: FontWeight.bold))),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: _buildInfoCard('Timeline', dashData['timeline'], Icons.timer, Colors.blue, cardColor, textColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildInfoCard('Next Exam/Milestone', dashData['nextExamDate'], Icons.event, Colors.purple, cardColor, textColor)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildSectionHeader("How should I start?", Icons.rocket_launch, Colors.green, textColor),
                  const SizedBox(height: 12),
                  Text(dashData['howToStart'], style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 15, height: 1.5)),
                  const SizedBox(height: 30),

                  _buildSectionHeader("Challenges I'll Face", Icons.warning_amber_rounded, Colors.redAccent, textColor),
                  const SizedBox(height: 16),
                  ...List<Widget>.from(dashData['challenges'].map((challenge) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("⚡ ", style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                        Expanded(child: Text(challenge.toString(), style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 14))),
                      ],
                    ),
                  ))),
                  const SizedBox(height: 50),
                ]
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color iconColor, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}