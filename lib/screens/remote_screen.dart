import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/volt_app_bar.dart';
import '../../providers/remote_provider.dart';
import '../../models/remote_command.dart';
import '../../models/tv_device.dart';

class RemoteScreen extends StatelessWidget {
  const RemoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final remote = context.read<RemoteProvider>();
    
    return Scaffold(
      appBar: VoltAppBar(
        leading: const SizedBox.shrink(), // Ensure title centers
        actions: [
          _IconButton(
            icon: Icons.mic,
            color: AppColors.primary,
            onPressed: () => Navigator.pushNamed(context, '/voice-search'),
          ),
          const SizedBox(width: 12),
          _IconButton(
            icon: Icons.cast,
            color: AppColors.primary,
            bgHighlight: true,
            onPressed: () {},
          ),
          const SizedBox(width: 12),
          _IconButton(
            icon: Icons.power_settings_new,
            color: AppColors.error,
            borderColor: AppColors.error.withOpacity(0.2),
            onPressed: () => remote.sendCommand(RemoteCommand.power),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100), // padding for bottom nav
          child: Column(
            children: [
              // Connection Status Indicator
              Consumer<RemoteProvider>(
                builder: (context, provider, child) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: provider.isConnected ? AppColors.primaryContainer.withOpacity(0.1) : AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: provider.isConnected ? AppColors.primaryContainer.withOpacity(0.3) : Colors.white10)
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: provider.isConnected ? AppColors.primaryContainer : Colors.white30,
                            boxShadow: provider.isConnected ? [BoxShadow(color: AppColors.primaryContainer, blurRadius: 8)] : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          provider.isConnected
                              ? '${provider.activeDevice?.brand.name.toUpperCase() ?? ''} • ${provider.activeDevice?.name ?? 'CONNECTED'}'
                              : 'NOT CONNECTED',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2,
                            color: provider.isConnected ? AppColors.primary : Colors.white54
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              // Touchpad Section
              Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(56),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 60, offset: const Offset(0, 30)),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rings
                      Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary.withOpacity(0.08)))),
                      Container(width: 195, height: 195, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary.withOpacity(0.08)))),
                      Container(width: 135, height: 135, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary.withOpacity(0.08)))),
                      
                      // Core
                      GestureDetector(
                        onTap: () => remote.sendCommand(RemoteCommand.enter),
                        child: Container(
                          width: 96, height: 96, 
                          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1)),
                          alignment: Alignment.center,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryContainer,
                              boxShadow: [BoxShadow(color: AppColors.primaryContainer.withOpacity(0.5), blurRadius: 20)],
                            ),
                          ),
                        ),
                      ),
                      
                      // Arrows
                      Positioned(top: 12, child: IconButton(icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 36), onPressed: () => remote.sendCommand(RemoteCommand.up))),
                      Positioned(bottom: 12, child: IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 36), onPressed: () => remote.sendCommand(RemoteCommand.down))),
                      Positioned(left: 12, child: IconButton(icon: const Icon(Icons.keyboard_arrow_left, color: Colors.white54, size: 36), onPressed: () => remote.sendCommand(RemoteCommand.left))),
                      Positioned(right: 12, child: IconButton(icon: const Icon(Icons.keyboard_arrow_right, color: Colors.white54, size: 36), onPressed: () => remote.sendCommand(RemoteCommand.right))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Bottom Controls Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Volume Column
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: [
                        _TactileButton(icon: Icons.volume_off, onPressed: () => remote.sendCommand(RemoteCommand.mute)),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onVerticalDragEnd: (details) {
                           if (details.primaryVelocity! < 0) {
                             remote.sendCommand(RemoteCommand.volumeUp);
                           } else if (details.primaryVelocity! > 0) {
                             remote.sendCommand(RemoteCommand.volumeDown);
                           }
                          },
                          child: Container(
                          width: 56,
                          height: 112,
                          decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: Colors.black),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () => remote.sendCommand(RemoteCommand.volumeUp),
                                  onLongPressStart: (_) => remote.startRepeat(RemoteCommand.volumeUp),
                                  onLongPressEnd: (_) => remote.stopRepeat(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(Icons.add, color: Colors.white54, size: 16),
                                  ),
                                ),
                                Container(height: 2, width: 32, decoration: BoxDecoration(color: AppColors.primaryContainer, boxShadow: [BoxShadow(color: AppColors.primaryContainer.withOpacity(0.5), blurRadius: 4)]), margin: const EdgeInsets.symmetric(vertical: 4)),
                                GestureDetector(
                                  onTap: () => remote.sendCommand(RemoteCommand.volumeDown),
                                  onLongPressStart: (_) => remote.startRepeat(RemoteCommand.volumeDown),
                                  onLongPressEnd: (_) => remote.stopRepeat(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(Icons.remove, color: Colors.white54, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('VOL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white38)),
                      ],
                    ),
                  ),
                  
                  // Center Actions
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _BigGradientButton(icon: Icons.play_arrow, colors: const [AppColors.primaryContainer, AppColors.primary], onPressed: () => remote.sendCommand(RemoteCommand.play)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _TactileSquare(icon: Icons.cast, color: AppColors.primary, onPressed: () {})),
                              const SizedBox(width: 12),
                              Expanded(child: _TactileSquare(icon: Icons.widgets, color: AppColors.primary, onPressed: () {})),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _TactileSquare(icon: Icons.home, onPressed: () => remote.sendCommand(RemoteCommand.home))),
                              const SizedBox(width: 12),
                              Expanded(child: _TactileSquare(icon: Icons.undo, onPressed: () => remote.sendCommand(RemoteCommand.back))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _BigGradientButton(
                            icon: Icons.keyboard, 
                            colors: const [AppColors.primaryContainer, Color(0xFFFF8C42)], 
                            height: 64, 
                            iconSize: 28, 
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: AppColors.surfaceContainerLowest,
                                isScrollControlled: true,
                                builder: (context) => Padding(
                                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                  child: TextField(
                                    autofocus: true,
                                    onSubmitted: (text) {
                                      // Real implementation would send text data payload
                                      Navigator.pop(context);
                                    },
                                    decoration: const InputDecoration(
                                      hintText: 'Type on TV...',
                                      contentPadding: EdgeInsets.all(24),
                                      border: InputBorder.none,
                                    ),
                                    style: const TextStyle(color: Colors.white, fontSize: 18),
                                  ),
                                ),
                              );
                            }
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Channel Column
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => remote.sendCommand(RemoteCommand.channelUp),
                          onLongPressStart: (_) => remote.startRepeat(RemoteCommand.channelUp),
                          onLongPressEnd: (_) => remote.stopRepeat(),
                          child: Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: const Icon(Icons.expand_less, color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 48),
                        const Text('CH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white38)),
                        const SizedBox(height: 48),
                        GestureDetector(
                          onTap: () => remote.sendCommand(RemoteCommand.channelDown),
                          onLongPressStart: (_) => remote.startRepeat(RemoteCommand.channelDown),
                          onLongPressEnd: (_) => remote.stopRepeat(),
                          child: Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: const Icon(Icons.expand_more, color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool bgHighlight;
  final Color? borderColor;

  const _IconButton({required this.icon, required this.color, required this.onPressed, this.bgHighlight = false, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgHighlight ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.05)),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}

class _TactileButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  const _TactileButton({required this.icon, required this.onPressed, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white60),
        onPressed: onPressed,
      ),
    );
  }
}

class _TactileSquare extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const _TactileSquare({required this.icon, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: IconButton(
          icon: Icon(icon, color: color ?? Colors.white60),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _BigGradientButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final List<Color> colors;
  final double? height;
  final double iconSize;

  const _BigGradientButton({required this.icon, required this.onPressed, required this.colors, this.height, this.iconSize = 48});

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: [BoxShadow(color: colors.first.withOpacity(0.4), blurRadius: 32, offset: const Offset(0, 12))],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: iconSize),
        onPressed: onPressed,
      ),
    );

    if (height != null) {
      return SizedBox(height: height, child: content);
    }
    return AspectRatio(aspectRatio: 1, child: content);
  }
}
