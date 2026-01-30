//This will store every AQI prediction for a user, so history and trends are ready.


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to handle AQI predictions storage
class AqiService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save AQI prediction for the user
  Future<void> saveAqiPrediction({
    required int aqi,
    required String category,
    required double latitude,
    required double longitude,
    required String modelVersion,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('aqiHistory')
        .add({
      'aqi': aqi,
      'category': category,
      'location': {'lat': latitude, 'lng': longitude},
      'modelVersion': modelVersion,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream user AQI history for graphs or display
  Stream<List<Map<String, dynamic>>> getAqiHistory() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('aqiHistory')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }

  Future<void> saveAqiData({required String userId, required int aqi, required String condition}) async {}
}
