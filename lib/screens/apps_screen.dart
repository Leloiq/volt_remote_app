import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_panel.dart';

class AppsScreen extends StatelessWidget {
  const AppsScreen({super.key});

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
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white70),
                    onPressed: () {},
                  ),
                  const Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.settings_input_component, color: AppColors.primaryContainer),
                        SizedBox(width: 8),
                        Text('VOLT', style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4, color: AppColors.primaryContainer)),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network('https://lh3.googleusercontent.com/aida-public/AB6AXuBRBT63ChORftKBUAP5ZEzMiRz6TIVzOPV4RvgGScezNrDYMyAx4fvTwHTVM2I6MimEtVhjYYo_C0IxSEh0CQvcXexpXOetL3eIhbfFIXnfvU5C10S2hNsgH2yF-HUrCDdkkihagMmz8T9DOC6dMUAywDO1cdcyUgI8aS-kil1OU-b-J3XD6Ph4ZB5b1pcTdrtYj86KKiDRc_vaqV3UsMChsiZiamYubykHP_UCPMmQe5U5KwbgyYVaHiTyegaRdT_hQLDRBKxr2jC7', fit: BoxFit.cover),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100), // padding for bottom nav
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: const [
                          Icon(Icons.search, color: Colors.white30, size: 20),
                          SizedBox(width: 12),
                          Text('Search apps, services...', style: TextStyle(color: Colors.white24, fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Spotlight Header
                    Row(
                      children: [
                        const Text('SPOTLIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white30)),
                        const SizedBox(width: 16),
                        Expanded(child: Container(height: 1, color: Colors.white10)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Spotlight Grid
                    SizedBox(
                      height: 280,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _SpotlightCard(
                              imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuB8OMukGiN19iQz_3U2wCDStd4KOJhPYIH9TF4MGsWlFABDJuq6qzCM-GPctniIso8pYeXFeSr9wO_rKui6QqQERpd75gqrV__cKpM8mmj4wP223GfWPLcz1fFT_4VGE4Q3Y5wiUYIK_3FJ11EnxHHAoTlxOHtIrehjYvvy7M685sC5FRhUXxxWroJCm_Xp6F2PSDGLoy_EvPHvGyYP8KEieGHquaNWHrSimsLXIiKE7hWxBM_sS1y0wH-mNlPXVVsaBbFyLsWEqkR2',
                              title: 'NEBULA',
                              subtitle: 'Spatial streaming engine update.',
                              badge: '4K',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                Expanded(child: _SmallFeaturedCard(icon: Icons.bolt, iconColor: AppColors.primary, title: 'Live', subtitle: 'Sports')),
                                const SizedBox(height: 16),
                                Expanded(child: _SmallFeaturedCard(icon: Icons.music_note, iconColor: Colors.white30, title: 'Audio', subtitle: 'Lossless')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Library Header
                    const Text('LIBRARY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white30)),
                    const SizedBox(height: 16),
                    
                    // App Grid
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.8,
                      children: [
                        const _AppIcon(name: 'Apple TV', bgColors: [Color(0xFF333333), Colors.black], imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCiA4EZcyfTIu7OT4GvsChFkKdk3Prz5B4wJ6raTdyAwb7UXklGokzLhTHdBOTOA_bkBFzvb3pTflLIKxji0ghOyTuAgL8ynuDd7erN2STXOF3-7xBwNHQxqvwj4NVZV6Lc6cXn17WuWDki1-q7iyQ9p7-XVBX0D_coiovlQe4-rnNpLQdbK6Y07OWwuyhGFB-oPxLXkDByy7wu1uJgFrJozUjRVZIyuKz2bWWtoWapS-9r-56bMFvNZ7e-XcV5w9j7hib1XPuOewYd', isFav: true, active: true),
                        const _AppIcon(name: 'Disney+', bgColors: [Color(0xFF020731), Color(0xFF0D1D61)], imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDIXjeSm7CFmv9F7somLoyWSDjxRndUmI6dnVSRsw374h4vIYjaVFbRNZifHeaZFibDQ5CVdepW-xBjavwrTCttJCzViskaYm-dH6ZQp9nYfxtB1qAVEB4yTUqX1uHf6tZlZoKXTGgfMdnYjyuypBpWTk5Y0Gya_eVqRRS7AdX8zeXHO8V9oF_LD2rPtQPslQbiZaHIcFwQyUSgYuMUPfuaxLsUHa6tPIlA8iXgmmxaLlYhcsFqJcyihSzD_JjzWs8uTfCLb1LSfYxy', isFav: true),
                        const _AppIcon(name: 'Netflix', bgColors: [Colors.black, Colors.black], imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDavRhTH5VyAMepzpPyMOdmtYar8EwHf0H7A6fI3dTVdh5jUPhGd-Z9ac_1PfAyCCitWxQmR7eAaAEQHRmXrs_JPPwm6-UjByDdlWRBSF7jWQRhom_jqidl6hMj2Gs5Q2u4KBOGxhU3TGeH2-8eQ1Fw0oDZZRnmFGWzpZ5SfUI65JbvoHBfe-2aakX4v_UCJjsL_qNc68HmQuDjL4L_iiyjyWTj7eNFgyAkiiXbQ2L8qJr9AQDkfWJXjEc7oniOWF8bIy-Qo87BKn3F', isFav: true),
                        const _AppIcon(name: 'App Store', bgColors: [Color(0xFF34A8FF), Color(0xFF007AFF)], imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCXePOLIIMNl2v9yH21EUkX6sio8kM94LtroZcFwjjNDSpWhbekJP_3DqaCQEP-Oe-SG1evP8QOj7PjyhNSNA9jWKmxJJWIYyrAPmw-liS0SOfmdZ-53GgEj8YRROlfG2123buoP6SS93tou_zayVi_CxBpUxD5SYJ87v5ELT9jBhVzOKifufpyEB0IDOKYepSEHa4pXHrNcKnDZqQCnhtU9CVoW5kwImJ5e6WLJkVnx6ap645Q1ig1SupHzOKa66gcI8tJEKgYF5td', isFav: true),
                        const _AppIcon(name: 'Spotify', bgColors: [Color(0xFF191414), Color(0xFF191414)], imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD2R8lRuJlmN3_muedO3uer2qdfmLWgpl5MA_Cq1PpmvsfGV0MxFqeUZkgwG-RVF8EYufZJRTTp3qBdWE2hfB2sgA9TG2xP1ifTfUMsw8RC8V73o7YX2Qrz-_L9otmqTUtCf-U0vyJeInsBBekCeTTzc3uTeZreuEn-FVZz3OBnDHsPMkx75cKZsDGibedogBpJd0jCo9vjnHaCm2Im8kyRolYr7_bhr7PvA4NSe8SDPlOw9iq8Rh9A5KHB0GqyXYmIqNYjA_ztLya9', isFav: true),
                        const _AppIcon(name: 'Max', bgColors: [Color(0xFF002BE7), Color(0xFF002BE7)], imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuATYXDJGYgDQpY-NAVMkAbMKClHhDz365CUL_ojPv8eC0g2h4RivqyU3ZOTgWZI5M37Sop6Ukqhjx6OA_EBxNoqv98NzvbSEGlDK4cChpEGpZRWRIg3noOolftkKA1jnpMfSFcOIJMSszRbKvWG4Aw-8Aw0mPR_FL6dzn4CFsYvqIQl0yhIebGTrpSixPN15mpZqZRqnK8TMAXfq-scOdwPKr92DWPPk7pl22lNJ0D-x8cy2BRaC0RnK7qglQvjIkDc85TEg-FkDGY5', isFav: true),
                        const _AppIcon(name: 'YouTube', bgColors: [Colors.white, Colors.white], imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBdqJybyQKHOiFI-iRnJ9xWfMiGULJQ3doBMjaDo6L8hqhpLo9t9EiioufL-UVCWrdgdrSZ7NxbdyaV9m7zCo-BfLuXFAS96sUQLEnCButku2QVDay0qBoQhMG9uF4voJ3dNzLhMyiPZDkxRAfuSTvR82XeDiSIRARgRid_OP66gW-Jon-YDuJ0NIsN0zk0bhG3jSs_EzGEC9S30CMZ7hb3-4v5LYaC-SfFdq-Guo9sCa8kx3_U-n1Sub3H_AlIwFkJC8-j4WOcrpZn', isFav: true, isLight: true),
                        const _AppIcon(name: 'Hulu', bgColors: [Colors.black, Colors.black], imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAPJ72_28bABngLXB177xolGghf2JpU8VIYonCRSgiebIfq4waf7hgtJLWJmcjZUT6NudkuT8ic-wuUpuyjhims-xIzn8y16eOxfjfDcrUzf3WtYEgxTlIdTi6O4lCrZKEUNI4fkQFVu1CQz1hD8dCukRRbujjOeb2IQWyK080DMjiIAr927ztfa9IH16cLvx5z0c1nYE-us-PD9fVltmVH0EYO6NzTAiplagVVzJpuvlndTVl7jwZcCJtosh-BT_Canm_Li4NLv6Ef', isFav: true),
                        // Add Placeholder
                        Column(
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white24, style: BorderStyle.solid), // Faking dashed
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(Icons.add, color: Colors.white24, size: 32),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('ADD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white30)),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String badge;

  const _SpotlightCard({required this.imageUrl, required this.title, required this.subtitle, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(imageUrl, fit: BoxFit.cover, opacity: const AlwaysStoppedAnimation(0.6)),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black, Colors.transparent],
                stops: [0.0, 0.6],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(4)),
                  child: Text(badge, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                ),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallFeaturedCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _SmallFeaturedCard({required this.icon, required this.iconColor, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.white38)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final String name;
  final List<Color> bgColors;
  final String imageUrl;
  final bool isFav;
  final bool active;
  final bool isLight;

  const _AppIcon({
    required this.name,
    required this.bgColors,
    required this.imageUrl,
    this.isFav = false,
    this.active = false,
    this.isLight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bgColors),
              boxShadow: active ? [BoxShadow(color: AppColors.primaryContainer.withOpacity(0.4), blurRadius: 20)] : null,
            ),
            child: Stack(
              children: [
                Center(child: Image.network(imageUrl, width: 48, height: 48)),
                if (isFav)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(Icons.star, color: AppColors.primary, size: 12, shadows: [Shadow(color: AppColors.primary, blurRadius: 4)]),
                  ),
                if (active)
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 2,
                        decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: AppColors.primaryContainer, blurRadius: 4)]),
                      ),
                    ),
                  )
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name.toUpperCase(),
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, color: active ? Colors.white : Colors.white54),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
