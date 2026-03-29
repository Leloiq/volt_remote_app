import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/remote_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/glass_panel.dart';

class SetupStep2Screen extends StatefulWidget {
  const SetupStep2Screen({super.key});

  @override
  State<SetupStep2Screen> createState() => _SetupStep2ScreenState();
}

class _SetupStep2ScreenState extends State<SetupStep2Screen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Automatically start pairing when this screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPairing();
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentPin => _controllers.map((c) => c.text).join();

  /// Initiate pairing — opens TLS to TV port 6467, TV shows code on screen.
  Future<void> _startPairing() async {
    final provider = context.read<RemoteProvider>();
    final device = provider.tempDevice;
    if (device == null) return;

    final success = await provider.startPairing(device);
    if (!success && mounted) {
      setState(() {
        _errorMessage = 'Could not start pairing. Is the TV on?';
      });
    }
  }

  /// Submit the 6-digit code shown on the TV.
  Future<void> _handleConnect() async {
    final pin = _currentPin;
    if (pin.length < 6) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final provider = context.read<RemoteProvider>();
    final success = await provider.submitPairingCode(pin);

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        Navigator.pushNamed(context, '/setup/3');
      } else {
        setState(() {
          _errorMessage = 'Invalid code. Check your TV and try again.';
          // Clear the input fields
          for (var c in _controllers) {
            c.clear();
          }
          _focusNodes[0].requestFocus();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RemoteProvider>();

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
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                'Enter pairing code',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1.1),
              ),
              const SizedBox(height: 12),

              // Connection method indicator
              if (provider.pairingStarted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Connected via TLS • TV is showing code',
                        style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else if (provider.isPairing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                      SizedBox(width: 8),
                      Text(
                        'Connecting to TV...',
                        style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 36),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // PIN Input Area
              SizedBox(
                height: 120,
                width: double.infinity,
                child: GlassPanel(
                   child: Center(
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: List.generate(6, (index) => Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 4.0),
                         child: _CodeInputField(
                           controller: _controllers[index],
                           focusNode: _focusNodes[index],
                           onChanged: (value) {
                             if (value.isNotEmpty && index < 5) {
                               _focusNodes[index + 1].requestFocus();
                             } else if (value.isEmpty && index > 0) {
                               _focusNodes[index - 1].requestFocus();
                             }
                             if (_currentPin.length == 6) {
                               _handleConnect();
                             }
                           },
                         ),
                       )),
                     )
                   ),
                )
              ),

              const SizedBox(height: 48),
              const Text(
                'Enter the 6-digit code displayed on your TV screen to securely pair your device.',
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
                            TextSpan(text: "Both devices must be on the "),
                            TextSpan(text: "same WiFi network", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            TextSpan(text: ". The pairing uses "),
                            TextSpan(text: "encrypted TLS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            TextSpan(text: " for security."),
                          ]
                        ),
                      )
                    )
                  ],
                ),
              ),
              const SizedBox(height: 48),
              GradientButton(
                onPressed: (_isSubmitting || !provider.pairingStarted) ? null : _handleConnect,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSubmitting)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                    else
                      const Icon(Icons.sync, color: AppColors.onPrimary),
                    const SizedBox(width: 12),
                    Text(_isSubmitting ? 'Verifying...' : 'Connect Now', style: const TextStyle(color: AppColors.onPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isSubmitting)
                const Text("VERIFYING PAIRING CODE...", style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w600)),
              if (!provider.pairingStarted && !provider.isPairing) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _startPairing,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry Connection'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryContainer),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onChanged;

  const _CodeInputField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

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
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.text, // Hex code - allow alphanumeric
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryContainer),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
      ),
    );
  }
}
