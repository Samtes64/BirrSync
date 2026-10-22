import 'package:flutter_test/flutter_test.dart';
import 'package:birrsync/parser/telebirr_parser.dart';

void main() {
  group('Telebirr Parser Tests', () {
    test('Parses English Telebirr SMS with masked phone', () {
      const sms =
          'You have received ETB 490.00 from Abebe Kebede(2519****4819). Your transaction number is DJD1R7KTJJ.';
      final parsed = parseReceipt('127', sms, 1729580000000);

      expect(parsed, isNotNull);
      expect(parsed!.provider, equals('TELEBIRR'));
      expect(parsed.transactionId, equals('DJD1R7KTJJ'));
      expect(parsed.amount, equals(490.00));
      expect(parsed.senderName, equals('Abebe Kebede'));
      expect(parsed.maskedPhone, equals('2519****4819'));
      expect(parsed.phoneSuffix, equals('4819'));
    });

    test('Parses Amharic Telebirr receipt', () {
      const sms =
          '490.00 ብር ከ Abebe Kebede(2519****4819) ገቢ ተደርጎልዎታል:: የግብይት ቁጥርዎ DJD1R7KTJJ ነው::';
      final parsed = parseReceipt('127', sms, 1729580000000);

      expect(parsed, isNotNull);
      expect(parsed!.provider, equals('TELEBIRR'));
      expect(parsed.transactionId, equals('DJD1R7KTJJ'));
      expect(parsed.amount, equals(490.00));
      expect(parsed.senderName, equals('Abebe Kebede'));
      expect(parsed.phoneSuffix, equals('4819'));
    });

    test('Parses large amount with commas', () {
      const sms =
          'You have received ETB 1,250.50 from Abebe Bikila(2519****9988). Your transaction number is TXN987654.';
      final parsed = parseReceipt('127', sms, 1729580000000);

      expect(parsed, isNotNull);
      expect(parsed!.amount, equals(1250.50));
      expect(parsed.transactionId, equals('TXN987654'));
      expect(parsed.phoneSuffix, equals('9988'));
    });

    test('Parses Production CBE Mobile Banking SMS with receipt URL and account transfer', () {
      const cbeSms =
          'Dear Customer You have received ETB 2,040.00 from account 1**9482 (Abebe Kebede) to your account 1**2233. Your current balance is ETB5,272.12. Thanks for Banking with CBE. https://mbreciept.cbe.com.et/v2-hfHCxHC6unkKSXCtrNI1  for feedback: https://forms.gle/kGNGQpG3mQCCk3iD6';
      
      final parsed = parseReceipt('CBE', cbeSms, 1729580000000);

      expect(parsed, isNotNull);
      expect(parsed!.provider, equals('CBE'));
      expect(parsed.transactionId, equals('v2-hfHCxHC6unkKSXCtrNI1'));
      expect(parsed.amount, equals(2040.00));
      expect(parsed.senderName, equals('Abebe Kebede'));
      expect(parsed.maskedPhone, equals('1**9482'));
      expect(parsed.phoneSuffix, equals('9482'));
    });

    test('Parses Traditional CBE SMS with Ref', () {
      const sms =
          'Your account credited with ETB 500.00 by Dawit Kebede. Ref: FT2410290001.';
      final parsed = parseReceipt('CBE', sms, 1729580000000);

      expect(parsed, isNotNull);
      expect(parsed!.provider, equals('CBE'));
      expect(parsed.transactionId, equals('FT2410290001'));
      expect(parsed.amount, equals(500.00));
      expect(parsed.senderName, equals('Dawit Kebede'));
    });

    test('Filters out non-financial SMS', () {
      const spam = 'Win 1,000,000 Birr lottery! Click this link now.';
      expect(isFinancialSender('SpamBot', spam), isFalse);
      final parsed = parseReceipt('SpamBot', spam, 1729580000000);
      expect(parsed, null);
    });

    test('Identifies financial sender variations', () {
      expect(isFinancialSender('127', ''), isTrue);
      expect(isFinancialSender('CBE_Birr', ''), isTrue);
      expect(isFinancialSender('Unknown', 'telebirr transaction alert'), isTrue);
      expect(isFinancialSender('Bank', 'ገቢ ተደርጎልዎታል'), isTrue);
      expect(isFinancialSender('Bank', 'Thanks for Banking with CBE.'), isTrue);
      expect(isFinancialSender('889', 'https://mbreciept.cbe.com.et/xyz'), isTrue);
    });
  });
}
