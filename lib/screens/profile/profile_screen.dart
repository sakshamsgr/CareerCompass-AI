import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/theme.dart';
import '../../services/storage_service.dart';
import 'interests_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _otherEduController = TextEditingController();
  
  DateTime? _selectedDate;
  int? _calculatedAge;
  String? _selectedEducation;
  String? _selectedBoard10;
  String? _selectedStream;
  String? _selectedCourse;
  String? _selectedDuration;
  String? _selectedCurrentYear;
  String? _selectedFinance;
  String? _selectedTime; // 🚀 NEW: Added time availability for Earn & Learn
  
  String? _profileImageUrl;
  bool _isUploadingImage = false;
  bool _isLoadingData = true;

  final List<String> _selectedSubjects10 = [];
  final List<String> _selectedAssets = [];
  final List<String> _savedInterests = []; 

  final List<String> _educationLevels = [
    'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10',
    'Class 11', 'Class 12', 'Diploma', 'Undergraduate', 'Postgraduate', 'Dropout', 'Other'
  ];
  
  final List<String> _boards = ['CBSE', 'ICSE', 'State Board', 'IGCSE', 'Other'];
  final List<String> _streams = ['Science (PCM)', 'Science (PCB)', 'Science (PCMB)', 'Commerce', 'Arts/Humanities'];
  final List<String> _courses = ['B.Tech / B.E', 'B.Sc', 'B.Com', 'BBA', 'BA', 'BCA', 'MBBS', 'BDS', 'LLB', 'Diploma', 'Other'];
  final List<String> _durations = ['1 Year', '2 Years', '3 Years', '4 Years', '5 Years'];
  
  // 🚀 UPGRADED: More descriptive finances for AI generation
  final List<String> _finances = [
    '₹0 (Bootstrapping)', 
    'Under ₹1,000 / month', 
    '₹1,000 - ₹5,000 / month', 
    '₹5,000+ / month'
  ];

  // 🚀 NEW: Crucial for AI to recommend realistic freelance/learning paths
  final List<String> _timeCommitments = [
    '1-2 Hours / Week', 
    '1-2 Hours / Day', 
    '3-4 Hours / Day', 
    '5+ Hours / Day', 
    'Weekends Only'
  ];
  
  final List<String> _allSubjects10 = ['Math', 'Science', 'English', 'Hindi', 'Social Science', 'Computer', 'Sanskrit', 'Regional Lang'];
  
  // 🚀 UPGRADED: Granular assets specifically targeted at Gig Economy & Digital Freelancing
  final List<String> _allAssets = [
    '📱 Basic Smartphone', 
    '📸 Good Phone Camera', 
    '💻 Basic Laptop', 
    '🎮 High-End/Gaming Laptop', 
    '🖥️ Desktop PC',
    '📱 Tablet / iPad', 
    '🌐 High-Speed WiFi', 
    '🚲 Bicycle', 
    '🛵 2-Wheeler + License', 
    '🚗 Car + License',
    '🎙️ Mic/Setup'
  ];

  bool get _isOver8th => ['Class 9', 'Class 10', 'Class 11', 'Class 12', 'Diploma', 'Undergraduate', 'Postgraduate'].contains(_selectedEducation);
  bool get _isOver10th => ['Class 11', 'Class 12', 'Diploma', 'Undergraduate', 'Postgraduate'].contains(_selectedEducation);
  bool get _isCollege => _selectedEducation == 'Undergraduate';

  @override
  void initState() {
    super.initState();
    _fetchExistingUserData();
  }

  Future<void> _fetchExistingUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _nameController.text = data['name'] ?? '';
            _calculatedAge = data['age'];
            if (data['dob'] != null) {
              _selectedDate = DateTime.parse(data['dob']);
            }
            _profileImageUrl = data['profileImage']; 
            
            if (_educationLevels.contains(data['education'])) _selectedEducation = data['education'];
            _otherEduController.text = data['otherEducation'] ?? '';
            if (_boards.contains(data['board10'])) _selectedBoard10 = data['board10'];
            
            if (data['subjects10'] != null) {
              _selectedSubjects10.addAll(List<String>.from(data['subjects10']));
            }
            if (_streams.contains(data['stream'])) _selectedStream = data['stream'];
            if (_courses.contains(data['course'])) _selectedCourse = data['course'];
            if (_durations.contains(data['duration'])) _selectedDuration = data['duration'];
            if (data['currentYear'] != null) _selectedCurrentYear = data['currentYear'];
            
            if (_finances.contains(data['financialCondition'])) _selectedFinance = data['financialCondition'];
            if (_timeCommitments.contains(data['timeCommitment'])) _selectedTime = data['timeCommitment']; // Load Time
            
            if (data['assets'] != null) {
              _selectedAssets.addAll(List<String>.from(data['assets']));
            }
            
            if (data['interests'] != null) {
              _savedInterests.clear();
              _savedInterests.addAll(List<String>.from(data['interests']));
            }
          });
        }
      } catch (e) {
        debugPrint("Error fetching user data: $e");
      }
    }
    setState(() => _isLoadingData = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoadingData = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'dob': _selectedDate?.toIso8601String(),
        'age': _calculatedAge,
        'education': _selectedEducation,
        'otherEducation': _otherEduController.text.trim(),
        'board10': _selectedBoard10,
        'subjects10': _selectedSubjects10,
        'stream': _selectedStream,
        'course': _selectedCourse,
        'duration': _selectedDuration,
        'currentYear': _selectedCurrentYear,
        'financialCondition': _selectedFinance,
        'timeCommitment': _selectedTime, // 🚀 Save Time Commitment
        'assets': _selectedAssets,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: AppTheme.secondaryAccent)
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickAndCropImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), 
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: AppTheme.backgroundDark,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            activeControlsWidgetColor: AppTheme.primaryAccent,
          ),
          IOSUiSettings(title: 'Crop Profile Picture', aspectRatioLockEnabled: true),
        ],
      );

      if (croppedFile != null) {
        setState(() => _isUploadingImage = true);
        try {
          String downloadUrl = await StorageService().uploadProfileImage(File(croppedFile.path));
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'profileImage': downloadUrl});
          }
          setState(() => _profileImageUrl = downloadUrl);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!'), backgroundColor: AppTheme.secondaryAccent));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
        } finally {
          setState(() => _isUploadingImage = false);
        }
      }
    }
  }

  void _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) age--;
    setState(() => _calculatedAge = age);
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.primaryAccent, surface: AppTheme.backgroundDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _calculateAge(picked);
      });
    }
  }

  void _toggleSelection(List<String> list, String item, {int? max}) {
    setState(() {
      if (list.contains(item)) {
        list.remove(item);
      } else {
        if (max == null || list.length < max) {
          list.add(item);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Maximum $max selections allowed.')));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Personal Details', style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveProfile();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoadingData 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50, 
                      backgroundColor: AppTheme.primaryAccent.withValues(alpha: 0.2), 
                      backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                      child: _profileImageUrl == null ? const Icon(Icons.person, size: 50, color: AppTheme.primaryAccent) : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.secondaryAccent,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: _isUploadingImage 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.camera_alt, size: 16, color: Colors.white), 
                          onPressed: _isUploadingImage ? null : _pickAndCropImage,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _nameController,
                style: TextStyle(color: textColor),
                decoration: AppTheme.inputDecoration('Full Name', Icons.person, context), 
              ),
              const SizedBox(height: 16),
              
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      const Icon(Icons.cake, color: AppTheme.primaryAccent),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDate == null ? 'Confirm Date of Birth' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        style: TextStyle(color: _selectedDate == null ? (isDark ? AppTheme.textMuted : AppTheme.textMutedLight) : textColor, fontSize: 16),
                      ),
                      const Spacer(),
                      if (_calculatedAge != null)
                        Text('Age: $_calculatedAge', style: const TextStyle(color: AppTheme.secondaryAccent, fontWeight: FontWeight.bold, fontSize: 16))
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                dropdownColor: isDark ? AppTheme.backgroundDark : Colors.white,
                style: TextStyle(color: textColor),
                decoration: AppTheme.inputDecoration('Current Education', Icons.school, context), 
                initialValue: _selectedEducation,
                items: _educationLevels.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() {
                  _selectedEducation = val;
                  _selectedSubjects10.clear();
                }),
              ),
              const SizedBox(height: 16),

              if (_selectedEducation == 'Other') ...[
                TextFormField(
                  controller: _otherEduController,
                  style: TextStyle(color: textColor),
                  decoration: AppTheme.inputDecoration('Specify Education', Icons.edit, context), 
                ),
                const SizedBox(height: 16),
              ],

              if (_isOver8th) ...[
                const Divider(),
                const Text('Class 10 Details', style: TextStyle(color: AppTheme.primaryAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: isDark ? AppTheme.backgroundDark : Colors.white,
                  style: TextStyle(color: textColor),
                  decoration: AppTheme.inputDecoration('Examination Board', Icons.account_balance, context), 
                  initialValue: _selectedBoard10,
                  items: _boards.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _selectedBoard10 = val),
                ),
                const SizedBox(height: 12),
                Text('Select Subjects (4 to 6)', style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allSubjects10.map((sub) {
                    final isSelected = _selectedSubjects10.contains(sub);
                    return FilterChip(
                      label: Text(sub, style: TextStyle(color: isSelected ? Colors.white : (isDark ? AppTheme.textMuted : AppTheme.textMutedLight))),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryAccent,
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      onSelected: (_) => _toggleSelection(_selectedSubjects10, sub, max: 6),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              if (_isOver10th) ...[
                const Divider(),
                const Text('Higher Secondary Details', style: TextStyle(color: AppTheme.primaryAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: isDark ? AppTheme.backgroundDark : Colors.white,
                  style: TextStyle(color: textColor),
                  decoration: AppTheme.inputDecoration('Stream / Major', Icons.menu_book, context), 
                  initialValue: _selectedStream,
                  items: _streams.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _selectedStream = val),
                ),
                const SizedBox(height: 16),
              ],

              if (_isCollege) ...[
                const Divider(),
                const Text('Undergraduate Details', style: TextStyle(color: AppTheme.primaryAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: isDark ? AppTheme.backgroundDark : Colors.white,
                  style: TextStyle(color: textColor),
                  decoration: AppTheme.inputDecoration('Course', Icons.library_books, context), 
                  initialValue: _selectedCourse,
                  items: _courses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _selectedCourse = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        dropdownColor: isDark ? AppTheme.backgroundDark : Colors.white,
                        style: TextStyle(color: textColor),
                        decoration: AppTheme.inputDecoration('Duration', Icons.timer, context), 
                        initialValue: _selectedDuration,
                        items: _durations.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setState(() => _selectedDuration = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        dropdownColor: isDark ? AppTheme.backgroundDark : Colors.white,
                        style: TextStyle(color: textColor),
                        decoration: AppTheme.inputDecoration('Current Yr', Icons.event, context), 
                        initialValue: _selectedCurrentYear,
                        items: _durations.map((e) => DropdownMenuItem(value: e, child: Text(e.replaceAll('Years', 'Year')))).toList(),
                        onChanged: (val) => setState(() => _selectedCurrentYear = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 🚀 UPGRADED: Tools, Time & Finance Section for Earn & Learn Matrix
              const Divider(),
              const Text('Tools, Time & Finance (For Earning)', style: TextStyle(color: AppTheme.primaryAccent, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('We use this to find the best side-hustles, freelancing gigs, and skills you can learn right now.', style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight, fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                dropdownColor: isDark ? AppTheme.backgroundDark : Colors.white,
                style: TextStyle(color: textColor),
                decoration: AppTheme.inputDecoration('Monthly Investment Budget', Icons.account_balance_wallet, context), 
                initialValue: _selectedFinance,
                items: _finances.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _selectedFinance = val),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                dropdownColor: isDark ? AppTheme.backgroundDark : Colors.white,
                style: TextStyle(color: textColor),
                decoration: AppTheme.inputDecoration('Time Available for Hustles/Learning', Icons.hourglass_empty, context), 
                initialValue: _selectedTime,
                items: _timeCommitments.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _selectedTime = val),
              ),
              const SizedBox(height: 16),

              Text('Current Assets (Select all that apply)', style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allAssets.map((asset) {
                  final isSelected = _selectedAssets.contains(asset);
                  return FilterChip(
                    label: Text(asset, style: TextStyle(color: isSelected ? Colors.white : (isDark ? AppTheme.textMuted : AppTheme.textMutedLight))),
                    selected: isSelected,
                    selectedColor: AppTheme.secondaryAccent,
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    onSelected: (_) => _toggleSelection(_selectedAssets, asset),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),

              // --- THE NEW INTERESTS DISPLAY & EDIT SECTION ---
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Your Passions & Interests', style: TextStyle(color: AppTheme.primaryAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => InterestsScreen(initialInterests: _savedInterests))
                      ).then((_) {
                        setState(() {
                          _isLoadingData = true;
                        });
                        _fetchExistingUserData();
                      }); 
                    },
                    icon: const Icon(Icons.edit, color: AppTheme.secondaryAccent, size: 18),
                    label: const Text('Edit', style: TextStyle(color: AppTheme.secondaryAccent)),
                  )
                ],
              ),
              const SizedBox(height: 12),
              if (_savedInterests.isEmpty)
                Text('No interests selected yet.', style: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _savedInterests.map((interest) => Chip(
                    label: Text(interest, style: const TextStyle(color: Colors.white)),
                    backgroundColor: AppTheme.primaryAccent.withValues(alpha: 0.8),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  )).toList(),
                ),
              const SizedBox(height: 40),
              // ----------------------------------------

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    if (_isOver8th && _selectedSubjects10.length < 4) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least 4 Class 10 subjects.')));
                      return;
                    }
                    await _saveProfile();
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Save & Close', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(width: 8),
                      Icon(Icons.check, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}