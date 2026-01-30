//This ensures your app always has the latest location ready for the ML model.


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

/// Service to handle user location updates
class LocationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Request location permission
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Update the current user's location in Firestore
  Future<void> updateUserLocation() async {
    final user = _auth.currentUser;
    if (user == null) return;

    bool hasPermission = await requestPermission();
    if (!hasPermission) return;

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('location')
        .doc('current')
        .set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get current location snapshot (optional)
  Stream<DocumentSnapshot> getCurrentLocationStream() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('location')
        .doc('current')
        .snapshots();
  }
}
