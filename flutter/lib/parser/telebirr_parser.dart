class ParsedReceipt {
  final String provider;
  final String transactionId;
  final double amount;
  final String? senderName;
  final String? maskedPhone;
  final String? phoneSuffix;
  final int timestamp;
  final String raw;

  ParsedReceipt({
    required this.provider,
    required this.transactionId,
    required this.amount,
    this.senderName,
    this.maskedPhone,
    this.phoneSuffix,
    required this.timestamp,
    required this.raw,
  });

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'transaction_id': transactionId,
        'amount': amount,
        'sender_name': senderName,
        'masked_phone': maskedPhone,
        'phone_suffix': phoneSuffix,
        'device_time': timestamp,
        'raw': raw,
      };

  @override
  String toString() {
    return 'ParsedReceipt($provider, $transactionId, ETB $amount, sender: $senderName, phone/acc: $maskedPhone)';
  }
}

/// Identifies if incoming SMS originates from Telebirr or CBE financial systems
bool isFinancialSender(String sender, String body) {
  final s = sender.toUpperCase();
  final b = body.toLowerCase();

  return s.contains('127') ||
      s.contains('CBE') ||
      b.contains('telebirr') ||
      b.contains('ቴሌብር') ||
      b.contains('ገቢ ተደርጎልዎታል') ||
      b.contains('commercial bank of ethiopia') ||
      b.contains('cbe') ||
      b.contains('mbreciept.cbe.com.et') ||
      b.contains('banking with cbe');
}

/// Parses receipt body into structured data
ParsedReceipt? parseReceipt(String sender, String text, int smsTimestamp) {
  final cleanText = text.replaceAll('\r\n', ' ').replaceAll('\n', ' ').trim();

  // 1. Telebirr Parser (Sender '127' or containing 'telebirr' / 'ቴሌብር' / 'ገቢ ተደርጎልዎታል')
  if (sender.contains('127') ||
      cleanText.toLowerCase().contains('telebirr') ||
      cleanText.contains('ቴሌብር') ||
      cleanText.contains('ገቢ ተደርጎልዎታል')) {
    // Transaction ID:
    // "Your transaction number is DJD1R7KTJJ"
    // "የግብይት ቁጥርዎ DJD1R7KTJJ"
    // "transaction number: DJD1R7KTJJ"
    final txnRegex = RegExp(
      r'(?:transaction\s*number\s*(?:is|:)?|የግብይት\s*ቁጥር(?:ዎ)?(?:\s*ነው)?[:\s]+|txn\s*id[:\s]+)\s*([A-Z0-9]{6,20})',
      caseSensitive: false,
    );
    final txnMatch = txnRegex.firstMatch(cleanText);

    // Amount patterns:
    final amountRegex1 = RegExp(
      r'(?:received|credited(?:\s+with)?)\s+(?:ETB\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    final amountRegex2 = RegExp(
      r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:ብር|ETB)',
      caseSensitive: false,
    );

    final amountRegex3 = RegExp(
      r'ETB\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    final amountMatch = amountRegex1.firstMatch(cleanText) ??
        amountRegex2.firstMatch(cleanText) ??
        amountRegex3.firstMatch(cleanText);

    // Sender Name & Masked Phone: "from Abebe Kebede(2519****4819)" or "ከ Abebe Kebede(2519****4819)"
    final senderRegex = RegExp(
      r'(?:from|ከ)\s+([A-Za-z\s]+?)\s*\(([0-9\*\+]+)\)',
      caseSensitive: false,
    );
    final senderMatch = senderRegex.firstMatch(cleanText);

    if (txnMatch != null && amountMatch != null) {
      final txnId = txnMatch.group(1)!.trim().toUpperCase();
      final amountStr = amountMatch.group(1)!.replaceAll(',', '');
      final amount = double.tryParse(amountStr);

      if (amount != null) {
        String? senderName = senderMatch?.group(1)?.trim();
        String? maskedPhone = senderMatch?.group(2)?.trim();

        // If masked phone was found, extract last 4 digits
        String? phoneSuffix;
        if (maskedPhone != null && maskedPhone.length >= 4) {
          final digitsOnly = maskedPhone.replaceAll(RegExp(r'[^0-9]'), '');
          if (digitsOnly.length >= 4) {
            phoneSuffix = digitsOnly.substring(digitsOnly.length - 4);
          }
        }

        return ParsedReceipt(
          provider: 'TELEBIRR',
          transactionId: txnId,
          amount: amount,
          senderName: senderName,
          maskedPhone: maskedPhone,
          phoneSuffix: phoneSuffix,
          timestamp: smsTimestamp,
          raw: text,
        );
      }
    }
  }

  // 2. Commercial Bank of Ethiopia (CBE) Parser
  if (sender.toUpperCase().contains('CBE') ||
      cleanText.toLowerCase().contains('commercial bank of ethiopia') ||
      cleanText.contains('Banking with CBE') ||
      cleanText.contains('mbreciept.cbe.com.et')) {
    // CBE Transaction ID / Receipt token:
    // Pattern A (Modern mobile banking receipt URL): https://mbreciept.cbe.com.et/v2-hfHCxHC6unkKSXCtrNI1
    final cbeUrlRegex = RegExp(
      r'https?:\/\/mbreciept\.cbe\.com\.et\/([A-Za-z0-9\-_]+)',
      caseSensitive: false,
    );

    // Pattern B (Traditional Ref): Ref: FT2410290001
    final cbeRefRegex = RegExp(
      r'(?:ref|reference|txn\s*id)\s*[:\s]+([A-Za-z0-9\-_]+)',
      caseSensitive: false,
    );

    final urlMatch = cbeUrlRegex.firstMatch(cleanText);
    final refMatch = cbeRefRegex.firstMatch(cleanText);
    final txnId = urlMatch?.group(1)?.trim() ?? refMatch?.group(1)?.trim();

    // Received Amount (capture specifically the received amount, not current balance)
    final amountRegex = RegExp(
      r'(?:received|credited(?:\s+with)?|deposited)\s+(?:ETB\s*)?([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final amountMatch = amountRegex.firstMatch(cleanText);

    // Sender details:
    // Format A: "from account 1**9482 (Abebe Kebede) to your account 1**2233"
    final cbeAccountTransferRegex = RegExp(
      r'from\s+account\s+([0-9\*\+]+)\s*\(([^)]+)\)',
      caseSensitive: false,
    );

    // Format B: "by Dawit Kebede. Ref: FT..."
    final cbeByRegex = RegExp(
      r'(?:by|from)\s+([A-Za-z\s]+?)(?:\.\s*Ref|\s*Ref|\s*to\s*your|\s*on|\s*$)',
      caseSensitive: false,
    );

    final transferMatch = cbeAccountTransferRegex.firstMatch(cleanText);
    final byMatch = cbeByRegex.firstMatch(cleanText);

    String? senderName;
    String? maskedPhone;
    String? phoneSuffix;

    if (transferMatch != null) {
      maskedPhone = transferMatch.group(1)?.trim();
      senderName = transferMatch.group(2)?.trim();
      if (maskedPhone != null) {
        final digits = maskedPhone.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length >= 4) {
          phoneSuffix = digits.substring(digits.length - 4);
        }
      }
    } else if (byMatch != null) {
      senderName = byMatch.group(1)?.trim();
    }

    if (txnId != null && amountMatch != null) {
      final amountStr = amountMatch.group(1)!.replaceAll(',', '');
      final amount = double.tryParse(amountStr);

      if (amount != null) {
        return ParsedReceipt(
          provider: 'CBE',
          transactionId: txnId,
          amount: amount,
          senderName: senderName,
          maskedPhone: maskedPhone,
          phoneSuffix: phoneSuffix,
          timestamp: smsTimestamp,
          raw: text,
        );
      }
    }
  }

  return null;
}
