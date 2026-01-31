import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';

// ---------------- DASHBOARD SCREEN ----------------
class AqiDashboardScreen extends StatefulWidget {
  const AqiDashboardScreen({super.key});

  @override
  _AqiDashboardScreenState createState() => _AqiDashboardScreenState();
}

class _AqiDashboardScreenState extends State<AqiDashboardScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> healthCards = [];
  List<Map<String, dynamic>> aqiMetrics = [];
  List<Map<String, dynamic>> recommendations = [];
  List<Map<String, dynamic>> dosDonts = [];
  List<Map<String, dynamic>> news = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _initializeAndFetchData();
  }

  Future<void> _initializeAndFetchData() async {
    await _initializeCollectionsIfNotExists();
    await _fetchAllData();
    setState(() {
      _loading = false;
    });
    _animationController.forward();
  }

  Future<void> _initializeCollectionsIfNotExists() async {
    // Health Cards
    CollectionReference healthRef = _firestore.collection('health_cards');
    var healthSnapshot = await healthRef.limit(1).get();
    if (healthSnapshot.docs.isEmpty) {
      List<Map<String, dynamic>> defaultCards = [
        {'title': 'AQI Basics','subtitle': 'Understanding Air Quality','icon': 'air','color': '#4CAF50','description': 'AQI measures air pollution levels. Lower is better.','value': '0-50','unit': 'Good Range','animation': 'bubbles','order': 1},
        {'title': 'Health Impact','subtitle': 'How AQI affects you','icon': 'favorite','color': '#FF5252','description': 'High AQI can cause breathing issues and fatigue.','value': '>150','unit': 'Unhealthy','animation': 'heartbeat','order': 2},
        {'title': 'Air Pollution','subtitle': 'Know the pollutants','icon': 'cloud','color': '#2196F3','description': 'PM2.5, PM10, CO, NO2 affect health.','value': 'Varies','unit': 'µg/m³','animation': 'cloudy','order': 3},
        {'title': 'Protect Yourself','subtitle': 'Tips & Precautions','icon': 'masks','color': '#FF9800','description': 'Use masks, purifiers, and avoid outdoors during high AQI.','value': 'N/A','unit': '','animation': 'mask','order': 4},
        {'title': 'Air Quality Index','subtitle': 'Realtime updates','icon': 'update','color': '#9C27B0','description': 'Track AQI in your area in real-time.','value': 'N/A','unit': '','animation': 'update','order': 5},
      ];
      WriteBatch batch = _firestore.batch();
      for (var card in defaultCards) batch.set(healthRef.doc(), card);
      await batch.commit();
    }

    // AQI Metrics
    CollectionReference metricsRef = _firestore.collection('aqi_metrics');
    var metricsSnapshot = await metricsRef.limit(1).get();
    if (metricsSnapshot.docs.isEmpty) {
      List<Map<String, dynamic>> defaultMetrics = [
        {'label': 'PM2.5','value': 42,'unit': 'µg/m³','order': 1},
        {'label': 'PM10','value': 55,'unit': 'µg/m³','order': 2},
        {'label': 'CO','value': 0.8,'unit': 'ppm','order': 3},
        {'label': 'NO2','value': 20,'unit': 'ppb','order': 4},
        {'label': 'Humidity','value': 65,'unit': '%','order': 5},
        {'label': 'Wind Speed','value': 5,'unit': 'km/h','order': 6},
      ];
      WriteBatch batch = _firestore.batch();
      for (var m in defaultMetrics) batch.set(metricsRef.doc(), m);
      await batch.commit();
    }

    // Recommendations
    CollectionReference recRef = _firestore.collection('recommendations');
    var recSnapshot = await recRef.limit(1).get();
    if (recSnapshot.docs.isEmpty) {
      List<Map<String, dynamic>> recs = [
        {'title': 'Reduce Outdoor Activity','description': 'Avoid long exposure during high AQI.','minAqi': 100},
        {'title': 'Use Air Purifier','description': 'Keep indoor air clean during high pollution.','minAqi': 150},
      ];
      WriteBatch batch = _firestore.batch();
      for (var r in recs) batch.set(recRef.doc(), r);
      await batch.commit();
    }

    // Dos & Don'ts
    CollectionReference ddRef = _firestore.collection('dos_donts');
    var ddSnapshot = await ddRef.limit(1).get();
    if (ddSnapshot.docs.isEmpty) {
      List<Map<String, dynamic>> ddList = [
        {'type': 'do','text': 'Wear N95 mask outdoors','minAqi': 120},
        {'type': 'do','text': 'Keep windows closed during high AQI','minAqi': 100},
        {'type': 'dont','text': 'Avoid morning walks','minAqi': 120},
        {'type': 'dont','text': 'Do not burn waste at home','minAqi': 150},
      ];
      WriteBatch batch = _firestore.batch();
      for (var item in ddList) batch.set(ddRef.doc(), item);
      await batch.commit();
    }

    // News
    CollectionReference newsRef = _firestore.collection('news');
    var newsSnapshot = await newsRef.limit(1).get();
    if (newsSnapshot.docs.isEmpty) {
      List<Map<String, dynamic>> newsList = [
        {'title': 'AQI Hits 200 in Delhi','description': 'Air pollution reaches hazardous levels.','date': Timestamp.now()},
        {'title': 'Tips to Reduce Indoor Pollution','description': 'How to protect yourself from smog.','date': Timestamp.now()},
      ];
      WriteBatch batch = _firestore.batch();
      for (var n in newsList) batch.set(newsRef.doc(), n);
      await batch.commit();
    }
  }

  Future<void> _fetchAllData() async {
    var hcSnapshot = await _firestore.collection('health_cards').orderBy('order').get();
    healthCards = hcSnapshot.docs.map((e) => e.data() as Map<String, dynamic>).toList();

    var mSnapshot = await _firestore.collection('aqi_metrics').orderBy('order').get();
    aqiMetrics = mSnapshot.docs.map((e) => e.data() as Map<String, dynamic>).toList();

    var rSnapshot = await _firestore.collection('recommendations').get();
    recommendations = rSnapshot.docs.map((e) => e.data() as Map<String, dynamic>).toList();

    var ddSnapshot = await _firestore.collection('dos_donts').get();
    dosDonts = ddSnapshot.docs.map((e) => e.data() as Map<String, dynamic>).toList();

    var nSnapshot = await _firestore.collection('news').orderBy('date', descending: true).get();
    news = nSnapshot.docs.map((e) => e.data() as Map<String, dynamic>).toList();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color parseColor(String hex) {
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Widget _buildHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Air Quality Dashboard',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[800]),
          ),
          const SizedBox(height: 4),
          Text(
            'Realtime AQI & Health Insights',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ],
      );

  Widget _buildSectionHeader(String title, IconData icon, Color color) => Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      );

  Widget _buildPollutantCard(Map<String, dynamic> metric, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[100]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(metric['label'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${metric['value'] ?? '-'} ${metric['unit'] ?? ''}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> r) => Card(
        color: Colors.green[50],
        child: ListTile(
          leading: const Icon(Icons.lightbulb, color: Colors.green),
          title: Text(r['title'] ?? ''),
          subtitle: Text(r['description'] ?? ''),
        ),
      );

  Widget _buildDosDontsCard(Map<String, dynamic> dd) => Card(
        color: dd['type'] == 'do' ? Colors.blue[50] : Colors.red[50],
        child: ListTile(
          leading: Icon(dd['type'] == 'do' ? Icons.check_circle : Icons.cancel,
              color: dd['type'] == 'do' ? Colors.blue : Colors.red),
          title: Text(dd['text'] ?? ''),
        ),
      );

  Widget _buildNewsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Air Quality News', Icons.article, Colors.orange),
          const SizedBox(height: 8),
          ...news.map((n) => Card(
                color: Colors.orange[50],
                child: ListTile(
                  title: Text(n['title'] ?? ''),
                  subtitle: Text(n['description'] ?? ''),
                  trailing: Text(DateFormat('dd MMM').format((n['date'] as Timestamp).toDate())),
                ),
              )),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitFadingFour(color: Theme.of(context).primaryColor, size: 50.0),
              const SizedBox(height: 20),
              Text('Analyzing Air Quality...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.waves, color: Colors.blue[800]),
            const SizedBox(width: 10),
            const Text('AirSafe Monitor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        shadowColor: Colors.blue[50]!.withOpacity(0.5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(15))),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Health Insights', Icons.insights, Colors.green),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: healthCards.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => HealthCardWidget(cardData: healthCards[index]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Pollutant Levels', Icons.poll, Colors.blue),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: aqiMetrics.length,
                    itemBuilder: (context, index) {
                      var metric = aqiMetrics[index];
                      return _buildPollutantCard(metric, index);
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Smart Suggestions', Icons.lightbulb, Colors.amber),
                  const SizedBox(height: 8),
                  ...recommendations.map((r) => _buildRecommendationCard(r)).toList(),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Safety Guide', Icons.safety_check, Colors.purple),
                  const SizedBox(height: 8),
                  ...dosDonts.map((dd) => _buildDosDontsCard(dd)).toList(),
                  const SizedBox(height: 20),
                  _buildNewsSection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------- HEALTH CARD WIDGET -----------------
class HealthCardWidget extends StatefulWidget {
  final Map<String, dynamic> cardData;
  const HealthCardWidget({super.key, required this.cardData});

  @override
  State<HealthCardWidget> createState() => _HealthCardWidgetState();
}

class _HealthCardWidgetState extends State<HealthCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovering = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _bubbleController;
  late Animation<double> _bubbleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _bubbleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bubbleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  void _handleHover(bool hovering) {
    setState(() {
      _isHovering = hovering;
      if (hovering) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  Color _getCardColor() {
    try {
      if (widget.cardData['color'] is String) {
        final colorStr = widget.cardData['color'] as String;
        if (colorStr.startsWith('#')) {
          return Color(int.parse(colorStr.substring(1, 7), radix: 16) + 0xFF000000);
        }
      }
    } catch (e) {}
    final icon = widget.cardData['icon'] ?? 'air';
    final colorMap = {
      'air': Colors.green,
      'favorite': Colors.red,
      'cloud': Colors.blue,
      'masks': Colors.orange,
      'update': Colors.purple,
    };
    return colorMap[icon]?.withOpacity(0.9) ?? Colors.blue.withOpacity(0.9);
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = _getCardColor();
    final textColor = cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTap: () {
          _controller.forward().then((_) => _controller.reverse());
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 200.0,
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cardColor.withOpacity(0.9),
                      cardColor.withOpacity(0.7),
                      cardColor.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: cardColor.withOpacity(0.4),
                      blurRadius: _isHovering ? 25.0 : 15.0,
                      spreadRadius: _isHovering ? 2.0 : 1.0,
                      offset: Offset(0, _isHovering ? 10.0 : 5.0),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.cardData['title'] ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(widget.cardData['subtitle'] ?? '', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
