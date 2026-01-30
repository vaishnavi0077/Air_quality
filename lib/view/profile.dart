// lib/screens/profile_screen.dart (UPDATED VERSION)

import 'package:aqi/view/login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aqi/theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  // Controllers with default empty values
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ============ SAFE DATA LOADING ============
  Future<void> _loadUserData() async {
    try {
      _currentUser = _auth.currentUser;
      
      if (_currentUser == null) {
        print('No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      print('Loading data for user: ${_currentUser!.uid}');
      
      final doc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      
      if (doc.exists && doc.data() != null) {
        // Load from Firestore
        _userData = doc.data()!;
        print('Loaded Firestore data: $_userData');
      } else {
        // Create new document
        print('No document found, creating new one...');
        await _createNewUserDocument();
      }

      // Update controllers with null-safe values
      _updateControllersFromData();
      
    } catch (e) {
      print('Error in _loadUserData: $e');
      // If error, still set defaults
      _updateControllersFromData();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============ CREATE NEW USER DOCUMENT ============
  Future<void> _createNewUserDocument() async {
    try {
      _userData = {
        'uid': _currentUser!.uid,
        'name': _currentUser!.displayName ?? '',
        'email': _currentUser!.email ?? '',
        'phone': '',
        'location': '',
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'emailVerified': _currentUser!.emailVerified,
        'photoURL': _currentUser!.photoURL,
        'notificationsEnabled': true,
      };
      
      await _firestore.collection('users').doc(_currentUser!.uid).set(_userData);
      print('Created new user document');
    } catch (e) {
      print('Error creating document: $e');
    }
  }

  // ============ SAFE CONTROLLER UPDATE ============
  void _updateControllersFromData() {
    // Always use null-safe access with fallback values
    _nameController.text = _userData['name']?.toString() ?? 
                          _currentUser?.displayName ?? 
                          '';
    
    _emailController.text = _userData['email']?.toString() ?? 
                           _currentUser?.email ?? 
                           '';
    
    _phoneController.text = _userData['phone']?.toString() ?? '';
    _locationController.text = _userData['location']?.toString() ?? '';
  }

  // ============ SAVE UPDATES TO FIREBASE ============
  Future<void> _saveProfile() async {
    if (_currentUser == null) return;

    setState(() => _isSaving = true);

    try {
      final updatedData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'updatedAt': DateTime.now(),
      };

      print('Saving to Firestore: $updatedData');
      
      // Save to Firestore using set with merge
      await _firestore.collection('users').doc(_currentUser!.uid).set(
        updatedData,
        SetOptions(merge: true),
      );

      // Update local state
      setState(() {
        _userData.addAll(updatedData);
        _isEditing = false;
      });

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Error saving profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ============ LOGOUT ============
  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUser == null) {
      return _buildNotLoggedInUI();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppColors.primary,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(),
            // Profile Form
            _buildProfileForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLoggedInUI() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text('Please login to view profile'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: _currentUser?.photoURL != null
                ? ClipOval(
                    child: Image.network(
                      _currentUser!.photoURL!,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            _nameController.text.isNotEmpty ? _nameController.text : 'User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _emailController.text,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildProfileField('Full Name', _nameController.text, Icons.person, true),
          _buildProfileField('Email', _emailController.text, Icons.email, false),
          _buildProfileField('Phone', _phoneController.text, Icons.phone, true),
          _buildProfileField('Location', _locationController.text, Icons.location_on, true),
          
          if (_isEditing) _buildEditForm(),
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, String value, IconData icon, bool editable) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : 'Not set',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (editable && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        const SizedBox(height: 20),
        _buildEditField('Full Name', _nameController),
        const SizedBox(height: 15),
        _buildEditField('Phone', _phoneController),
        const SizedBox(height: 15),
        _buildEditField('Location', _locationController),
        const SizedBox(height: 30),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => setState(() => _isEditing = false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}