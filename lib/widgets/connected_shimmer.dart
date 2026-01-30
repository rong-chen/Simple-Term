import 'package:flutter/material.dart';

/// 已连接状态的光效动画组件
class ConnectedShimmer extends StatefulWidget {
  final Widget child;
  final bool isActive;
  
  const ConnectedShimmer({
    super.key,
    required this.child,
    this.isActive = false,
  });

  @override
  State<ConnectedShimmer> createState() => _ConnectedShimmerState();
}

class _ConnectedShimmerState extends State<ConnectedShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-0.5 + 2.0 * _controller.value, 0),
              colors: widget.isActive
                  ? [
                      const Color(0xFF1a3a1a),
                      const Color(0xFF2a5a2a),
                      const Color(0xFF1a3a1a),
                    ]
                  : [
                      const Color(0xFF1a3a1a),
                      const Color(0xFF254525),
                      const Color(0xFF1a3a1a),
                    ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
