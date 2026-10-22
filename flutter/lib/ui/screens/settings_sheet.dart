import 'package:flutter/material.dart';
import '../../services/sync_service.dart';

class SettingsSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const SettingsSheet({super.key, required this.onSaved});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _urlController;
  late TextEditingController _gatewayIdController;
  late TextEditingController _secretController;
  bool _obscureSecret = true;
  bool _isTesting = false;
  String? _testStatusMessage;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _gatewayIdController = TextEditingController();
    _secretController = TextEditingController();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final cfg = await SyncService.getConfig();
    setState(() {
      _urlController.text = cfg['serverUrl'] ?? '';
      _gatewayIdController.text = cfg['gatewayId'] ?? '';
      _secretController.text = cfg['gatewaySecret'] ?? '';
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _gatewayIdController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testStatusMessage = null;
      _testSuccess = null;
    });

    final res = await SyncService.testConnection(
      serverUrl: _urlController.text,
      gatewayId: _gatewayIdController.text,
      gatewaySecret: _secretController.text,
    );

    setState(() {
      _isTesting = false;
      _testSuccess = res.success;
      _testStatusMessage = res.message;
    });
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    await SyncService.saveConfig(
      serverUrl: _urlController.text,
      gatewayId: _gatewayIdController.text,
      gatewaySecret: _secretController.text,
    );

    widget.onSaved();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gateway configuration saved!'),
          backgroundColor: Color(0xFF0D5C3A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gateway Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Server Base URL',
                  hintText: 'https://gateway.yourdomain.com:8080',
                  prefixIcon: Icon(Icons.dns_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Server URL is required';
                  }
                  if (!val.startsWith('http://') && !val.startsWith('https://')) {
                    return 'URL must begin with http:// or https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gatewayIdController,
                decoration: const InputDecoration(
                  labelText: 'Gateway Device ID',
                  hintText: 'gateway_agent_01',
                  prefixIcon: Icon(Icons.phone_android_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Gateway ID is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _secretController,
                obscureText: _obscureSecret,
                decoration: InputDecoration(
                  labelText: 'Gateway Secret Key (HMAC-SHA256)',
                  hintText: 'Secret key configured on Go server',
                  prefixIcon: const Icon(Icons.key_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSecret ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureSecret = !_obscureSecret;
                      });
                    },
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Secret key is required';
                  }
                  return null;
                },
              ),
              if (_testStatusMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testSuccess == true
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _testSuccess == true
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess == true
                            ? Icons.check_circle
                            : Icons.error_outline,
                        color: _testSuccess == true
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testStatusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _testSuccess == true
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isTesting ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isTesting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test Connection'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D5C3A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
