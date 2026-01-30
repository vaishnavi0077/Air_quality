// navbar.dart - UPDATED VERSION (fixes deprecation warnings)
import 'package:flutter/material.dart';

class NavItem {
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final Color? bubbleColor;

  const NavItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    this.bubbleColor,
  });
}

class WavyFloatingNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final List<NavItem> items;

  final Color backgroundColor;
  final Color iconColor;
  final Color activeIconColor;
  final Color selectedColor;
  final Color unselectedColor;
  final double elevation;
  final double waveHeight;
  final bool showLabels;
  final bool enableWaveAnimation;
  final double horizontalMargin;

  const WavyFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.items,
    this.backgroundColor = Colors.white,
    this.iconColor = Colors.grey,
    this.activeIconColor = const Color(0xFF1E88E5),
    this.selectedColor = Colors.blue,
    this.unselectedColor = Colors.grey,
    this.elevation = 22,
    this.waveHeight = 22,
    this.showLabels = true,
    this.enableWaveAnimation = true,
    this.horizontalMargin = 16,
  });

  @override
  State<WavyFloatingNavBar> createState() => _WavyFloatingNavBarState();
}

class _WavyFloatingNavBarState extends State<WavyFloatingNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _waveAnimation;
  double _waveOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _waveAnimation = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _waveAnimation.addListener(() {
      if (!widget.enableWaveAnimation) return;
      setState(() => _waveOffset = _waveAnimation.value * 10);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final itemWidth = (width - widget.horizontalMargin * 2) / widget.items.length;

    return Container(
      margin: EdgeInsets.fromLTRB(widget.horizontalMargin, 0, widget.horizontalMargin, 20),
      height: 75,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: widget.elevation,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _WavyPainter(
                  selectedIndex: widget.selectedIndex,
                  itemCount: widget.items.length,
                  waveHeight: widget.waveHeight,
                  waveOffset: _waveOffset,
                  backgroundColor: widget.backgroundColor,
                  waveColor: widget.items[widget.selectedIndex].bubbleColor ??
                      widget.activeIconColor,
                ),
              ),
            ),

            Row(
              children: List.generate(widget.items.length, (index) {
                final item = widget.items[index];
                final isSelected = index == widget.selectedIndex;
                final bubbleColor = item.bubbleColor ?? widget.activeIconColor;

                return GestureDetector(
                  onTap: () {
                    widget.onItemTapped(index);
                  },
                  child: SizedBox(
                    width: itemWidth,
                    height: 75,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.elasticOut,
                          transform: Matrix4.translationValues(
                              0.0, isSelected ? -widget.waveHeight / 2 : 0, 0.0),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? bubbleColor : Colors.transparent,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: bubbleColor.withAlpha(128), // Fixed .withOpacity
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              isSelected && item.activeIcon != null
                                  ? item.activeIcon
                                  : item.icon,
                              size: 18,
                              color: isSelected ? Colors.white : widget.iconColor,
                            ),
                          ),
                        ),
                        if (widget.showLabels) const SizedBox(height: 6),
                        if (widget.showLabels)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: isSelected ? 1 : 0.7,
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected ? bubbleColor : widget.iconColor,
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavyPainter extends CustomPainter {
  final int selectedIndex;
  final int itemCount;
  final double waveHeight;
  final double waveOffset;
  final Color backgroundColor;
  final Color waveColor;

  _WavyPainter({
    required this.selectedIndex,
    required this.itemCount,
    required this.waveHeight,
    required this.waveOffset,
    required this.backgroundColor,
    required this.waveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final itemWidth = size.width / itemCount;
    final centerX = itemWidth * (selectedIndex + 0.5);

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(centerX - itemWidth * 0.75, size.height)
      ..cubicTo(
        centerX - itemWidth * 0.4,
        size.height,
        centerX - itemWidth * 0.3,
        waveHeight + waveOffset,
        centerX,
        waveHeight + waveOffset,
      )
      ..cubicTo(
        centerX + itemWidth * 0.3,
        waveHeight + waveOffset,
        centerX + itemWidth * 0.4,
        size.height,
        centerX + itemWidth * 0.75,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    final wavePaint = Paint()
      ..color = waveColor.withAlpha(38) // Equivalent to .withOpacity(0.15)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}