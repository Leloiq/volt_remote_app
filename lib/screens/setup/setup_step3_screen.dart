import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class SetupStep3Screen extends StatelessWidget {
  const SetupStep3Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryContainer),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'VOLT TV',
          style: TextStyle(color: AppColors.primaryContainer, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              const Text('STEP 3', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3)),
              const SizedBox(height: 8),
              Container(
                width: 120,
                height: 4,
                decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 64),
              // Success Icon
              Center(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.15)),
                    boxShadow: [BoxShadow(color: AppColors.primaryContainer.withOpacity(0.4), blurRadius: 60, spreadRadius: -15)],
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2, style: BorderStyle.solid),
                        ),
                      ),
                      const Icon(Icons.check_circle, size: 80, color: AppColors.primaryContainer),
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBright,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                          ),
                          child: const Text('CONNECTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: AppColors.onSurface)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 64),
              const Text(
                'Your TV is \nconnected',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1.1),
              ),
              const SizedBox(height: 16),
              const Text(
                "You're all set! You can now control your TV, launch apps, and cast media directly from VOLT.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 16, height: 1.5),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryContainer],
                  ),
                  boxShadow: [BoxShadow(color: AppColors.primaryContainer.withOpacity(0.3), blurRadius: 32, offset: const Offset(0, 8))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pushReplacementNamed(context, '/home'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Text('GO TO REMOTE', textAlign: TextAlign.center, style: TextStyle(color: AppColors.onPrimaryContainer, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/setup/1'),
                child: Text("ADD ANOTHER DEVICE", style: TextStyle(color: AppColors.onSurface.withOpacity(0.6), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
