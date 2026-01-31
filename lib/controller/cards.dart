import 'dart:math' as math;
import 'package:flutter/material.dart';

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
  late Animation<double> _fadeAnimation;
  bool _isHovering = false;
  
  // Animation controllers for specific effects
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  late AnimationController _bubbleController;
  late Animation<double> _bubbleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main hover animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    // Pulse animation for heartbeat effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Bubble animation
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
    } catch (e) {
      // Fallback to mapped color
    }
    
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

  // ANIMATION TYPES
  Widget _buildAnimatedIcon() {
    final animationType = widget.cardData['animation'] ?? '';
    final icon = widget.cardData['icon'] ?? 'air';
    
    final iconMap = {
      'air': Icons.air,
      'favorite': Icons.favorite,
      'cloud': Icons.cloud,
      'masks': Icons.masks,
      'update': Icons.update,
    };
    
    switch (animationType) {
      case 'bubbles':
        return _buildBubbleAnimation();
      case 'heartbeat':
        return _buildHeartbeatAnimation();
      case 'cloudy':
        return _buildCloudAnimation();
      case 'mask':
        return _buildMaskAnimation();
      case 'update':
        return _buildUpdateAnimation();
      default:
        return Icon(
          iconMap[icon] ?? Icons.air,
          size: 40.0,
          color: Colors.white,
        );
    }
  }

  // 1. BUBBLE ANIMATION
  Widget _buildBubbleAnimation() {
    return AnimatedBuilder(
      animation: _bubbleController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Main bubble
            Transform.scale(
              scale: 1.0 + math.sin(_bubbleController.value * 2.0 * math.pi) * 0.1,
              child: Container(
                width: 50.0,
                height: 50.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.3),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white,
                    width: 2.0,
                  ),
                ),
              ),
            ),
            
            // Floating smaller bubbles
            ...List.generate(3, (index) {
              final offset = _bubbleAnimation.value * 2.0 * math.pi;
              final angle = offset + (index * 2.0 * math.pi / 3.0);
              final radius = 25.0 + math.sin(offset * 2.0) * 5.0;
              
              return Positioned(
                left: 25.0 + math.cos(angle) * radius,
                top: 25.0 + math.sin(angle) * radius,
                child: Container(
                  width: 8.0 + index.toDouble() * 2.0,
                  height: 8.0 + index.toDouble() * 2.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // 2. HEARTBEAT ANIMATION
  Widget _buildHeartbeatAnimation() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing heart
            Transform.scale(
              scale: _pulseAnimation.value,
              child: Icon(
                Icons.favorite,
                size: 50.0,
                color: Colors.white,
              ),
            ),
            
            // Ripple effect
            ...List.generate(2, (index) {
              return Positioned(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  width: 50.0 + (_pulseController.value * 20.0 * (index + 1)),
                  height: 50.0 + (_pulseController.value * 20.0 * (index + 1)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(
                        0.3 * (1 - _pulseController.value),
                      ),
                      width: 2.0,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // 3. CLOUD ANIMATION
  Widget _buildCloudAnimation() {
    return AnimatedBuilder(
      animation: _bubbleController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Main cloud
            Icon(
              Icons.cloud,
              size: 50.0,
              color: Colors.white,
            ),
            
            // Moving particles
            ...List.generate(5, (index) {
              final xOffset = math.sin(
                _bubbleController.value * 2.0 * math.pi + (index * 0.5)
              ) * 20.0;
              
              return Positioned(
                left: 25.0 + xOffset,
                top: 15.0 + index.toDouble() * 5.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 4.0 + index.toDouble(),
                  height: 4.0 + index.toDouble(),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.7 - (index * 0.1)),
                  ),
                ),
              );
            }),
            
            // Rain drops
            if (_isHovering)
              ...List.generate(3, (index) {
                return Positioned(
                  top: 40.0 + (_bubbleController.value * 20.0 * index),
                  left: 20.0 + (index * 10.0),
                  child: Container(
                    width: 3.0,
                    height: 8.0,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // 4. MASK ANIMATION
  Widget _buildMaskAnimation() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Mask icon
        Icon(
          Icons.masks,
          size: 50.0,
          color: Colors.white,
        ),
        
        // Protective shield
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: _isHovering ? 70.0 : 60.0,
          height: _isHovering ? 70.0 : 60.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(_isHovering ? 0.5 : 0.3),
              width: 2.0,
            ),
          ),
        ),
        
        // Floating protection particles
        if (_isHovering)
          ...List.generate(4, (index) {
            final angle = _bubbleController.value * 2.0 * math.pi + (index * math.pi / 2.0);
            final radius = 35.0;
            
            return Positioned(
              left: 25.0 + math.cos(angle) * radius,
              top: 25.0 + math.sin(angle) * radius,
              child: Container(
                width: 6.0,
                height: 6.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.5),
                      blurRadius: 4.0,
                      spreadRadius: 2.0,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // 5. UPDATE/REFRESH ANIMATION
  Widget _buildUpdateAnimation() {
    return AnimatedBuilder(
      animation: _bubbleController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Rotating icon
            Transform.rotate(
              angle: _bubbleController.value * 2.0 * math.pi,
              child: Icon(
                Icons.update,
                size: 50.0,
                color: Colors.white,
              ),
            ),
            
            // Progress ring
            SizedBox(
              width: 60.0,
              height: 60.0,
              child: CircularProgressIndicator(
                value: _bubbleController.value,
                strokeWidth: 2.0,
                color: Colors.white.withOpacity(0.7),
                backgroundColor: Colors.white.withOpacity(0.2),
              ),
            ),
            
            // Data points
            ...List.generate(4, (index) {
              final angle = (index * math.pi / 2.0) + (_bubbleController.value * math.pi / 2.0);
              final radius = 30.0;
              
              return Positioned(
                left: 25.0 + math.cos(angle) * radius,
                top: 25.0 + math.sin(angle) * radius,
                child: Container(
                  width: 6.0,
                  height: 6.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(
                      0.9 - (index * 0.2)
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = _getCardColor();
    final textColor = cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final subtitleColor = textColor.withOpacity(0.8);
    
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Animated Icon Container
                      Container(
                        height: 80.0,
                        width: 80.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Center(
                          child: _buildAnimatedIcon(),
                        ),
                      ),
                      
                      const SizedBox(height: 16.0),
                      
                      // Title with subtle animation
                      AnimatedOpacity(
                        opacity: _isHovering ? 1.0 : 0.9,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          widget.cardData['title'] ?? 'Health Card',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            shadows: _isHovering ? [
                              Shadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4.0,
                                offset: const Offset(1.0, 1.0),
                              ),
                            ] : null,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      const SizedBox(height: 8.0),
                      
                      // Subtitle
                      Text(
                        widget.cardData['subtitle'] ?? 'Health Information',
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 13.0,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 12.0),
                      
                      // Value with pulse animation on hover
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(_isHovering ? 0.2 : 0.15),
                          borderRadius: BorderRadius.circular(20.0),
                          boxShadow: _isHovering ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 10.0,
                              spreadRadius: 1.0,
                            ),
                          ] : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              scale: _isHovering ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                widget.cardData['value']?.toString() ?? '',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            
                            const SizedBox(width: 4.0),
                            
                            Text(
                              widget.cardData['unit']?.toString() ?? '',
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                                fontSize: 12.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
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