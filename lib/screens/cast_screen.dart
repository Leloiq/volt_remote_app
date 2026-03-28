import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_panel.dart';

class CastScreen extends StatelessWidget {
  const CastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  const Icon(Icons.settings_input_component, color: AppColors.primaryContainer),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('VOLT', style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4, color: AppColors.primaryContainer)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white70),
                    onPressed: () {},
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network('https://lh3.googleusercontent.com/aida-public/AB6AXuCNJXKa3xf-1_YtbmCTBavyFgRiKMl9PZE9qu1ilMYtBYH6uQcqo7ubny-uEwlOffpfbyei8uJTj4zyTeVapudBnhVr_1HWZMazEKSaughg8rJJfaIgYvlrZ8lAfj6D7WdDSNTEyM20g2vpqIfKFPAOymqbpPhrdl_pIj1oiDCl4nRvla5cNGkK4xiv9ej6h3Vk83_gzfXY7GY1BPhs_Mc3SvoExRmiRGlNbjCtGOBOQP6B9UdItvHk6U0iladYkNhikmSjVk8zPolj', fit: BoxFit.cover),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Device Card
                    GlassPanel(
                      blur: 10,
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(color: AppColors.surfaceContainerHighest.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.tv, color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ACTIVE DEVICE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white30)),
                                const SizedBox(height: 4),
                                const Text('Living Room TV', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primaryContainer, blurRadius: 8)])),
                                    const SizedBox(width: 8),
                                    const Text('CONNECTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.primary)),
                                  ],
                                )
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.surfaceContainerHighest.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.swap_horiz, color: Colors.white70),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Library
                    Row(
                      children: [
                        const Text('LIBRARY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white30)),
                        const SizedBox(width: 16),
                        Expanded(child: Container(height: 1, color: Colors.white10)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.3,
                      children: const [
                        _CategoryCard(icon: Icons.photo_library, title: 'Photos', subtitle: '1,240 items'),
                        _CategoryCard(icon: Icons.movie, title: 'Videos', subtitle: '45 items'),
                        _CategoryCard(icon: Icons.music_note, title: 'Music', subtitle: '3.2k tracks'),
                        _MirroringCard(),
                      ],
                    ),
                    const SizedBox(height: 40),
                    
                    // Recent Activity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('RECENT ACTIVITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white30)),
                        Text('CLEAR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      height: 160,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        children: const [
                          _ActivityItem(imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuA5NH0y2JoCWH1cOTy_A3MG0fKN3ftxGgYSouRDFiWJitt6Ut3JR6QNiKYfvcA2Q2WcihCR4MYxi3rCTw6-KPdLYSpEsBELs72-thLBCY-dQ65rR9FI6O_3tCVm9Eb4RUrolIDyqmhXG45ppN0UWCHvi9qxe3XJlsyFvhjRg8KBLRAUAXHBGXS0awSCKBYbUKFjZjkWaXwwOVQ3gRZRDJ74ceSjSitoozN1hxYURSaeKvXsRlPYI-76R2LdSzTQVt-QKOUbxCJBNhVh', title: 'Interstellar_4K.mkv', subtitle: 'CAST 2H AGO', badge: '4K'),
                          SizedBox(width: 20),
                          _ActivityItem(imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBC2q1VhKZAiH62Ww2lW0lf86Ooh8fLftPJgTIHabbTg0MCg7ljWjudOiKAFBzkLJO699BPxO3xqSLTKYvbM51G-UT6S_HyPjIqEJr_9JdSYOX3fyhfrswbNJ0yiwoLs39_9CmZbsJ4cLGzc06ppXIrAP0gBq2DHlXk4Qs604njgREDOfSeloEwQg8L0pgtfOQC0QEnwn31BiWQ54dTyy9ufok3I-JrHsl7rITzOB-1fv8euqyxGLAByvLvg7XseOiBp6Z_CvuuBxzi', title: 'Summer Mix 2024', subtitle: 'CAST YESTERDAY', playIcon: true),
                          SizedBox(width: 20),
                          _ActivityItem(imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCB1IPS3Y-bFx3CXcE64NDvieKMPHvxH8fZd3GHIFJKVVG4A6OGH6BF1i0um9QOxB7x1IBahbdOc4kZtAceJ2GJKZUbHeJcbxQ6jLq2AZdCFh6XwYHH1MzH4rhzOkn-KwdzgU4INrZ14H2No4ZpKUsgqOqJrkrUT5DhXOvCY9iT8cwxQv9u_9KGSE5T7NL8yg7V6kG76iTpq3DtVw-rbNJZFYhpj4RXbytLGoW_j-Y69-1dVlxsqeOLoDZZO2rtymr2ry3rS5K-kzz5', title: 'Deep Space Slideshow', subtitle: 'CAST 3D AGO'),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primaryContainer]),
            boxShadow: [BoxShadow(color: AppColors.primaryContainer.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 8))],
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CategoryCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const Spacer(),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1, color: Colors.white38)),
        ],
      ),
    );
  }
}

class _MirroringCard extends StatelessWidget {
  const _MirroringCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary.withOpacity(0.1), Colors.transparent]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.screen_share, color: AppColors.primaryContainer, size: 28),
          const Spacer(),
          const Text('Mirroring', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('START NOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String? badge;
  final bool playIcon;

  const _ActivityItem({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.badge,
    this.playIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 99, // 16:9 aspect ratio for 176 width
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(imageUrl, fit: BoxFit.cover),
                Container(color: Colors.black26),
                if (badge != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                      child: Text(badge!, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                if (playIcon)
                  const Center(child: Icon(Icons.play_circle, color: Colors.white60, size: 32)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 9, letterSpacing: 2, color: Colors.white30)),
        ],
      ),
    );
  }
}
