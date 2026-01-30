import 'package:flutter/material.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping'),
        backgroundColor: Color(0xFF00BCD4),
      ),
      body: Center(
        child: Text(
          'Your Shopping Content Here',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}