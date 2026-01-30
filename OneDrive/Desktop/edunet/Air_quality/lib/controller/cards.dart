import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InitializeFirestoreButton extends StatelessWidget {
  const InitializeFirestoreButton({super.key});

  Future<void> _initializeHealthCards() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference healthCardsRef = firestore.collection('health_cards');

    // List of cards matching your previous design
    List<Map<String, dynamic>> defaultCards = [
      {
        'title': 'AQI Basics',
        'subtitle': 'Understanding Air Quality',
        'icon': 'air',
        'color': '#4CAF50',
        'description': 'AQI measures air pollution levels. Lower is better.',
        'value': '0-50',
        'unit': 'Good Range',
        'animation': 'bubbles',
        'order': 1 // For sorting
      },
      {
        'title': 'Health Impact',
        'subtitle': 'How AQI affects you',
        'icon': 'favorite',
        'color': '#FF5252',
        'description': 'High AQI can cause breathing issues and fatigue.',
        'value': '>150',
        'unit': 'Unhealthy',
        'animation': 'heartbeat',
        'order': 2
      },
      // ... Add the other 3 card objects here
    ];

    // Use a batch write for efficiency
    WriteBatch batch = firestore.batch();
    for (var card in defaultCards) {
      // This creates a new document with a unique auto-ID
      DocumentReference newDocRef = healthCardsRef.doc();
      batch.set(newDocRef, card);
    }

    try {
      await batch.commit();
      print('Successfully initialized health_cards collection');
    } catch (e) {
      print('Error writing batch: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _initializeHealthCards,
      child: const Text('Initialize Firebase Cards'),
    );
  }
}