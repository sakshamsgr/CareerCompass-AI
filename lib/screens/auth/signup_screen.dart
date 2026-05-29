import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import 'otp_verification_screen.dart'; 

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  DateTime? _selectedDate;
  int? _calculatedAge;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
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

  Future<void> _initiateSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _calculatedAge == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your Date of Birth')));
      return;
    }
    if (_calculatedAge! < 13 || _calculatedAge! > 30) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ROADMAP is optimized for ages 13-30.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      
      String generatedOtp = await _authService.sendOtpEmail(email);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              actualOtp: generatedOtp,
              email: email,
              password: _passwordController.text.trim(),
              name: _nameController.text.trim(),
              age: _calculatedAge!,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🚀 MASSIVE EDGE-TO-EDGE BANNER
                  SizedBox(
                    width: double.infinity,
                    height: 140, 
                    child: Image.asset(
                      'assets/images/app_header.png', 
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 50),
                  
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: AppTheme.textWhite),
                    decoration: AppTheme.inputDecoration('Full Name', Icons.person, context), 
                    validator: (val) => val!.isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(color: Colors.white.withAlpha((0.05 * 255).round()), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          const Icon(Icons.cake, color: AppTheme.primaryAccent),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDate == null ? 'Select Date of Birth' : _formatDate(_selectedDate!),
                            style: TextStyle(color: _selectedDate == null ? AppTheme.textMuted : AppTheme.textWhite, fontSize: 16),
                          ),
                          const Spacer(),
                          if (_calculatedAge != null)
                            Text('Age: $_calculatedAge', style: const TextStyle(color: AppTheme.secondaryAccent, fontWeight: FontWeight.bold, fontSize: 16))
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: AppTheme.textWhite),
                    decoration: AppTheme.inputDecoration('Email', Icons.email, context), 
                    validator: (val) => val!.isEmpty ? 'Enter an email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: AppTheme.textWhite),
                    decoration: AppTheme.inputDecoration('Password', Icons.lock, context), 
                    validator: (val) => val!.length < 6 ? 'Password must be 6+ chars' : null,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isLoading ? null : _initiateSignUp, 
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Verify Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Already have an account? Login', style: TextStyle(color: AppTheme.textMuted)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}