import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/glass_panel.dart';

class SetupStep2Screen extends StatelessWidget {
  const SetupStep2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'VOLT TV',
          style: TextStyle(color: AppColors.primaryContainer, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(color: AppColors.surfaceContainerHighest, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {},
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryContainer.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('STEP 2', style: TextStyle(color: AppColors.primaryContainer, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Confirm the pairing',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1.1),
              ),
              const SizedBox(height: 48),
              
              // Code Display mock TV
              SizedBox(
                height: 200,
                width: double.infinity,
                child: GlassPanel(
                   child: Center(
                     child: Container(
                       width: 260,
                       height: 150,
                       decoration: BoxDecoration(
                         color: AppColors.surfaceContainerLowest,
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: const [
                               _CodeBox('8'),
                               SizedBox(width: 8),
                               _CodeBox('2'),
                               SizedBox(width: 8),
                               _CodeBox('4'),
                               SizedBox(width: 8),
                               _CodeBox('9'),
                             ],
                           ),
                           const SizedBox(height: 16),
                           Text('VERIFY CODE ON TV', style: TextStyle(color: AppColors.onSurfaceVariant.withOpacity(0.6), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w500)),
                         ],
                       ),
                     )
                   ),
                )
              ),
              
              const SizedBox(height: 48),
              const Text(
                'To connect your TV you will need to confirm the pairing request.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                blur: 10,
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primaryContainer, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14, height: 1.5),
                          children: [
                            TextSpan(text: "Depending on your model, you may need to: "),
                            TextSpan(text: "Press 'OK'", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            TextSpan(text: " on the pop-up that appears, or enter the "),
                            TextSpan(text: "numeric code", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            TextSpan(text: " shown above."),
                          ]
                        ),
                      )
                    )
                  ],
                ),
              ),
              const Spacer(),
              GradientButton(
                onPressed: () => Navigator.pushNamed(context, '/setup/3'),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sync, color: AppColors.onPrimary),
                    SizedBox(width: 12),
                    Text('Connect Now', style: TextStyle(color: AppColors.onPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text("WAITING FOR RESPONSE...", style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String code;
  const _CodeBox(this.code);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surfaceBright.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      alignment: Alignment.center,
      child: Text(code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryContainer)),
    );
  }
}
