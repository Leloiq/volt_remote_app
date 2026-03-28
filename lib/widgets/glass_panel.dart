import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const GlassPanel({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.opacity = 0.4,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.border,
    this.padding,
    this.width,
    this.height,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null 
                  ? const Color(0xFF353534).withOpacity(opacity) 
                  : null,
              borderRadius: borderRadius,
              border: border ?? Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
