import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/glass_panel.dart';
import '../../providers/remote_provider.dart';

class SetupStep1Screen extends StatelessWidget {
  const SetupStep1Screen({super.key});

  void _showDiscoverySheet(BuildContext context) {
    final provider = context.read<RemoteProvider>();
    provider.startScan();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return Consumer<RemoteProvider>(
          builder: (context, ref, child) {
            return Container(
              padding: const EdgeInsets.all(24.0),
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select your TV', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(ref.isScanning ? 'Scanning local network...' : 'Scan complete', style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 24),
                  
                  if (ref.isScanning && ref.discoveredDevices.isEmpty)
                    const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primaryContainer)))
                  else if (ref.discoveredDevices.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.tv_off, color: Colors.white24, size: 48),
                            const SizedBox(height: 16),
                            const Text('No TVs found', style: TextStyle(color: Colors.white60)),
                            TextButton(
                              onPressed: () => provider.startScan(),
                              child: const Text('RETRY', style: TextStyle(color: AppColors.primaryContainer)),
                            )
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: ref.discoveredDevices.length,
                        itemBuilder: (context, index) {
                          final device = ref.discoveredDevices[index];
                          return ListTile(
                            leading: const Icon(Icons.tv, color: AppColors.primary),
                            title: Text(device.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('\${device.ip} • \${device.brand.name}', style: const TextStyle(color: Colors.white38)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                            onTap: () async {
                              Navigator.pop(context); // close sheet
                              
                              // Proceed to connect and handle pairing
                              final success = await provider.connectToDevice(device);
                              if (context.mounted) {
                                if (success) {
                                  Navigator.pushNamed(context, '/setup/3');
                                } else if (provider.tempDevice != null) {
                                  // Device requires pairing - go to Step 2
                                  Navigator.pushNamed(context, '/setup/2');
                                } else {
                                  // Show error
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Failed to connect. Please ensure TV is on and on the same WiFi.')),
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() => provider.stopScan());
  }

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
                child: const Text('STEP 1', style: TextStyle(color: AppColors.primaryContainer, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Make sure your TV is on',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1.1),
              ),
              const SizedBox(height: 48),
              // Glass TV Illustration
              SizedBox(
                height: 200,
                width: double.infinity,
                child: GlassPanel(
                   child: Center(
                     // Content inside the glass panel (mock TV)
                     child: Container(
                       width: 260,
                       height: 150,
                       decoration: BoxDecoration(
                         color: AppColors.surfaceContainerLowest,
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Stack(
                         alignment: Alignment.center,
                         children: [
                           Positioned(
                             bottom: 16,
                             child: Container(
                               width: 10,
                               height: 10,
                               decoration: const BoxDecoration(
                                 color: AppColors.primaryContainer,
                                 shape: BoxShape.circle,
                                 boxShadow: [BoxShadow(color: AppColors.primaryContainer, blurRadius: 12)],
                               ),
                             ),
                           )
                         ],
                       ),
                     )
                   ),
                )
              ),
              const SizedBox(height: 48),
              const Text(
                'Every TV has a physical power button, usually located underneath the screen or on the back side of the TV.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
              ),
              const Spacer(),
              GradientButton(
                onPressed: () => _showDiscoverySheet(context),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Find Devices', style: TextStyle(color: AppColors.onPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(width: 12),
                    Icon(Icons.search, color: AppColors.onPrimary),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _showManualIpDialog(context),
                child: const Text("ENTER TV IP MANUALLY", style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualIpDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Manual IP Entry', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. 192.168.1.50',
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryContainer)),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final ip = controller.text.trim();
              if (ip.isNotEmpty) {
                Navigator.pop(context);
                context.read<RemoteProvider>().addManualDevice(ip);
                // The provider will handle navigation to pairing if needed
              }
            },
            child: const Text('CONNECT', style: TextStyle(color: AppColors.primaryContainer)),
          ),
        ],
      ),
    );
  }
}

