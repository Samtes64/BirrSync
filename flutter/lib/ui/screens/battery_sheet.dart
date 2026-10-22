import 'package:flutter/material.dart';

class BatteryGuideSheet extends StatelessWidget {
  const BatteryGuideSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.battery_alert, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    const Text(
                      'Background Survival Guide',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Android manufacturers (especially Tecno, Infinix, Samsung, and Xiaomi) aggressively terminate background services when the screen is locked.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            _buildOemTile(
              title: '1. General Android (All Phones)',
              bullets: const [
                'Go to Settings > Apps > BirrSync Agent > Battery.',
                'Select "Unrestricted" (Don\'t optimize).',
                'Enable "Background Data" and "Unrestricted Data".',
                'Lock BirrSync Agent in the Recent Apps overview.',
              ],
            ),
            const SizedBox(height: 12),
            _buildOemTile(
              title: '2. Transsion (Tecno / Infinix / itel)',
              bullets: const [
                'Open pre-installed "Phone Master" app.',
                'Go to Toolbox > Auto-start management.',
                'Toggle BirrSync Agent to ON.',
                'In Power Marathon / Battery Lab, disable "Screen off sleep".',
              ],
            ),
            const SizedBox(height: 12),
            _buildOemTile(
              title: '3. Xiaomi / Redmi / POCO',
              bullets: const [
                'Settings > Apps > Permissions > Autostart > Enable BirrSync.',
                'Settings > Manage Apps > BirrSync > Battery Saver > "No restrictions".',
                'Security App > Boost Speed > Lock apps > Enable BirrSync.',
              ],
            ),
            const SizedBox(height: 12),
            _buildOemTile(
              title: '4. Samsung (One UI)',
              bullets: const [
                'Settings > Battery & device care > Battery > Background usage limits.',
                'Add BirrSync Agent to "Never sleeping apps".',
                'Turn off "Adaptive battery".',
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C3A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('I Understand, Keep Service Running'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOemTile({
    required String title,
    required List<String> bullets,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
