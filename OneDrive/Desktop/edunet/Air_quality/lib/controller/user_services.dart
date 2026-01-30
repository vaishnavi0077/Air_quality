// lib/services/user_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Get user data from Firestore
  static Future<Map<String, dynamic>> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()!;
      }
      return {};
    } catch (e) {
      print('Error getting user data: $e');
      return {};
    }
  }

  // Stream user data for real-time updates
  static Stream<Map<String, dynamic>> streamUserData(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data() ?? {});
  }

  // Update user profile
  static Future<void> updateUserProfile({
    required String uid,
    required String name,
    String? phone,
    String? location,
  }) async {
    try {
      final updateData = {
        'name': name,
        'phone': phone ?? '',
        'location': location ?? '',
        'updatedAt': DateTime.now(),
      };

      // Update Firestore
      await _firestore.collection('users').doc(uid).update(updateData);

      // Update Firebase Auth display name
      final user = _auth.currentUser;
      if (user != null && name != user.displayName) {
        await user.updateDisplayName(name);
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }
}