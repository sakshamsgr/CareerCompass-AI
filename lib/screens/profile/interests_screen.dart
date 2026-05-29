import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';

class InterestsScreen extends StatefulWidget {
  final List<String>? initialInterests; 
  
  const InterestsScreen({super.key, this.initialInterests});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final Set<String> _selectedInterests = {};
  bool _isSaving = false;

  // 50 Highly diverse interests relevant to young adults
  final List<String> _allInterests = [
    'Drawing', 'Painting', 'Singing', 'Dancing', 'Playing Cricket', 'Football', 
    'Basketball', 'Badminton', 'Swimming', 'Gym & Fitness', 'Yoga', 'Martial Arts', 
    'Photography', 'Videography', 'Video Editing', 'UI/UX Design', 'Coding', 
    'Robotics', 'Electronics', 'Arduino/IoT', '3D Modeling', 'Animation', 
    'Creative Writing', 'Blogging', 'Poetry', 'Reading', 'History', 
    'Space/Astronomy', 'Psychology', 'Public Speaking', 'Debating', 'Acting', 
    'Stand-up Comedy', 'Cooking', 'Baking', 'Gardening', 'DIY Crafts', 
    'Fashion/Styling', 'Makeup Artistry', 'Gaming', 'Esports', 'Streaming', 
    'Board Games', 'Chess', 'Music Production', 'Playing Guitar', 
    'Playing Piano', 'Traveling', 'Investing/Finance', 'Cars & Bikes'
  ];

  @override
  void initState() {
    super.initState();
    // Load any existing interests so the user can easily edit them
    if (widget.initialInterests != null) {
      _selectedInterests.addAll(widget.initialInterests!);
    }
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_selectedInterests.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 3 interests to continue.')),
      );
      return;
    }
    
    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'interests': _selectedInterests.toList(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Interests saved perfectly!'), backgroundColor: AppTheme.secondaryAccent),
          );
          // Go back to the previous screen
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving interests: $e')));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        title: const Text('Your Interests', style: TextStyle(color: AppTheme.textWhite)),
        iconTheme: const IconThemeData(color: AppTheme.textWhite),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pick your passions.\nSelect at least 3.',
                    style: TextStyle(color: AppTheme.textWhite, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedInterests.length >= 3 ? AppTheme.secondaryAccent : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedInterests.length} Selected',
                    style: TextStyle(
                      color: _selectedInterests.length >= 3 ? Colors.white : AppTheme.textMuted, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _allInterests.length,
              itemBuilder: (context, index) {
                final interest = _allInterests[index];
                final isSelected = _selectedInterests.contains(interest);
                return InkWell(
                  onTap: () => _toggleInterest(interest),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryAccent : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      interest,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryAccent : AppTheme.textWhite,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedInterests.length >= 3 ? AppTheme.secondaryAccent : Colors.grey.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}