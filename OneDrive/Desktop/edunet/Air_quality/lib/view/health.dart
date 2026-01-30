import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
class HealthRecommendationScreen extends StatefulWidget {
  const HealthRecommendationScreen({super.key});

  @override
  _HealthRecommendationScreenState createState() =>
      _HealthRecommendationScreenState();
}

class _HealthRecommendationScreenState
    extends State<HealthRecommendationScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Health Cards Data
  List<Map<String, dynamic>> healthCards = [];
  int _currentCardIndex = 0;
  
  // Recommendations Datayour 
  List<String> recommendations = [];
  List<String> dos = [];
  List<String> donts = [];
  
  // AQI Data
  int aqi = 0;
  String aqiStatus = '';
  String location = '';
  String aqiDescription = '';
  Color aqiColor = const Color(0xFF4CAF50);
  IconData aqiIcon = Icons.sentiment_satisfied;
  
  // UI State
  bool isLoading = true;
  bool _isDisposed = false;
  
  // Animation Controllers
  late AnimationController _cardSlideController;
  late Animation<double> _cardSlideAnimation;
  late AnimationController _cardFadeController;
  late Animation<double> _cardFadeAnimation;
  late AnimationController _bubbleController;
  late AnimationController _pulseController;
  late AnimationController _autoChangeController;
  late AnimationController _breathController;
  late AnimationController _listItemController;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    try {
      // Card sliding animation
      _cardSlideController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      )..repeat(reverse: true);
      
      _cardSlideAnimation = Tween<double>(begin: -10, end: 10).animate(
        CurvedAnimation(
          parent: _cardSlideController,
          curve: Curves.easeInOut,
        ),
      );

      // Card fade animation
      _cardFadeController = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      )..repeat(reverse: true);
      
      _cardFadeAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(
          parent: _cardFadeController,
          curve: Curves.easeInOut,
        ),
      );

      // Background bubble animation
      _bubbleController = AnimationController(
        duration: const Duration(seconds: 8),
        vsync: this,
      )..repeat();

      // Pulse animation for cards
      _pulseController = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      )..repeat(reverse: true);

      // Auto card change animation
      _autoChangeController = AnimationController(
        duration: const Duration(seconds: 5),
        vsync: this,
      )..repeat();

      // Breathing animation
      _breathController = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      )..repeat(reverse: true);

      // List item animation
      _listItemController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      )..repeat(reverse: true);

      // Listen to auto change controller to change cards automatically
      _autoChangeController.addListener(() {
        if (_autoChangeController.isCompleted) {
          _autoChangeController.reset();
          _nextCard();
        }
      });

    } catch (e) {
      debugPrint('Error initializing animations: $e');
    }
  }

  Future<void> _initializeApp() async {
    try {
      await _loadData();
    } catch (e) {
      debugPrint('Error initializing app: $e');
      _loadFallbackData();
    }
  }

  void _nextCard() {
    if (_isDisposed || healthCards.isEmpty) return;
    
    _safeSetState(() {
      _currentCardIndex = (_currentCardIndex + 1) % healthCards.length;
    });
  }

  void _previousCard() {
    if (_isDisposed || healthCards.isEmpty) return;
    
    _safeSetState(() {
      _currentCardIndex = (_currentCardIndex - 1 + healthCards.length) % healthCards.length;
    });
  }

  Future<void> _loadData() async {
    if (_isDisposed) return;
    
    try {
      _safeSetState(() {
        isLoading = true;
      });

      // Load data sequentially
      await _loadAqiData();
      await _loadHealthCards();
      await _loadRecommendations();

      _safeSetState(() {
        isLoading = false;
      });

      // Start animations
      _cardSlideController.repeat(reverse: true);
      _cardFadeController.repeat(reverse: true);
      _bubbleController.repeat();
      _pulseController.repeat(reverse: true);
      _autoChangeController.repeat();
      _breathController.repeat(reverse: true);
      _listItemController.repeat(reverse: true);

    } catch (e) {
      debugPrint('Error loading data: $e');
      _loadFallbackData();
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  Future<void> _loadAqiData() async {
    try {
      final aqiDoc = await _firestore.collection('aqi_data').doc('current').get();
      
      int currentAqi = 75;
      String currentLocation = 'Your Location';
      
      if (aqiDoc.exists) {
        final data = aqiDoc.data()!;
        currentAqi = data['value'] ?? 75;
        currentLocation = data['location'] ?? 'Your Location';
      }

      final configDoc = await _firestore.collection('aqi_configuration').doc('categories').get();
      
      if (!configDoc.exists) {
        await _initializeAqiConfiguration();
        await _loadAqiData(); // Retry after initialization
        return;
      }

      final configData = configDoc.data()!;
      final thresholds = configData['thresholds'] as Map<String, dynamic>;
      final String aqiCategory = _determineAqiCategory(currentAqi, thresholds);
      final Map<String, dynamic> categoryConfig = 
          (configData[aqiCategory] as Map<String, dynamic>?) ?? {};

      _safeSetState(() {
        aqi = currentAqi;
        location = currentLocation;
        aqiStatus = categoryConfig['status'] ?? 'Moderate';
        aqiDescription = categoryConfig['description'] ?? 'Air quality is moderate.';
        aqiColor = _parseColor(categoryConfig['color'] ?? '#4CAF50');
        aqiIcon = _parseIcon(categoryConfig['icon'] ?? 'sentiment_satisfied');
      });

    } catch (e) {
      debugPrint('Error loading AQI data: $e');
      throw e;
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      final configDoc = await _firestore.collection('aqi_configuration').doc('categories').get();
      
      if (configDoc.exists) {
        final configData = configDoc.data()!;
        final thresholds = configData['thresholds'] as Map<String, dynamic>;
        final String aqiCategory = _determineAqiCategory(aqi, thresholds);
        final Map<String, dynamic> categoryConfig = 
            (configData[aqiCategory] as Map<String, dynamic>?) ?? {};

        _safeSetState(() {
          recommendations = List<String>.from(categoryConfig['recommendations'] ?? []);
          dos = List<String>.from(categoryConfig['dos'] ?? []);
          donts = List<String>.from(categoryConfig['donts'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
      throw e;
    }
  }





Future<void> _fetchUserLocation() async {
  try {
    _safeSetState(() {
      location = 'Fetching location...';
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    final place = placemarks.first;
    final city = place.locality ?? '';
    final state = place.administrativeArea ?? '';

    _safeSetState(() {
      location =
          city.isNotEmpty ? '$city${state.isNotEmpty ? ', $state' : ''}' : 'Your Location';
    });

    // 🔥 AI / ML READY
    debugPrint('LATITUDE: ${position.latitude}');
    debugPrint('LONGITUDE: ${position.longitude}');

  } catch (e) {
    debugPrint('Location Error: $e');
    _safeSetState(() {
      location = 'Location unavailable';
    });
  }
}






  Future<void> _initializeAqiConfiguration() async {
    try {
      final config = {
        'thresholds': {
          'good': 50,
          'moderate': 100,
          'unhealthy_sensitive': 150,
          'unhealthy': 200,
          'very_unhealthy': 300,
          'hazardous': 500
        },
        'good': {
          'status': 'Good',
          'description': 'Air quality is satisfactory.',
          'color': '#4CAF50',
          'icon': 'sentiment_very_satisfied',
          'recommendations': [
            'Enjoy outdoor activities',
            'Open windows for ventilation',
            'Exercise outdoors',
            'Spend time in nature'
          ],
          'dos': [
            'Stay hydrated',
            'Keep indoor plants',
            'Maintain regular activities',
            'Check AQI daily'
          ],
          'donts': [
            'No restrictions needed',
            'Avoid indoor confinement'
          ]
        },
        'moderate': {
          'status': 'Moderate',
          'description': 'Air quality is acceptable.',
          'color': '#FFC107',
          'icon': 'sentiment_satisfied',
          'recommendations': [
            'Sensitive groups should limit outdoor activity',
            'Consider indoor alternatives',
            'Monitor air quality'
          ],
          'dos': [
            'Use air purifiers if sensitive',
            'Keep windows closed during peak hours',
            'Wear masks if needed',
            'Stay hydrated'
          ],
          'donts': [
            'Avoid strenuous activities',
            "Don't ignore symptoms",
            'Avoid busy roads'
          ]
        },
        'unhealthy_sensitive': {
          'status': 'Unhealthy for Sensitive',
          'description': 'Sensitive groups may experience effects.',
          'color': '#FF9800',
          'icon': 'sentiment_neutral',
          'recommendations': [
            'Sensitive groups avoid outdoors',
            'Reschedule outdoor plans',
            'Use indoor air monitors'
          ],
          'dos': [
            'Wear N95 masks outdoors',
            'Keep windows closed',
            'Use air conditioning',
            'Stay in ventilated spaces'
          ],
          'donts': [
            'Avoid outdoor exercise',
            "Don't expose vulnerable people",
            'Avoid industrial areas'
          ]
        },
        'unhealthy': {
          'status': 'Unhealthy',
          'description': 'Everyone may experience effects.',
          'color': '#F44336',
          'icon': 'sentiment_dissatisfied',
          'recommendations': [
            'Avoid outdoor exertion',
            'Postpone activities',
            'Seek medical advice'
          ],
          'dos': [
            'Stay indoors with air purification',
            'Use high-efficiency filters',
            'Keep medications accessible',
            'Monitor symptoms'
          ],
          'donts': [
            'Do not engage outdoors',
            'Avoid opening windows',
            "Don't use fans that bring outside air"
          ]
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('aqi_configuration').doc('categories').set(config);
    } catch (e) {
      debugPrint('Error initializing AQI config: $e');
    }
  }

  Future<void> _loadHealthCards() async {
    try {
      final snapshot = await _firestore
          .collection('health_cards')
          .orderBy('order')
          .get();

      if (snapshot.docs.isEmpty) {
        await _initializeHealthCards();
        return _loadHealthCards();
      }

      final cards = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'subtitle': data['subtitle'] ?? '',
          'icon': data['icon'] ?? 'info',
          'color': data['color'] ?? '#4CAF50',
          'description': data['description'] ?? '',
          'value': data['value'] ?? '',
          'unit': data['unit'] ?? '',
          'animation': data['animation'] ?? 'bubbles',
          'order': data['order'] ?? 0,
        };
      }).toList();

      _safeSetState(() {
        healthCards = cards;
      });

    } catch (e) {
      debugPrint('Error loading health cards: $e');
      throw e;
    }
  }

  Future<void> _initializeHealthCards() async {
    try {
      final defaultCards = [
        {
          'title': 'AQI Basics',
          'subtitle': 'Understanding Air Quality',
          'icon': 'air',
          'color': '#4CAF50',
          'description': 'AQI measures air pollution levels from 0-500. Lower is healthier. Values above 100 can affect sensitive groups.',
          'value': '$aqi',
          'unit': 'Current AQI',
          'animation': 'bubbles',
          'order': 1,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Health Impact',
          'subtitle': 'How AQI affects you',
          'icon': 'favorite',
          'color': '#FF5252',
          'description': 'High AQI (above 100) can cause breathing issues, headaches, fatigue, and worsen asthma or heart conditions.',
          'value': aqiStatus,
          'unit': 'Status',
          'animation': 'heartbeat',
          'order': 2,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Vulnerable Groups',
          'subtitle': 'Who should be careful',
          'icon': 'people',
          'color': '#2196F3',
          'description': 'Children, elderly, pregnant women, and people with respiratory or heart conditions are most at risk.',
          'value': 'High Risk',
          'unit': 'Alert Level',
          'animation': 'shield',
          'order': 3,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Pollutants',
          'subtitle': "What's in the air",
          'icon': 'water_drop',
          'color': '#9C27B0',
          'description': 'PM2.5 (fine particles), PM10 (coarse), Ozone, NO2, SO2, and Carbon Monoxide are monitored pollutants.',
          'value': '6 Types',
          'unit': 'Total',
          'animation': 'particles',
          'order': 4,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Protection Tips',
          'subtitle': 'Stay safe outdoors',
          'icon': 'shield',
          'color': '#FF9800',
          'description': 'Wear N95 masks, avoid busy roads, limit outdoor exercise when AQI > 100, check air quality apps.',
          'value': '5 Tips',
          'unit': 'Safety',
          'animation': 'stars',
          'order': 5,
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      final batch = _firestore.batch();
      for (final card in defaultCards) {
        final docRef = _firestore.collection('health_cards').doc();
        batch.set(docRef, card);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error initializing health cards: $e');
    }
  }

  String _determineAqiCategory(int aqiValue, Map<String, dynamic> thresholds) {
    if (aqiValue <= (thresholds['good'] as int? ?? 50)) return 'good';
    if (aqiValue <= (thresholds['moderate'] as int? ?? 100)) return 'moderate';
    if (aqiValue <= (thresholds['unhealthy_sensitive'] as int? ?? 150)) return 'unhealthy_sensitive';
    return 'unhealthy';
  }

  Color _parseColor(String colorString) {
    try {
      String hexColor = colorString.replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return const Color(0xFF4CAF50);
    }
  }

  IconData _parseIcon(String iconName) {
    final iconMap = {
      'sentiment_very_satisfied': Icons.sentiment_very_satisfied,
      'sentiment_satisfied': Icons.sentiment_satisfied,
      'sentiment_neutral': Icons.sentiment_neutral,
      'sentiment_dissatisfied': Icons.sentiment_dissatisfied,
      'sentiment_very_dissatisfied': Icons.sentiment_very_dissatisfied,
      'warning': Icons.warning,
      'error': Icons.error,
      'air': Icons.air,
      'health_and_safety': Icons.health_and_safety,
      'directions_run': Icons.directions_run,
      'home': Icons.home,
      'local_drink': Icons.local_drink,
      'masks': Icons.masks,
      'spa': Icons.spa,
      'favorite': Icons.favorite,
      'people': Icons.people,
      'water_drop': Icons.water_drop,
      'shield': Icons.shield,
      'info': Icons.info,
    };
    
    return iconMap[iconName] ?? Icons.info;
  }

  void _loadFallbackData() {
    _safeSetState(() {
      aqi = 75;
      aqiStatus = 'Moderate';
      aqiDescription = 'Air quality is acceptable for most people';
      location = 'Your Location';
      aqiColor = const Color(0xFF4CAF50);
      aqiIcon = Icons.sentiment_satisfied;
      
      healthCards = [
        {
          'title': 'AQI Basics',
          'subtitle': 'Understanding Air Quality',
          'icon': 'air',
          'color': '#4CAF50',
          'description': 'AQI measures air pollution levels from 0-500. Lower is healthier.',
          'value': '75',
          'unit': 'Current AQI',
          'animation': 'bubbles'
        },
        {
          'title': 'Health Impact',
          'subtitle': 'How AQI affects you',
          'icon': 'favorite',
          'color': '#FF5252',
          'description': 'High AQI can cause breathing issues, headaches, and fatigue.',
          'value': 'Moderate',
          'unit': 'Status',
          'animation': 'heartbeat'
        },
        {
          'title': 'Vulnerable Groups',
          'subtitle': 'Who should be careful',
          'icon': 'people',
          'color': '#2196F3',
          'description': 'Children, elderly, and people with health conditions are most at risk.',
          'value': 'High Risk',
          'unit': 'Alert',
          'animation': 'shield'
        },
        {
          'title': 'Pollutants',
          'subtitle': "What's in the air",
          'icon': 'water_drop',
          'color': '#9C27B0',
          'description': 'PM2.5, PM10, Ozone, NO2, SO2, and Carbon Monoxide.',
          'value': '6 Types',
          'unit': 'Total',
          'animation': 'particles'
        },
        {
          'title': 'Protection Tips',
          'subtitle': 'Stay safe outdoors',
          'icon': 'shield',
          'color': '#FF9800',
          'description': 'Wear masks, avoid busy roads, check air quality apps regularly.',
          'value': '5 Tips',
          'unit': 'Safety',
          'animation': 'stars'
        },
      ];
      
      recommendations = [
        'Monitor AQI levels regularly',
        'Adjust outdoor activities based on air quality',
        'Use air purifiers indoors when needed',
        'Stay hydrated to help your body cope',
        'Consider wearing masks on high pollution days'
      ];
      
      dos = [
        'Check AQI forecasts before planning outdoor activities',
        'Keep windows closed during high pollution hours',
        'Use air conditioning with clean filters',
        'Stay hydrated by drinking plenty of water',
        'Wear N95 masks when air quality is poor',
        'Use indoor air purifiers with HEPA filters',
        'Keep indoor plants that purify air',
        'Exercise indoors when outdoor air quality is bad'
      ];
      
      donts = [
        "Don't exercise outdoors when AQI is above 150",
        'Avoid busy roads and industrial areas',
        "Don't burn candles or incense indoors",
        'Avoid opening windows during rush hour',
        "Don't ignore symptoms like coughing or wheezing",
        'Avoid outdoor gatherings during pollution alerts',
        "Don't use fans that bring in outside air without filters",
        "Don't neglect regular maintenance of air purifiers"
      ];
      
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    
    _cardSlideController.dispose();
    _cardFadeController.dispose();
    _bubbleController.dispose();
    _pulseController.dispose();
    _autoChangeController.dispose();
    _breathController.dispose();
    _listItemController.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(aqiColor),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading health information...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Health & AQI Insights'),
        backgroundColor: aqiColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // AQI Status Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    aqiColor,
                    aqiColor.withOpacity(0.8),
                  ],
                ),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _breathController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_breathController.value * 0.1),
                        child: Icon(
                          aqiIcon,
                          color: Colors.white,
                          size: 40,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AQI: $aqi • $aqiStatus',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      aqiStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Animated Health Cards Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section Title
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16,top:6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Health Insights',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: aqiColor,
                          ),
                        ),
                        Text(
                          '${_currentCardIndex + 1}/${healthCards.length}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main Animated Card
                  Container(
                    height: 300,
                    child: healthCards.isNotEmpty
                        ? _buildAnimatedCard(healthCards[_currentCardIndex])
                        : _buildNoCardsPlaceholder(),
                  ),

                  // Card Navigation
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Previous Button
                        IconButton(
                          onPressed: _previousCard,
                          icon: Icon(Icons.arrow_back_ios, color: aqiColor),
                          style: IconButton.styleFrom(
                            backgroundColor: aqiColor.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        
                        // Dots Indicator
                        Expanded(
                          child: Center(
                            child: Wrap(
                              spacing: 8,
                              children: List.generate(healthCards.length, (index) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: index == _currentCardIndex ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: index == _currentCardIndex 
                                        ? aqiColor 
                                        : aqiColor.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        
                        // Next Button
                        IconButton(
                          onPressed: _nextCard,
                          icon: Icon(Icons.arrow_forward_ios, color: aqiColor),
                          style: IconButton.styleFrom(
                            backgroundColor: aqiColor.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Auto-change indicator
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        Icon(Icons.autorenew, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                       
                      ],
                    ),
                  ),

                  // Recommendations Section
                  if (recommendations.isNotEmpty)
                    _buildRecommendationsSection(),

                  // Dos Section
                  if (dos.isNotEmpty)
                    _buildDosSection(),

                  // Don'ts Section
                  if (donts.isNotEmpty)
                    _buildDontsSection(),

                  // Spacer at bottom
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
      
      // Refresh Button
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        backgroundColor: aqiColor,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildAnimatedCard(Map<String, dynamic> card) {
    final cardColor = _parseColor(card['color'] ?? '#4CAF50');
    
    return AnimatedBuilder(
      animation: Listenable.merge([_cardSlideController, _cardFadeController, _pulseController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _cardSlideAnimation.value),
          child: Opacity(
            opacity: _cardFadeAnimation.value,
            child: Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.02),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cardColor.withOpacity(0.1),
                        cardColor.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Background Animation
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CustomPaint(
                            painter: _CardBackgroundPainter(
                              animationValue: _bubbleController.value,
                              color: cardColor.withOpacity(0.1),
                              animationType: card['animation'] ?? 'bubbles',
                            ),
                          ),
                        ),
                      ),

                      // Card Content
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon and Title Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cardColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _parseIcon(card['icon']),
                                    color: cardColor,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        card['title'],
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: cardColor,
                                        ),
                                      ),
                                      Text(
                                        card['subtitle'],
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

                            const SizedBox(height: 20),

                            // Description
                            Expanded(
                              child: Text(
                                card['description'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Value and Unit
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Value',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            card['value'],
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: cardColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            card['unit'],
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: cardColor.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Animation Type Indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cardColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getAnimationIcon(card['animation']),
                                        size: 16,
                                        color: cardColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        card['animation']?.toString().toUpperCase() ?? 'ANIMATION',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: cardColor,
                                        ),
                                      ),
                                    ],
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
          ),
        );
      },
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Personalized Recommendations',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Based on current AQI: $aqi ($aqiStatus)',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Smart Suggestions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...recommendations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return AnimatedBuilder(
                    animation: _listItemController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, sin(_listItemController.value * 2 * pi + index * 0.3) * 1),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.eco,
                                  color: Colors.blue,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              Icons.thumb_up,
              color: Colors.green,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Health Do\'s',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Positive actions for better health',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green[100]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Recommended Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...dos.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return AnimatedBuilder(
                    animation: _listItemController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, sin(_listItemController.value * 2 * pi + index * 0.5) * 1),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDontsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              Icons.thumb_down,
              color: Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Health Don\'ts',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Actions to avoid for health protection',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red[100]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Avoid These Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...donts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return AnimatedBuilder(
                    animation: _listItemController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, sin(_listItemController.value * 2 * pi + index * 0.4) * 1),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getAnimationIcon(String? animationType) {
    switch (animationType) {
      case 'bubbles': return Icons.bubble_chart;
      case 'heartbeat': return Icons.favorite;
      case 'shield': return Icons.security;
      case 'particles': return Icons.grain;
      case 'stars': return Icons.star;
      default: return Icons.animation;
    }
  }

  Widget _buildNoCardsPlaceholder() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              aqiColor.withOpacity(0.1),
              aqiColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.health_and_safety,
              size: 64,
              color: aqiColor.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              'No Health Data Available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please check your connection or refresh',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for Card Background Animations
class _CardBackgroundPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final String animationType;

  _CardBackgroundPainter({
    required this.animationValue,
    required this.color,
    required this.animationType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (animationType) {
      case 'bubbles':
        _drawBubbles(canvas, size, paint);
        break;
      case 'heartbeat':
        _drawHeartbeat(canvas, size, paint);
        break;
      case 'shield':
        _drawShield(canvas, size, paint);
        break;
      case 'particles':
        _drawParticles(canvas, size, paint);
        break;
      case 'stars':
        _drawStars(canvas, size, paint);
        break;
      default:
        _drawBubbles(canvas, size, paint);
    }
  }

  void _drawBubbles(Canvas canvas, Size size, Paint paint) {
    for (int i = 0; i < 10; i++) {
      final x = size.width * (0.1 + (i * 0.08));
      final y = size.height * 0.5 + sin(animationValue * 2 * pi + i) * 30;
      final radius = 4 + sin(animationValue * 2 * pi + i * 0.5) * 3;
      
      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint..color = color.withOpacity(0.3),
      );
    }
  }

  void _drawHeartbeat(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final centerY = size.height * 0.5;
    
    for (double x = 0; x < size.width; x += 2) {
      final y = centerY + sin(x * 0.05 + animationValue * 2 * pi) * 15;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(
      path,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withOpacity(0.4),
    );
  }

  void _drawShield(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 40 + sin(animationValue * 2 * pi) * 10;
    
    canvas.drawCircle(
      center,
      radius,
      paint..style = PaintingStyle.stroke..strokeWidth = 2,
    );
    
    // Draw shield lines
    for (int i = 0; i < 6; i++) {
      final angle = 2 * pi * i / 6 + animationValue * pi;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;
      
      canvas.drawLine(
        center,
        Offset(x, y),
        paint..strokeWidth = 1,
      );
    }
  }

  void _drawParticles(Canvas canvas, Size size, Paint paint) {
    for (int i = 0; i < 20; i++) {
      final angle = 2 * pi * i / 20 + animationValue * 2 * pi;
      final distance = 30 + sin(animationValue * 2 * pi + i) * 20;
      final x = size.width / 2 + cos(angle) * distance;
      final y = size.height / 2 + sin(angle) * distance;
      final radius = 1.5 + sin(animationValue * 2 * pi + i * 0.3) * 1;
      
      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint..color = color.withOpacity(0.4),
      );
    }
  }

  void _drawStars(Canvas canvas, Size size, Paint paint) {
    for (int i = 0; i < 12; i++) {
      final x = size.width * (0.1 + i * 0.07);
      final y = size.height * (0.3 + sin(animationValue * 2 * pi + i * 0.7) * 0.4);
      
      // Draw 5-point star
      final path = Path();
      for (int j = 0; j < 5; j++) {
        final angle = 2 * pi * j / 5 - pi / 2;
        final radius = j % 2 == 0 ? 4 : 2;
        final pointX = x + cos(angle) * radius;
        final pointY = y + sin(angle) * radius;
        
        if (j == 0) {
          path.moveTo(pointX, pointY);
        } else {
          path.lineTo(pointX, pointY);
        }
      }
      path.close();
      
      canvas.drawPath(
        path,
        paint..color = color.withOpacity(0.3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CardBackgroundPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
           color != oldDelegate.color ||
           animationType != oldDelegate.animationType;
  }
}