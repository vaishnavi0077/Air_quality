import 'package:aqi/view/aqi_history.dart';
import 'package:flutter/material.dart';


class AqiInputScreen extends StatefulWidget {
  final String userId; // pass logged-in user ID here

  const AqiInputScreen({super.key, required this.userId});

  @override
  State<AqiInputScreen> createState() => _AqiInputScreenState();
}

class _AqiInputScreenState extends State<AqiInputScreen> {
  final TextEditingController _aqiController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();

  final AqiService _aqiService = AqiService();

  bool _isSaving = false;

  void _saveData() async {
    final aqiText = _aqiController.text.trim();
    final condition = _conditionController.text.trim();

    if (aqiText.isEmpty || condition.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    int? aqi = int.tryParse(aqiText);
    if (aqi == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AQI must be a number')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _aqiService.saveAqiData(
        userId: widget.userId,
        aqi: aqi,
        condition: condition,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data saved successfully!')),
      );

      // Clear inputs
      _aqiController.clear();
      _conditionController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Save AQI Data')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _aqiController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'AQI Value',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _conditionController,
              decoration: const InputDecoration(
                labelText: 'Condition (Good, Moderate, etc.)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            _isSaving
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveData,
                    child: const Text('Save AQI Data'),
                  ),
          ],
        ),
      ),
    );
  }
}
