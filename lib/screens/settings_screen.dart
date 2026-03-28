import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_panel.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryContainer),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: AppColors.primaryContainer),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                  image: DecorationImage(
                    image: const NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuBcm6DCnIxZQmtlo6mW8EC_WP7NLKdrf6cEj5WcKs12iWYkg_g1yJkUkaAczBLiRzDdFe3L5axfJUo5_1pGHW_CSoKMt11tZ5FUI2lamgDqq9Ch4DSHqVEC2pSnNAPGFWxNX5b6Nc3Inqpz7t2QLjaEtwBkmoUu61gp3nfjVe3spZ7BGN3m01ElF47WlT8iOLCPdJUzKGl1OQDee-I5G66qvsWYSqlUxg8b2kHHQDr2AMElO4usDWPIquRqIz4-3NCraEM3bC3M2n_I'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.8), BlendMode.darken),
                  )
                ),
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primaryContainer, width: 2),
                            image: const DecorationImage(
                                image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuBcm6DCnIxZQmtlo6mW8EC_WP7NLKdrf6cEj5WcKs12iWYkg_g1yJkUkaAczBLiRzDdFe3L5axfJUo5_1pGHW_CSoKMt11tZ5FUI2lamgDqq9Ch4DSHqVEC2pSnNAPGFWxNX5b6Nc3Inqpz7t2QLjaEtwBkmoUu61gp3nfjVe3spZ7BGN3m01ElF47WlT8iOLCPdJUzKGl1OQDee-I5G66qvsWYSqlUxg8b2kHHQDr2AMElO4usDWPIquRqIz4-3NCraEM3bC3M2n_I'),
                                fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.verified, color: AppColors.onPrimary, size: 14),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Julian Carboni', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(4)),
                          child: const Text('PREMIUM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.onPrimary)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Device & Connectivity
              GlassPanel(
                blur: 20,
                opacity: 0.4,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.connected_tv, color: AppColors.primary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: const Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Living Room TV', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Sony Bravia OLED • 4K HDR', style: TextStyle(fontSize: 12, color: Colors.white38)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.wifi, color: AppColors.primary),
                        ),
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primaryContainer, blurRadius: 4)])),
                            const SizedBox(width: 4),
                            const Text('5.0 GHz', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white60)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('TV I POINT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Paired via Carbon Bridge', style: TextStyle(fontSize: 12, color: Colors.white38)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Interactive Feedback
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('INTERACTIVE FEEDBACK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white30)),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                padding: const EdgeInsets.all(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.vibration, color: Colors.white60),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(child: Text('Haptic Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
                      Switch(
                        value: true,
                        onChanged: (v) {},
                        activeColor: Colors.white,
                        activeTrackColor: AppColors.primaryContainer,
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // System Config
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('SYSTEM CONFIG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white30)),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: const [
                    _ConfigRow(icon: Icons.translate, title: 'Language', value: 'English (US)', showChevron: true),
                    _ConfigRow(icon: Icons.info_outline, title: 'App Version', value: 'v4.8.2-stable', showChevron: false),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Support
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
                      child: Column(
                        children: const [
                          Icon(Icons.help_center, color: AppColors.primary),
                          SizedBox(height: 12),
                          Text('HELP CENTER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
                      child: Column(
                        children: const [
                          Icon(Icons.bug_report, color: Colors.white38),
                          SizedBox(height: 12),
                          Text('REPORT ISSUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Footer
              Center(
                child: Column(
                  children: const [
                    Icon(Icons.layers, color: Colors.white24, size: 24),
                    SizedBox(height: 8),
                    Text('ENGINEERED BY CARBON DYNAMICS © 2024', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 3, color: Colors.white24)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool showChevron;

  const _ConfigRow({required this.icon, required this.title, required this.value, required this.showChevron});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70))),
          Text(value, style: const TextStyle(fontSize: 14, color: Colors.white60)),
          if (showChevron) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ]
        ],
      ),
    );
  }
}
