import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/setup/1');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF131313), Color(0xFF1A0D06), Colors.black],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // V Logo Placeholder
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Icon(Icons.bolt, size: 80, color: Colors.white),
                ],
              ),
              const SizedBox(height: 32),
              // VOLT text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Text(
                    'VOLT',
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: AppColors.primaryContainer.withOpacity(0.6), blurRadius: 20)
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.power_settings_new, color: AppColors.primaryContainer, size: 36),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'NEXT-GEN CONTROL',
                style: TextStyle(
                  color: AppColors.primaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
