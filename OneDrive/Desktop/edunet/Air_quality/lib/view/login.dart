import 'package:aqi/modal/auth_services.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoginMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildLogo(),
                    const SizedBox(height: 30),
                    _buildModeToggle(),
                    const SizedBox(height: 32),
                    _buildEmailField(),
                    const SizedBox(height: 20),
                    _buildPasswordField(),
                    if (!_isLoginMode) const SizedBox(height: 20),
                    if (!_isLoginMode) _buildConfirmPasswordField(),
                    if (_isLoginMode) const SizedBox(height: 10),
                    if (_isLoginMode) _buildForgotPassword(),
                    const SizedBox(height: 30),
                    _buildSubmitButton(),
                    const SizedBox(height: 24),
                    _buildDivider(),
                    const SizedBox(height: 24),
                    _buildSocialButtons(),
                    const SizedBox(height: 32),
                    _buildTerms(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
          ),
          child: const Icon(Icons.air, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          'AIR GUARD',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Breathe Safe, Live Healthy',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 1.5,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLoginMode = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: _isLoginMode ? Colors.white.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    'LOGIN',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: _isLoginMode ? Colors.white : Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLoginMode = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: !_isLoginMode ? Colors.white.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    'SIGN UP',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: !_isLoginMode ? Colors.white : Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        prefixIcon: Icon(Icons.email_outlined, color: Colors.white.withOpacity(0.8)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your email';
        if (!value.contains('@')) return 'Please enter a valid email';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        prefixIcon: Icon(Icons.lock_outline, color: Colors.white.withOpacity(0.8)),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white.withOpacity(0.8)),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your password';
        if (value.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        prefixIcon: Icon(Icons.lock_outline, color: Colors.white.withOpacity(0.8)),
        suffixIcon: IconButton(
          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white.withOpacity(0.8)),
          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please confirm your password';
        if (value != _passwordController.text) return 'Passwords do not match';
        return null;
      },
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => _showSnackBar('Password recovery feature will be implemented'),
        child: Text('Forgot Password?', style: TextStyle(color: Colors.white.withOpacity(0.9))),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
            : Text(_isLoginMode ? 'LOG IN' : 'SIGN UP', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Or continue with', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialButton(Icons.g_mobiledata_rounded, 'Google', Colors.orange, Colors.white),
        const SizedBox(width: 20),
        _socialButton(Icons.apple, 'Apple', Colors.white, Colors.black),
        const SizedBox(width: 20),
        _socialButton(Icons.facebook, 'Facebook', Colors.white, const Color(0xFF4267B2)),
      ],
    );
  }

  Widget _socialButton(IconData icon, String label, Color color, Color bg) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: IconButton(onPressed: () => _showSnackBar('$label login will be implemented'), icon: Icon(icon, color: color)),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
      ],
    );
  }

  Widget _buildTerms() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
          children: [
            const TextSpan(text: 'By continuing, you agree to our '),
            WidgetSpan(
              child: GestureDetector(
                onTap: () => _showSnackBar('Terms of Service will be shown'),
                child: const Text('Terms of Service', style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
              ),
            ),
            const TextSpan(text: ' and '),
            WidgetSpan(
              child: GestureDetector(
                onTap: () => _showSnackBar('Privacy Policy will be shown'),
                child: const Text('Privacy Policy', style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundGradient() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primary.withOpacity(0.95), AppColors.primary, AppColors.primary.withOpacity(0.9), AppColors.secondary.withOpacity(0.8)],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ),
    );
  }
Future<void> _handleSubmit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    User? user;

    if (_isLoginMode) {
      user = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (user != null){
         _showSnackBar("Login successful!");
         Navigator.of(context).pushReplacementNamed('/health-profile');

         }

    } else {
      user = await _authService.signup(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: 'New User', // You can add a Name field to the form later
      );
      if (user != null) _showSnackBar("Signup successful!");
    }

    if (user != null) {
      // Give a short delay so SnackBar shows
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/health-profile');
    }
  } on FirebaseAuthException catch (e) {
    String msg = '';
    switch (e.code) {
      case 'user-not-found':
        msg = 'No user found for that email.';
        break;
      case 'wrong-password':
        msg = 'Wrong password provided.';
        break;
      case 'email-already-in-use':
        msg = 'Email is already registered.';
        break;
      case 'invalid-email':
        msg = 'Invalid email address.';
        break;
      case 'weak-password':
        msg = 'Password is too weak.';
        break;
      default:
        msg = e.message ?? 'Authentication failed.';
    }
    if (mounted) _showSnackBar(msg);
  } catch (e) {
    if (mounted) _showSnackBar('Error: ${e.toString()}');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}



  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 10,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
