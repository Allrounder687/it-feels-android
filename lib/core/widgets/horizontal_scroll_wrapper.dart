import 'package:flutter/material.dart';

class HorizontalScrollWrapper extends StatefulWidget {
  final Widget Function(BuildContext context, ScrollController controller) builder;

  const HorizontalScrollWrapper({
    super.key,
    required this.builder,
  });

  @override
  State<HorizontalScrollWrapper> createState() => _HorizontalScrollWrapperState();
}

class _HorizontalScrollWrapperState extends State<HorizontalScrollWrapper> {
  late ScrollController _scrollController;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_checkScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (!_scrollController.hasClients) return;
    
    final position = _scrollController.position;
    final canScrollLeft = position.pixels > 0;
    final canScrollRight = position.pixels < position.maxScrollExtent;
    
    if (_canScrollLeft != canScrollLeft || _canScrollRight != canScrollRight) {
      setState(() {
        _canScrollLeft = canScrollLeft;
        _canScrollRight = canScrollRight;
      });
    }
  }

  void _scroll(double amount) {
    if (!_scrollController.hasClients) return;
    final currentPos = _scrollController.offset;
    final targetPos = (currentPos + amount).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      targetPos,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show scroll buttons if the device has a mouse (desktop/web)
    final isDesktop = MediaQuery.of(context).size.width >= 800; // rough heuristic, but actually we can just show on hover

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        children: [
          widget.builder(context, _scrollController),
          if (_canScrollLeft)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _buildScrollButton(
                icon: Icons.chevron_left,
                onTap: () => _scroll(-400),
                alignment: Alignment.centerLeft,
                gradientColors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
          if (_canScrollRight)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _buildScrollButton(
                icon: Icons.chevron_right,
                onTap: () => _scroll(400),
                alignment: Alignment.centerRight,
                gradientColors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScrollButton({
    required IconData icon,
    required VoidCallback onTap,
    required Alignment alignment,
    required List<Color> gradientColors,
  }) {
    return IgnorePointer(
      ignoring: !_isHovered,
      child: AnimatedOpacity(
        opacity: _isHovered ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          alignment: alignment,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
