import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final AnimationController _lineController;
  late final Animation<double> _linePosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();

    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _linePosition = CurvedAnimation(
      parent: _lineController,
      curve: Curves.easeInOut,
    );

    Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      context.go('/permissions');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _lineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/ntwaza_splash.png',
                fit: BoxFit.cover,
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xB3000000),
                      Color(0xE6000000),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _linePosition,
                        builder: (context, child) {
                          const lineWidth = 150.0;
                          const dotSize = 10.0;
                          final travel = lineWidth - dotSize;
                          return SizedBox(
                            width: lineWidth,
                            height: 12,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F262A),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                Positioned(
                                  left: travel * _linePosition.value,
                                  child: Container(
                                    width: dotSize,
                                    height: dotSize,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF66D36E),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF66D36E)
                                              .withOpacity(0.6),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Fast. Fresh. On time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFFCCCCCC),
                          fontSize: 14,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFF66D36E),
                          backgroundColor: Color(0xFF22282B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
