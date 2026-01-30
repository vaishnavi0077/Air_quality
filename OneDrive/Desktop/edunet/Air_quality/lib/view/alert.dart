import 'package:flutter/material.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Alerts'),
        backgroundColor: Color(0xFFFF9800),
      ),
      body: Center(
        child: Text(
          'Your Alerts Content Here',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}