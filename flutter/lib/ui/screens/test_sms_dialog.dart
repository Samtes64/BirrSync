import 'package:flutter/material.dart';
import '../../database/queue_db.dart';
import '../../parser/telebirr_parser.dart';
import '../../services/sync_service.dart';

class TestSmsDialog extends StatefulWidget {
  final VoidCallback onParsed;

  const TestSmsDialog({super.key, required this.onParsed});

  @override
  State<TestSmsDialog> createState() => _TestSmsDialogState();
}

class _TestSmsDialogState extends State<TestSmsDialog> {
  late TextEditingController _senderController;
  late TextEditingController _bodyController;
  ParsedReceipt? _parsedResult;
  String? _parseError;

  final Map<String, Map<String, String>> _templates = {
    'Telebirr (English)': {
      'sender': '127',
      'body':
          'You have received ETB 490.00 from Abebe Kebede(2519****4819). Your transaction number is DJD1R7KTJJ.',
    },
    'Telebirr (Amharic)': {
      'sender': '127',
      'body':
          '490.00 ብር ከ Abebe Kebede(2519****4819) ገቢ ተደርጎልዎታል:: የግብይት ቁጥርዎ DJD1R7KTJJ ነው::',
    },
    'CBE Mobile Banking': {
      'sender': 'CBE',
      'body':
          'Dear Customer You have received ETB 2,040.00 from account 1**9482 (Abebe Kebede) to your account 1**2233. Your current balance is ETB5,272.12. Thanks for Banking with CBE. https://mbreciept.cbe.com.et/v2-hfHCxHC6unkKSXCtrNI1  for feedback: https://forms.gle/kGNGQpG3mQCCk3iD6',
    },
    'CBE Ref Deposit': {
      'sender': 'CBE',
      'body':
          'Your account credited with ETB 750.00 by Dawit Kebede. Ref: FT2410290001.',
    },
  };

  @override
  void initState() {
    super.initState();
    _senderController = TextEditingController(text: '127');
    _bodyController = TextEditingController(
      text: _templates['Telebirr (English)']!['body'],
    );
  }

  @override
  void dispose() {
    _senderController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _applyTemplate(String templateName) {
    final t = _templates[templateName]!;
    setState(() {
      _senderController.text = t['sender']!;
      _bodyController.text = t['body']!;
      _parsedResult = null;
      _parseError = null;
    });
  }

  void _testParse() {
    setState(() {
      _parseError = null;
      _parsedResult = null;
    });

    final sender = _senderController.text.trim();
    final body = _bodyController.text.trim();

    if (body.isEmpty) {
      setState(() => _parseError = 'SMS text cannot be empty');
      return;
    }

    final result = parseReceipt(
      sender,
      body,
      DateTime.now().millisecondsSinceEpoch,
    );

    if (result == null) {
      setState(() => _parseError =
          'Parser could not identify transaction ID or amount. Check pattern.');
    } else {
      setState(() => _parsedResult = result);
    }
  }

  Future<void> _saveAndSync() async {
    if (_parsedResult == null) return;

    final inserted =
        await QueueDatabase.instance.insertTransaction(_parsedResult!);
    if (inserted) {
      await SyncService.syncPendingQueue();
      widget.onParsed();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Inserted & synced txn ${_parsedResult!.transactionId}!'),
            backgroundColor: const Color(0xFF0D5C3A),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction already exists in local database'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Test SMS Receipt Parser'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: _templates.keys.map((name) {
                return ActionChip(
                  label: Text(name, style: const TextStyle(fontSize: 11)),
                  onPressed: () => _applyTemplate(name),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _senderController,
              decoration: const InputDecoration(
                labelText: 'SMS Sender (e.g. 127 or CBE)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'SMS Receipt Body',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _testParse,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Parse SMS'),
            ),
            if (_parseError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade50,
                child: Text(
                  _parseError!,
                  style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                ),
              ),
            ],
            if (_parsedResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Provider: ${_parsedResult!.provider}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Txn ID: ${_parsedResult!.transactionId}'),
                    Text('Amount: ETB ${_parsedResult!.amount.toStringAsFixed(2)}'),
                    if (_parsedResult!.senderName != null)
                      Text('Sender: ${_parsedResult!.senderName}'),
                    if (_parsedResult!.phoneSuffix != null)
                      Text('Phone Suffix: ${_parsedResult!.phoneSuffix}'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_parsedResult != null)
          ElevatedButton(
            onPressed: _saveAndSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D5C3A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Insert & Sync'),
          ),
      ],
    );
  }
}
