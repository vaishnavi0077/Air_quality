import 'package:aqi/theme/app_colors.dart';
import 'package:aqi/view/health.dart';
import 'package:aqi/view/login.dart';
import 'package:aqi/view/navbar.dart';
import 'package:aqi/view/profile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

// MOVE AQIDataPoint CLASS OUTSIDE THE STATE CLASS
class AQIDataPoint {
  final DateTime timestamp;
  final int aqi;
  final String city;
  
  AQIDataPoint({
    required this.timestamp,
    required this.aqi,
    required this.city,
  });
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // New AQI Dashboard Variables
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _cloudAnimation;
  String _selectedCity = 'Pune';
  int _selectedDay = 0;
  final PageController _newsPageController = PageController(viewportFraction: 0.85);
  int _currentNewsIndex = 0;
  
  // Graph Variables
  bool _showGraph = false;
  List<AQIDataPoint> _graphData = [];
  List<AQIDataPoint> _hourlyData = [];
  List<AQIDataPoint> _dailyData = [];
  String _selectedGraphType = 'hourly'; // 'hourly', 'daily'
  
  // Real News Variables
  List<Map<String, dynamic>> _realNews = [];
  bool _isLoadingNews = false;
  String _newsApiKey = 'ed45356195d64188b63f907dcdcfae70'; // Replace with your actual API key
  
  final Map<int, Map<String, dynamic>> _dayData = {
    0: {'aqi': 163, 'status': 'Unhealthy', 'trend': '↑2', 'trendIcon': Icons.arrow_upward},
    -1: {'aqi': 142, 'status': 'Unhealthy for SG', 'trend': '→', 'trendIcon': Icons.remove},
    1: {'aqi': 158, 'status': 'Unhealthy', 'trend': '↓5', 'trendIcon': Icons.arrow_downward},
  };
  
  int get _currentAQI => _dayData[_selectedDay]?['aqi'] ?? 163;
  String get _currentStatus => _dayData[_selectedDay]?['status'] ?? 'Unhealthy';
  String get _currentTrend => _dayData[_selectedDay]?['trend'] ?? '→';
  IconData get _currentTrendIcon => _dayData[_selectedDay]?['trendIcon'] ?? Icons.remove;
  
  final Map<String, dynamic> _pollutants = {
    'PM2.5': {'value': 74, 'unit': 'µg/m³', 'trend': '↑'},
    'PM10': {'value': 89, 'unit': 'µg/m³', 'trend': '→'},
    'Primary': {'value': 'PM2.5', 'unit': '', 'trend': ''},
  };
  
  final Map<String, dynamic> _weather = {
    'temp': 27,
    'humidity': 39,
    'wind': 14,
    'condition': 'Sunny',
    'uv': 7,
  };

  @override
  void initState() {
    super.initState();
    
    // Initialize AQI Dashboard animations
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );
    
    _cloudAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    
    // Load initial data
    _loadGraphData();
    _fetchRealNews();
  }

  @override
  void dispose() {
    _controller.dispose();
    _newsPageController.dispose();
    super.dispose();
  }

  // Load Graph Data
  Future<void> _loadGraphData() async {
    try {
      // Load historical data from Firestore
      final snapshot = await _firestore
          .collection('aqi_data')
          .where('city', isEqualTo: _selectedCity)
          .orderBy('timestamp', descending: true)
          .limit(48) // Last 48 data points
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        List<AQIDataPoint> dataPoints = [];
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final timestamp = (data['timestamp'] as Timestamp).toDate();
          final aqi = data['aqi'] as int;
          
          dataPoints.add(AQIDataPoint(
            timestamp: timestamp,
            aqi: aqi,
            city: _selectedCity,
          ));
        }
        
        // Sort by timestamp (oldest to newest)
        dataPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        setState(() {
          _graphData = dataPoints;
          _processHourlyData();
          _processDailyData();
        });
      } else {
        _generateSampleData();
      }
    } catch (e) {
      print('Error loading graph data: $e');
      _generateSampleData();
    }
  }

  void _processHourlyData() {
    if (_graphData.isEmpty) return;
    
    List<AQIDataPoint> hourly = [];
    
    // Group by hour
    Map<String, List<int>> hourlyMap = {};
    
    for (var point in _graphData) {
      String hourKey = DateFormat('MM/dd HH:00').format(point.timestamp);
      if (!hourlyMap.containsKey(hourKey)) {
        hourlyMap[hourKey] = [];
      }
      hourlyMap[hourKey]!.add(point.aqi);
    }
    
    for (var entry in hourlyMap.entries) {
      final avgAQI = (entry.value.reduce((a, b) => a + b) / entry.value.length).round();
      hourly.add(AQIDataPoint(
        timestamp: DateFormat('MM/dd HH:00').parse(entry.key),
        aqi: avgAQI,
        city: _selectedCity,
      ));
    }
    
    setState(() {
      _hourlyData = hourly;
    });
  }

  void _processDailyData() {
    if (_graphData.isEmpty) return;
    
    List<AQIDataPoint> daily = [];
    
    // Group by day
    Map<String, List<int>> dailyMap = {};
    
    for (var point in _graphData) {
      String dayKey = DateFormat('MM/dd').format(point.timestamp);
      if (!dailyMap.containsKey(dayKey)) {
        dailyMap[dayKey] = [];
      }
      dailyMap[dayKey]!.add(point.aqi);
    }
    
    for (var entry in dailyMap.entries) {
      final avgAQI = (entry.value.reduce((a, b) => a + b) / entry.value.length).round();
      daily.add(AQIDataPoint(
        timestamp: DateFormat('MM/dd').parse(entry.key),
        aqi: avgAQI,
        city: _selectedCity,
      ));
    }
    
    setState(() {
      _dailyData = daily;
    });
  }

  void _generateSampleData() {
    List<AQIDataPoint> sampleData = [];
    final now = DateTime.now();
    
    // Generate hourly data for last 24 hours
    for (int i = 0; i < 24; i++) {
      final time = now.subtract(Duration(hours: 23 - i));
      final aqi = 120 + Random().nextInt(80); // Random AQI between 120-200
      
      sampleData.add(AQIDataPoint(
        timestamp: time,
        aqi: aqi,
        city: _selectedCity,
      ));
    }
    
    setState(() {
      _graphData = sampleData;
      _hourlyData = sampleData;
      _dailyData = sampleData;
    });
  }

  // Handle navigation item taps
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _showGraph = false; // Close graph if open
    });
  }

  // Handle drawer item selection
  void _onDrawerItemSelected(int index) {
    _scaffoldKey.currentState?.closeEndDrawer();
    if (index == 4) { // Profile option
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      );
    } else if (index == 5) { // Logout option
      _handleLogout();
    } else {
      setState(() {
        _selectedIndex = index;
        _showGraph = false; // Close graph if open
      });
    }
  }

  // Method to get screen content based on selection
  Widget _getScreenContent() {
    if (_showGraph) {
      return _buildGraphView();
    }
    
    switch (_selectedIndex) {
      case 0: // Home - Use new enhanced AQI dashboard
        return _buildNewHomeContent();
      case 1: // Shopping
        return _buildShoppingContent();
      case 2: // Health
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: AqiDashboardScreen()                                           //HealthScreen(),
        );
      case 3: // Alerts
        return _buildAlertsContent();
      default:
        return _buildNewHomeContent();
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // AQI Dashboard helper methods from new code
  Color get _aqiColor {
    final aqi = _currentAQI;
    if (aqi <= 50) return const Color(0xFF00E400);
    if (aqi <= 100) return const Color(0xFFFFFF00);
    if (aqi <= 150) return const Color(0xFFFF7E00);
    if (aqi <= 200) return const Color(0xFFFF0000);
    if (aqi <= 300) return const Color(0xFF99004C);
    return const Color(0xFF7E0023);
  }
  
  String get _leftDayLabel {
    if (_selectedDay == 0) return 'Yesterday';
    return '${_selectedDay.abs()} days ago';
  }
  
  String get _rightDayLabel {
    if (_selectedDay == 0) return 'Tomorrow';
    return 'In $_selectedDay days';
  }
  
  String get _currentDayLabel {
    if (_selectedDay == 0) return 'TODAY';
    if (_selectedDay < 0) return '${_selectedDay.abs()} DAYS AGO';
    return 'IN $_selectedDay DAYS';
  }
  
  Color get _trendColor {
    if (_currentTrend.contains('↑')) return Colors.red;
    if (_currentTrend.contains('↓')) return Colors.green;
    return Colors.orange;
  }
  
  String get _trendText {
    if (_currentTrend.contains('↑')) return 'Worsening';
    if (_currentTrend.contains('↓')) return 'Improving';
    return 'Stable';
  }

  // News API Methods
  Future<void> _fetchRealNews() async {
    if (_isLoadingNews) return;
    
    setState(() {
      _isLoadingNews = true;
    });
    
    try {
      const apiKey = 'ed45356195d64188b63f907dcdcfae70';
      
      final response = await http.get(
        Uri.parse(
          'https://newsapi.org/v2/everything?'
          'q=air quality OR air pollution OR AQI OR "air quality index" OR pollution OR environment&'
          'language=en&'
          'sortBy=publishedAt&'
          'pageSize=10&'
          'apiKey=$apiKey'
        ),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'ok') {
          final articles = data['articles'] as List;
          
          final filteredNews = articles
              .where((article) => 
                  article['title'] != null && 
                  article['title'] != '[Removed]' &&
                  article['description'] != null)
              .map((article) {
            return {
              'title': article['title'] ?? 'No Title',
              'description': article['description'] ?? '',
              'content': article['content'] ?? '',
              'url': article['url'] ?? '',
              'imageUrl': article['urlToImage'] ?? '',
              'source': article['source']['name'] ?? 'Unknown Source',
              'publishedAt': article['publishedAt'] ?? DateTime.now().toIso8601String(),
              'timestamp': DateTime.now(),
              'category': _getNewsCategory(article['title'] ?? ''),
            };
          }).toList();
          
          setState(() {
            _realNews = filteredNews;
            _isLoadingNews = false;
          });
          
          await _saveNewsToFirestore(filteredNews);
          
          print('✅ Fetched ${_realNews.length} real news articles');
        }
      } else {
        print('❌ News API Error: ${response.statusCode}');
        setState(() {
          _isLoadingNews = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching news: $e');
      setState(() {
        _isLoadingNews = false;
      });
      
      await _loadNewsFromFirestore();
    }
  }
  
  String _getNewsCategory(String title) {
    final lowerTitle = title.toLowerCase();
    
    if (lowerTitle.contains('delhi') || lowerTitle.contains('mumbai') || 
        lowerTitle.contains('pune') || lowerTitle.contains('india')) {
      return 'National';
    } else if (lowerTitle.contains('health') || lowerTitle.contains('respiratory') || 
               lowerTitle.contains('medical') || lowerTitle.contains('cancer')) {
      return 'Health';
    } else if (lowerTitle.contains('study') || lowerTitle.contains('research') || 
               lowerTitle.contains('scientists')) {
      return 'Research';
    } else if (lowerTitle.contains('government') || lowerTitle.contains('policy') || 
               lowerTitle.contains('regulation')) {
      return 'Policy';
    } else if (lowerTitle.contains('technology') || lowerTitle.contains('app') || 
               lowerTitle.contains('device') || lowerTitle.contains('purifier')) {
      return 'Technology';
    } else if (lowerTitle.contains('alert') || lowerTitle.contains('warning') || 
               lowerTitle.contains('emergency')) {
      return 'Alert';
    } else {
      return 'Environment';
    }
  }
  
  Future<void> _saveNewsToFirestore(List<Map<String, dynamic>> news) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Clear old news
      final allNews = await firestore
          .collection('news_cache')
          .orderBy('timestamp', descending: true)
          .get();
      
      if (allNews.docs.length > 20) {
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        
        for (var doc in allNews.docs) {
          final data = doc.data();
          final timestamp = data['timestamp'];
          
          if (timestamp is Timestamp) {
            final newsDate = timestamp.toDate();
            if (newsDate.isBefore(weekAgo)) {
              await doc.reference.delete();
            }
          }
        }
      }
      
      // Save new news
      for (var newsItem in news) {
        await firestore.collection('news_cache').add(newsItem);
      }
      
      print('✅ News saved to Firestore');
    } catch (e) {
      print('Error saving to Firestore: $e');
    }
  }
  
  Future<void> _loadNewsFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('news_cache')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _realNews = snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
          _isLoadingNews = false;
        });
        print('✅ Loaded ${_realNews.length} news from Firestore cache');
      }
    } catch (e) {
      print('Error loading from Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _showGraph ? 'AQI Graph - $_selectedCity' : _getAppBarTitle(),
          style: TextStyle(
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 2,
        centerTitle: true,
        leading: _showGraph
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.textOnPrimary),
                onPressed: () {
                  setState(() {
                    _showGraph = false;
                  });
                },
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline, color: AppColors.textOnPrimary),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(15),
            bottomRight: Radius.circular(15),
          ),
        ),
      ),

      endDrawer: _buildDrawer(),

      body: _getScreenContent(),
      bottomNavigationBar: _showGraph ? null : WavyFloatingNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        unselectedColor: AppColors.textSecondary.withOpacity(0.7),
        elevation: 8.0,
        items: [
          NavItem(
            label: 'Home',
            icon: Icons.home_outlined,
            activeIcon: Icons.home_filled,
            bubbleColor: AppColors.primary,
          ),
          NavItem(
            label: 'Shopping',
            icon: Icons.shopping_cart_outlined,
            activeIcon: Icons.shopping_cart,
            bubbleColor: Colors.purple,
          ),
          NavItem(
            label: 'Health',
            icon: Icons.health_and_safety_outlined,
            activeIcon: Icons.health_and_safety,
            bubbleColor: Colors.green,
          ),
          NavItem(
            label: 'Alerts',
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications,
            bubbleColor: Colors.orange,
          ),
        ],
      ),
      
      // Refresh News Floating Button (only on Home tab)
      floatingActionButton: _selectedIndex == 0 && !_showGraph ? FloatingActionButton(
        backgroundColor: _aqiColor,
        foregroundColor: Colors.white,
        onPressed: _fetchRealNews,
        child: _isLoadingNews
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : const Icon(Icons.refresh),
      ) : null,
    );
  }

  // ============ GRAPH VIEW ============
  Widget _buildGraphView() {
    final currentData = _selectedGraphType == 'hourly' ? _hourlyData : _dailyData;
    
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Current AQI Info
          Container(
            padding: EdgeInsets.all(20),
            color: _aqiColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current AQI',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '$_currentAQI',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _aqiColor,
                      ),
                    ),
                    Text(
                      _currentStatus,
                      style: TextStyle(
                        fontSize: 16,
                        color: _aqiColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        setState(() {
                          _selectedGraphType = value;
                        });
                      },
                      icon: Icon(Icons.filter_list, color: _aqiColor),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'hourly',
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: _aqiColor),
                              SizedBox(width: 8),
                              Text('Hourly Trend'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'daily',
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: _aqiColor),
                              SizedBox(width: 8),
                              Text('Daily Trend'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(_currentTrendIcon, color: _trendColor, size: 24),
                        SizedBox(width: 4),
                        Text(
                          _currentTrend,
                          style: TextStyle(
                            fontSize: 20,
                            color: _trendColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _trendText,
                      style: TextStyle(
                        fontSize: 14,
                        color: _trendColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Graph
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: currentData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart, size: 60, color: Colors.grey[300]),
                          SizedBox(height: 16),
                          Text(
                            'No data available',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadGraphData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _aqiColor,
                            ),
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : SfCartesianChart(
                      backgroundColor: Colors.transparent,
                      primaryXAxis: DateTimeAxis(
                        dateFormat: _selectedGraphType == 'hourly' 
                            ? DateFormat('HH:mm')
                            : DateFormat('MM/dd'),
                        majorGridLines: MajorGridLines(width: 0),
                        edgeLabelPlacement: EdgeLabelPlacement.shift,
                        interval: _selectedGraphType == 'hourly' ? 3 : 1,
                        labelStyle: TextStyle(color: Colors.grey[600]),
                      ),
                      primaryYAxis: NumericAxis(
                        minimum: 0,
                        maximum: 300,
                        interval: 50,
                        axisLine: AxisLine(width: 0),
                        majorTickLines: MajorTickLines(size: 0),
                        labelStyle: TextStyle(color: Colors.grey[600]),
                        labelFormat: '{value}',
                      ),
                      series: <CartesianSeries>[
  AreaSeries<AQIDataPoint, DateTime>(
    dataSource: currentData,
    xValueMapper: (AQIDataPoint data, _) => data.timestamp,
    yValueMapper: (AQIDataPoint data, _) => data.aqi,
    name: 'AQI',
    color: _aqiColor.withOpacity(0.3),
    borderColor: _aqiColor,
    borderWidth: 2,
    dataLabelSettings: DataLabelSettings(
      isVisible: false,
    ),
    markerSettings: MarkerSettings(
      isVisible: true,
      shape: DataMarkerType.circle,
      borderWidth: 2,
      borderColor: _aqiColor,
      color: Colors.white,
    ),
  ),
  LineSeries<AQIDataPoint, DateTime>(
    dataSource: currentData,
    xValueMapper: (AQIDataPoint data, _) => data.timestamp,
    yValueMapper: (AQIDataPoint data, _) => data.aqi,
    name: 'AQI Line',
    color: _aqiColor,
    width: 3,
    dataLabelSettings: DataLabelSettings(
      isVisible: false,
    ),
  ),
],
                      


                      tooltipBehavior: TooltipBehavior(
                        enable: true,
                        format: 'AQI: point.y',
                        color: _aqiColor,
                        textStyle: TextStyle(color: Colors.white),
                      ),
                    ),
            ),
          ),
          
          // AQI Color Scale
          Container(
            padding: EdgeInsets.all(20),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AQI Color Scale',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF00E400), // Good
                        Color(0xFFFFFF00), // Moderate
                        Color(0xFFFF7E00), // Unhealthy for SG
                        Color(0xFFFF0000), // Unhealthy
                        Color(0xFF99004C), // Very Unhealthy
                        Color(0xFF7E0023), // Hazardous
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: (_currentAQI / 500) * 100 - 1.5,
                        child: Container(
                          width: 3,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: _aqiColor,
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('0', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('50', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('100', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('150', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('200', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('300', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('500', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          
          // Data Points List
          if (currentData.isNotEmpty && currentData.length <= 10)
            Container(
              height: 150,
              padding: EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Data Points',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: currentData.length,
                      itemBuilder: (context, index) {
                        final data = currentData[index];
                        final time = _selectedGraphType == 'hourly'
                            ? DateFormat('HH:mm').format(data.timestamp)
                            : DateFormat('MM/dd').format(data.timestamp);
                        
                        return Container(
                          margin: EdgeInsets.only(right: 12),
                          padding: EdgeInsets.all(12),
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${data.aqi}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _getAQIColor(data.aqi),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _getAQIStatus(data.aqi),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _getAQIColor(data.aqi),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getAQIColor(int aqi) {
    if (aqi <= 50) return Color(0xFF00E400);
    if (aqi <= 100) return Color(0xFFFFFF00);
    if (aqi <= 150) return Color(0xFFFF7E00);
    if (aqi <= 200) return Color(0xFFFF0000);
    if (aqi <= 300) return Color(0xFF99004C);
    return Color(0xFF7E0023);
  }

  String _getAQIStatus(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for SG';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  // ============ NEW ENHANCED HOME CONTENT ============
  Widget _buildNewHomeContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // App Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.menu, size: 20),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButton<String>(
                        value: _selectedCity,
                        isExpanded: true,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                        underline: Container(),
                        items: [
                          'Pune',
                          'Mumbai',
                          'Delhi',
                          'Bangalore',
                          'Chennai',
                          'Kolkata',
                          'Hyderabad',
                        ].map((String city) {
                          return DropdownMenuItem<String>(
                            value: city,
                            child: Text(city),
                          );
                        }).toList(),
                        onChanged: (String? newValue) async {
                          if (newValue != null) {
                            setState(() {
                              _selectedCity = newValue;
                            });
                            // Reload graph data for the new city
                            await _loadGraphData();
                          }
                        },
                      ),
                      Text(
                        'Air Quality Index',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // View Graph Button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showGraph = true;
                    });
                    _loadGraphData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _aqiColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _aqiColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bar_chart, size: 16, color: _aqiColor),
                        const SizedBox(width: 6),
                        Text(
                          'View Graph',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _aqiColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Search Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey[500], size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _aqiColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.my_location, size: 16, color: Colors.white),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Glassy AQI Display Area
          Stack(
            children: [
              // Glassy Background Shade
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                height: 380,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _aqiColor.withOpacity(0.08),
                      _aqiColor.withOpacity(0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                ),
              ),
              
              // Cloud Animations
              _buildCloudBackground(),
              
              // Glassy AQI Display
              _buildGlassyAQIDisplay(),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Weather Info Cards
          _buildWeatherCards(),
          
          const SizedBox(height: 20),
          
          // Pollutant Row
          _buildPollutantRow(),
          
          const SizedBox(height: 20),
          
          // Precautions Section
          _buildPrecautionsSection(),
          
          const SizedBox(height: 24),
          
          // Real News Carousel
          _buildRealNewsCarousel(),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCloudBackground() {
    return AnimatedBuilder(
      animation: _cloudAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 380,
          child: Stack(
            children: [
              // Cloud 1
              Positioned(
                top: 40,
                left: 20 + sin(_cloudAnimation.value) * 15,
                child: Icon(
                  Icons.cloud,
                  size: 60,
                  color: Colors.white.withOpacity(0.25),
                ),
              ),
              
              // Cloud 2
              Positioned(
                top: 80,
                right: 30 + cos(_cloudAnimation.value * 1.5) * 20,
                child: Icon(
                  Icons.cloud,
                  size: 80,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              
              // Cloud 3
              Positioned(
                bottom: 100,
                left: 50 + sin(_cloudAnimation.value * 2) * 25,
                child: Icon(
                  Icons.cloud,
                  size: 50,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

 Widget _buildGlassyAQIDisplay() {
  return AnimatedBuilder(
    animation: _pulseAnimation,
    builder: (context, child) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.8),
              Colors.white.withOpacity(0.4),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 2.0),
          boxShadow: [
            BoxShadow(
              color: _aqiColor.withOpacity(0.4),
              blurRadius: 60,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              blurRadius: 30,
              spreadRadius: -10,
              offset: const Offset(-15, -15),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
                child: Column(
                  children: [
                    // Live Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _aqiColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _aqiColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE AQI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _aqiColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // DAY NAVIGATION ROW
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Arrow
                        _buildDayNavButton(
                          icon: Icons.arrow_back_ios,
                          label: _leftDayLabel,
                          isEnabled: _selectedDay > -2,
                          onPressed: () {
                            if (_selectedDay > -2) {
                              setState(() => _selectedDay--);
                            }
                          },
                        ),
                        
                        // Main AQI Digit
                        Expanded(
                          child: Column(
                            children: [
                              // Current Day Label
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _aqiColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _currentDayLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _aqiColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Main AQI Digit with Pulse
                              Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$_currentAQI',
                                        style: TextStyle(
                                          fontSize: 68,
                                          fontWeight: FontWeight.w900,
                                          color: _aqiColor,
                                          height: 0.9,
                                          shadows: [
                                            Shadow(
                                              color: _aqiColor.withOpacity(0.2),
                                              blurRadius: 20,
                                              offset: const Offset(0, 0),
                                            ),
                                            Shadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' US',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // AQI Status
                              Text(
                                _currentStatus.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _aqiColor,
                                  letterSpacing: 1,
                                ),
                              ),
                              
                              // Trend Indicator
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _trendColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _currentTrendIcon,
                                      size: 16,
                                      color: _trendColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _trendText,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _trendColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Right Arrow
                        _buildDayNavButton(
                          icon: Icons.arrow_forward_ios,
                          label: _rightDayLabel,
                          isEnabled: _selectedDay < 2,
                          onPressed: () {
                            if (_selectedDay < 2) {
                              setState(() => _selectedDay++);
                            }
                          },
                          isRight: true,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // AQI Color Scale
                    Container(
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00E400),
                            Color(0xFFFFFF00),
                            Color(0xFFFF7E00),
                            Color(0xFFFF0000),
                            Color(0xFF99004C),
                            Color(0xFF7E0023),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: (_currentAQI / 500) * 100 - 3,
                            child: Container(
                              width: 6,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: _aqiColor,
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Scale Labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('0', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text('50', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text('100', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text('150', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text('200', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text('300', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text('500', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Last Updated
                    Text(
                      'Updated: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Glass Shine Overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.transparent,
                    Colors.white.withOpacity(0.05),
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildDayNavButton({
    required IconData icon,
    required String label,
    required bool isEnabled,
    required VoidCallback onPressed,
    bool isRight = false,
  }) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isEnabled ? Colors.white : Colors.grey[100],
            shape: BoxShape.circle,
            boxShadow: isEnabled ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: IconButton(
            icon: Icon(icon, size: 20),
            color: isEnabled ? Colors.blue[700] : Colors.grey[400],
            onPressed: isEnabled ? onPressed : null,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isEnabled ? Colors.blue[700] : Colors.grey[400],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
  
  Widget _buildWeatherCards() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildWeatherCard('🌡️', '${_weather['temp']}°C', 'Temperature'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildWeatherCard('💧', '${_weather['humidity']}%', 'Humidity'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildWeatherCard('💨', '${_weather['wind']} km/h', 'Wind Speed'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildWeatherCard('☀️', 'UV ${_weather['uv']}', 'UV Index'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWeatherCard(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildPollutantRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Major Pollutants',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPollutantChip('PM2.5', '${_pollutants['PM2.5']!['value']}', _pollutants['PM2.5']!['unit'] as String),
              _buildPollutantChip('PM10', '${_pollutants['PM10']!['value']}', _pollutants['PM10']!['unit'] as String),
              _buildPollutantChip('Primary', _pollutants['Primary']!['value'] as String, ''),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildPollutantChip(String label, String value, String unit) {
    final trend = _pollutants[label]?['trend'] as String? ?? '';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _aqiColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _aqiColor.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              if (trend.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  trend,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: trend == '↑' ? Colors.red : 
                           trend == '↓' ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _aqiColor,
                  ),
                ),
                if (unit.isNotEmpty) TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPrecautionsSection() {
    final precautions = _currentAQI > 150 ? [
      {'icon': Icons.block, 'title': 'Avoid Outdoors', 'desc': 'Stay inside with windows closed'},
      {'icon': Icons.masks, 'title': 'Wear N95 Mask', 'desc': 'Use mask if going outside'},
      {'icon': Icons.air, 'title': 'Use Air Purifiers', 'desc': 'Run purifiers on high'},
      {'icon': Icons.local_hospital, 'title': 'Monitor Health', 'desc': 'Seek help if breathing worsens'},
    ] : _currentAQI > 100 ? [
      {'icon': Icons.warning, 'title': 'Limit Exercise', 'desc': 'Reduce outdoor activity'},
      {'icon': Icons.elderly, 'title': 'Protect Vulnerable', 'desc': 'Children & elderly stay indoors'},
      {'icon': Icons.home, 'title': 'Close Windows', 'desc': 'Keep indoor air clean'},
      {'icon': Icons.water_drop, 'title': 'Stay Hydrated', 'desc': 'Drink plenty of water'},
    ] : [
      {'icon': Icons.check_circle, 'title': 'Good Conditions', 'desc': 'Normal activities safe'},
      {'icon': Icons.park, 'title': 'Ideal for Exercise', 'desc': 'Perfect outdoor time'},
      {'icon': Icons.air, 'title': 'Fresh Air', 'desc': 'Good to ventilate home'},
      {'icon': Icons.health_and_safety, 'title': 'Low Risk', 'desc': 'Minimal health concerns'},
    ];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(Icons.health_and_safety, color: _aqiColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Health Precautions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          
          // Precautions Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: precautions.map((precaution) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _aqiColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        precaution['icon'] as IconData,
                        color: _aqiColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            precaution['title'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            precaution['desc'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 10),
          
          // View More button
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text(
                'View All Precautions →',
                style: TextStyle(
                  color: _aqiColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // REAL NEWS CAROUSEL FROM NEWSAPI
  Widget _buildRealNewsCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _aqiColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.newspaper, color: _aqiColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Air Quality News',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _isLoadingNews ? 'Fetching latest...' : 'Live from NewsAPI',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // News Count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _aqiColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_realNews.length} updates',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _aqiColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Real News Carousel
        SizedBox(
          height: 220,
          child: _isLoadingNews
              ? _buildLoadingNewsCards()
              : _realNews.isEmpty
                  ? _buildNoNewsCard()
                  : Stack(
                      children: [
                        // News Cards PageView
                        PageView.builder(
                          controller: _newsPageController,
                          itemCount: _realNews.length,
                          onPageChanged: (index) {
                            setState(() => _currentNewsIndex = index);
                          },
                          itemBuilder: (context, index) {
                            final news = _realNews[index];
                            return _buildRealNewsCard(news, index);
                          },
                        ),
                        
                        // Page Indicator
                        if (_realNews.length > 1)
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_realNews.length, (index) {
                                return Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentNewsIndex == index 
                                        ? _aqiColor 
                                        : Colors.grey[300],
                                  ),
                                );
                              }),
                            ),
                          ),
                      ],
                    ),
        ),
        
        // Refresh Button
        Padding(
          padding: const EdgeInsets.only(right: 20, top: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _fetchRealNews,
              style: TextButton.styleFrom(
                foregroundColor: _aqiColor,
              ),
              icon: Icon(
                _isLoadingNews ? Icons.hourglass_bottom : Icons.refresh,
                size: 16,
              ),
              label: Text(
                _isLoadingNews ? 'Fetching...' : 'Refresh News',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildRealNewsCard(Map<String, dynamic> news, int index) {
    final isCurrent = _currentNewsIndex == index;
    final hasImage = news['imageUrl'] != null && news['imageUrl'].toString().isNotEmpty;
    
    return GestureDetector(
      onTap: () {
        _showNewsDetail(news);
      },
      child: AnimatedScale(
        scale: isCurrent ? 1.0 : 0.95,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: isCurrent ? 10 : 15,
            vertical: isCurrent ? 0 : 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Background Image
                if (hasImage)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: news['imageUrl'].toString(),
                      fit: BoxFit.cover,
                      color: Colors.black.withOpacity(0.4),
                      colorBlendMode: BlendMode.darken,
                    ),
                  )
                else
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _aqiColor.withOpacity(0.3),
                            _aqiColor.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(hasImage ? 0.7 : 0.4),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Category Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          (news['category'] ?? 'ENVIRONMENT').toString().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Title
                      Text(
                        news['title']?.toString() ?? 'Air Quality Update',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Source and Time
                      Row(
                        children: [
                          // Source Icon
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                (news['source']?.toString().substring(0, 1) ?? 'N').toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 10),
                          
                          // Source Name and Time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  news['source']?.toString() ?? 'News Source',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _formatNewsTime(news['publishedAt']),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Read Button
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'READ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showNewsDetail(Map<String, dynamic> news) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 1.0,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      
                      if (news['imageUrl'] != null && news['imageUrl'].toString().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: news['imageUrl'].toString(),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        news['title']?.toString() ?? 'Air Quality News',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Icon(Icons.source, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            news['source']?.toString() ?? 'Unknown Source',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _formatNewsTime(news['publishedAt']),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        news['description']?.toString() ?? '',
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                      
                      if (news['content'] != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          news['content'].toString(),
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ],
                      
                      const SizedBox(height: 32),
                      
                      if (news['url'] != null && news['url'].toString().isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () {
                            // Open in browser
                            print('Open URL: ${news['url']}');
                          },
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Read Full Article'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _aqiColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  Widget _buildLoadingNewsCards() {
    return PageView.builder(
      controller: PageController(viewportFraction: 0.85),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey[100],
          ),
        );
      },
    );
  }
  
  Widget _buildNoNewsCard() {
    return Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.newspaper, size: 50, color: _aqiColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'No news available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your internet connection or API key',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRealNews,
              style: ElevatedButton.styleFrom(
                backgroundColor: _aqiColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatNewsTime(dynamic timestamp) {
    try {
      if (timestamp == null) return 'Recently';
      
      DateTime date;
      if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Recently';
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d').format(date);
      }
    } catch (e) {
      return 'Recently';
    }
  }

  // ============ DRAWER ============
  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
      ),
      child: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = authSnapshot.data;

          if (user == null) {
            return _buildNotLoggedInDrawer();
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('users').doc(user.uid).snapshots(),
            builder: (context, snapshot) {
              Map<String, dynamic> userData = {};
              if (snapshot.hasData && snapshot.data!.exists) {
                userData = snapshot.data!.data() as Map<String, dynamic>;
              }

              final userName = userData['name'] ?? 
                              user.displayName ?? 
                              user.email?.split('@').first ?? 
                              'User';
              final userEmail = userData['email'] ?? user.email ?? '';
              final isVerified = user.emailVerified;

              return SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User Profile Header
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Profile Picture
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.2),
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  image: user.photoURL != null
                                      ? DecorationImage(
                                          image: NetworkImage(user.photoURL!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: user.photoURL == null
                                    ? const Icon(
                                        Icons.person,
                                        size: 35,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Name with verification badge
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            userName,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            maxLines: 1,
                                          ),
                                        ),
                                        if (isVerified)
                                          Container(
                                            margin: const EdgeInsets.only(left: 5),
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.green,
                                            ),
                                            child: const Icon(
                                              Icons.verified,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Email
                                    Text(
                                      userEmail,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      maxLines: 1,
                                    ),
                                    // Status
                                    Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Online',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Quick Actions
                          Row(
                            children: [
                              Expanded(
                                child: _buildDrawerHeaderButton(
                                  icon: Icons.edit,
                                  label: 'Edit Profile',
                                  onTap: () {
                                    _scaffoldKey.currentState?.closeEndDrawer();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildDrawerHeaderButton(
                                  icon: Icons.settings,
                                  label: 'Settings',
                                  onTap: () {
                                    _scaffoldKey.currentState?.closeEndDrawer();
                                    // TODO: Navigate to settings
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Drawer Menu Items
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildDrawerMenuItem(
                            icon: Icons.home_outlined,
                            label: 'Home',
                            index: 0,
                          ),
                          _buildDrawerMenuItem(
                            icon: Icons.shopping_cart_outlined,
                            label: 'Shopping',
                            index: 1,
                          ),
                          _buildDrawerMenuItem(
                            icon: Icons.health_and_safety_outlined,
                            label: 'Health',
                            index: 2,
                          ),
                          _buildDrawerMenuItem(
                            icon: Icons.notifications_outlined,
                            label: 'Alerts',
                            index: 3,
                          ),
                          const Divider(height: 20),
                          _buildDrawerMenuItem(
                            icon: Icons.person_outline,
                            label: 'My Profile',
                            index: 4,
                          ),
                          _buildDrawerMenuItem(
                            icon: Icons.help_outline,
                            label: 'Help & Support',
                            index: 6,
                          ),
                          _buildDrawerMenuItem(
                            icon: Icons.info_outline,
                            label: 'About',
                            index: 7,
                          ),
                          const Divider(height: 20),
                          _buildDrawerMenuItem(
                            icon: Icons.logout,
                            label: 'Logout',
                            index: 5,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),

                    // App Info Footer
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Air Guard v1.0.0',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Breathe Safe, Live Healthy',
                            style: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotLoggedInDrawer() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.9),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Welcome to Air Guard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to access all features',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _scaffoldKey.currentState?.closeEndDrawer();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sign In / Register',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 60,
                    color: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Please login to continue',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeaderButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerMenuItem({
    required IconData icon,
    required String label,
    required int index,
    Color? color,
  }) {
    final isSelected = _selectedIndex == index && index <= 3;
    final iconColor = color ?? (isSelected ? AppColors.primary : AppColors.textSecondary);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _onDrawerItemSelected(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: color ?? (isSelected ? AppColors.primary : AppColors.textPrimary),
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ OTHER TABS ============
  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return 'Air Quality Dashboard';
      case 1: return 'Air Quality Shopping';
      case 2: return 'Health Insights';
      case 3: return 'Alerts & Notifications';
      default: return 'Air Guard';
    }
  }

  // ============ SHOPPING CONTENT ============
  Widget _buildShoppingContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.primary.withOpacity(0.3)),
          SizedBox(height: 20),
          Text(
            'Air Quality Shopping',
            style: TextStyle(
              fontSize: 20,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Products for clean air living',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ============ ALERTS CONTENT ============
  Widget _buildAlertsContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_active, size: 80, color: Colors.amber.withOpacity(0.3)),
          SizedBox(height: 20),
          Text(
            'Air Quality Alerts',
            style: TextStyle(
              fontSize: 20,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Stay informed about air quality changes',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}