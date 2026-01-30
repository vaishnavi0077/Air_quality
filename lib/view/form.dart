// lib/screens/health_profile_form.dart
import 'package:aqi/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Data model for health conditions
class HealthCondition {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  HealthCondition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

// Predefined list of conditions relevant to air quality
List<HealthCondition> healthConditions = [
  HealthCondition(
    id: 'asthma',
    name: 'Asthma',
    description: 'Chronic inflammatory disease of the airways',
    icon: Icons.air,
  ),
  HealthCondition(
    id: 'copd',
    name: 'COPD',
    description: 'Chronic Obstructive Pulmonary Disease',
    icon: Icons.health_and_safety,
  ),
  HealthCondition(
    id: 'bronchitis',
    name: 'Chronic Bronchitis',
    description: 'Long-term inflammation of the bronchi',
    icon: Icons.sick,
  ),
  HealthCondition(
    id: 'allergic_rhinitis',
    name: 'Allergic Rhinitis',
    description: 'Hay fever or allergies',
    icon: Icons.bug_report,
  ),
  HealthCondition(
    id: 'heart_disease',
    name: 'Heart Disease',
    description: 'Cardiovascular conditions',
    icon: Icons.favorite,
  ),
  HealthCondition(
    id: 'none',
    name: 'None',
    description: 'No specific respiratory conditions',
    icon: Icons.check_circle,
  ),
];

class HealthProfileForm extends StatefulWidget {
  @override
  _HealthProfileFormState createState() => _HealthProfileFormState();

  // Firebase collection reference
  final CollectionReference users =
      FirebaseFirestore.instance.collection('users');
}

class _HealthProfileFormState extends State<HealthProfileForm>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  String? _selectedCondition;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? _selectedGender;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  bool get _areAllFieldsFilled {
    if (_currentStep == 0) {
      return _nameController.text.isNotEmpty &&
          _ageController.text.isNotEmpty &&
          _selectedGender != null;
    } else if (_currentStep == 1) {
      return _selectedCondition != null;
    } else if (_currentStep == 2) {
      return _nameController.text.isNotEmpty &&
          _ageController.text.isNotEmpty &&
          _selectedGender != null &&
          _selectedCondition != null;
    }
    return false;
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive || isCompleted
                            ? AppColors.primary
                            : AppColors.background,
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textSecondary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? Icon(Icons.check,
                                size: 16, color: AppColors.textOnPrimary)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? AppColors.textOnPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (index < 2)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppColors.primary
                                : AppColors.textSecondary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ['Personal', 'Health', 'Review'][index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _currentStep == 0
          ? _buildStep1()
          : _currentStep == 1
              ? _buildStep2()
              : _buildStep3(),
    );
  }

  // Step 1: Personal Info
  Widget _buildStep1() {
    return Container(
      key: const ValueKey(0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.person_outline,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          Text(
            'Tell us about yourself',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll use this information to personalize your experience',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              prefixIcon: Icon(Icons.person, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide:
                    BorderSide(color: AppColors.primary.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: AppColors.background,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Age',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              prefixIcon: Icon(Icons.cake, color: AppColors.primary),
              suffixText: 'years',
              suffixStyle: TextStyle(color: AppColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide:
                    BorderSide(color: AppColors.primary.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: AppColors.background,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gender',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildGenderChip('Male', Icons.male),
                  _buildGenderChip('Female', Icons.female),
                  _buildGenderChip('Other', Icons.transgender),
                  _buildGenderChip('Prefer not to say', Icons.remove_circle_outline),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String label, IconData icon) {
    final isSelected = _selectedGender == label.toLowerCase();

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 18,
              color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedGender = selected ? label.toLowerCase() : null;
        });
      },
      backgroundColor: AppColors.background,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.textOnPrimary : AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : AppColors.textSecondary.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }

  // Step 2: Health Profile
  Widget _buildStep2() {
    return Container(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.health_and_safety,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          Text(
            'Health Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select any conditions you have for personalized air quality alerts',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 30),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: healthConditions.map((condition) {
              final isSelected = _selectedCondition == condition.id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCondition = condition.id;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary.withOpacity(0.2),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          condition.icon,
                          size: 24,
                          color: isSelected
                              ? AppColors.textOnPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        condition.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (isSelected && condition.id != 'none')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Step 3: Review
  Widget _buildStep3() {
    return Container(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          Text(
            'Review Your Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please confirm your information below',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 30),
          Column(
            children: [
              _buildReviewCard(
                icon: Icons.person,
                title: 'Personal Information',
                items: [
                  'Name: ${_nameController.text}',
                  'Age: ${_ageController.text} years',
                  'Gender: ${_getGenderDisplay(_selectedGender)}',
                ],
              ),
              const SizedBox(height: 16),
              _buildReviewCard(
                icon: Icons.health_and_safety,
                title: 'Health Profile',
                items: [
                  'Condition: ${_getConditionDisplay(_selectedCondition)}',
                  if (_selectedCondition != null && _selectedCondition != 'none')
                    'Personalized alerts: Enabled',
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(
      {required IconData icon,
      required String title,
      required List<String> items}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  item,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )),
        ],
      ),
    );
  }

  String _getGenderDisplay(String? gender) {
    switch (gender) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      case 'prefer not to say':
        return 'Prefer not to say';
      default:
        return 'Not specified';
    }
  }

  String _getConditionDisplay(String? conditionId) {
    if (conditionId == null) return 'Not specified';
    final condition = healthConditions.firstWhere(
      (c) => c.id == conditionId,
      orElse: () => HealthCondition(
        id: '',
        name: 'None',
        description: '',
        icon: Icons.check_circle,
      ),
    );
    return condition.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Health Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildStepIndicator(),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildStepContent(),
                  ),
                ),
                const SizedBox(height: 20),
                _buildBottomNavigation(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: index == _currentStep ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index == _currentStep
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _areAllFieldsFilled
                  ? _currentStep == 2
                      ? _saveProfileData
                      : () {
                          setState(() => _currentStep++);
                        }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _currentStep == 2 ? Icons.check_circle : Icons.arrow_forward,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _currentStep == 2 ? 'COMPLETE SETUP' : 'CONTINUE',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_currentStep > 0)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => setState(() => _currentStep--),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back, size: 18),
                    SizedBox(width: 8),
                    Text('BACK'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Firestore save
  void _saveProfileData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final userProfile = {
    'name': _nameController.text.trim(),
    'age': int.tryParse(_ageController.text.trim()) ?? 0,
    'gender': _selectedGender,
    'healthCondition': _selectedCondition,
    'createdAt': FieldValue.serverTimestamp(),
  };

  try {
    // Save under UID instead of random doc
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(userProfile, SetOptions(merge: true)); // merge:true avoids overwriting

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved successfully!')),
    );

    Navigator.of(context).pushReplacementNamed('/dashboard');
  } catch (e) {
    print('Error saving profile: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save profile: $e')),
    );
  }
}

}
