import 'package:flutter/material.dart';
import 'dart:async';
import 'package:rotina_comercial/components/animated_logo_title.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _zoomOutController;
  late Animation<double> _zoomOutScale;
  late Animation<double> _zoomOutOpacity;
  String _dots = '';
  bool _zooming = false;

  @override
  void initState() {
    super.initState();
    _zoomOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _zoomOutScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _zoomOutController, curve: Curves.easeInBack),
    );
    _zoomOutOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _zoomOutController, curve: Curves.easeIn),
    );

    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_dots.length >= 3) {
          _dots = '';
        } else {
          _dots += '.';
        }
      });
    });

    Timer(const Duration(milliseconds: 2600), () {
      if (mounted && !_zooming) {
        _startZoomOut();
      }
    });
  }

  void _startZoomOut() {
    _zooming = true;
    _zoomOutController.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _zoomOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Center(
        child: AnimatedBuilder(
          animation: _zoomOutController,
          builder: (context, child) {
            final scale = _zooming ? _zoomOutScale.value : 1.0;
            final opacity = _zooming ? _zoomOutOpacity.value : 1.0;
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AnimatedLogoTitle(
                logoSize: 120,
                title: 'Rotina Comercial',
                titleColor: Color(0xFFE60014),
              ),
              const SizedBox(height: 20),
              Text(
                _dots,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE60014),
                  fontFamily: 'Open Sans',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
