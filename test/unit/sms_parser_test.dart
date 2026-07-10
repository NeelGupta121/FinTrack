import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/services/sms_parser_service.dart';

void main() {
  final parser = SmsParserService();

  group('SmsParserService', () {
    test('parses UPI "Sent" as an expense (previously dropped)', () {
      final d = parser.parse('Sent Rs.500 to Amazon via UPI Ref 123456789');
      expect(d, isNotNull);
      expect(d!.type, TransactionType.expense);
      expect(d.amount, 500);
      expect(d.merchant, 'Amazon');
    });

    test('parses "transferred" as an expense', () {
      final d = parser.parse('Rs.1,000 transferred to John Doe on 05-01-2026');
      expect(d, isNotNull);
      expect(d!.type, TransactionType.expense);
      expect(d.amount, 1000);
      // merchant trimmed of trailing " on <date>"
      expect(d.merchant, 'John Doe');
    });

    test('parses "deducted" as an expense', () {
      final d = parser.parse('INR 250 deducted for Netflix subscription');
      expect(d?.type, TransactionType.expense);
      expect(d?.amount, 250);
    });

    test('classic debited still works and trims merchant noise', () {
      final d = parser.parse('Your a/c debited Rs.200 at SWIGGY on 04-01-2026 Avl Bal Rs.5000');
      expect(d?.type, TransactionType.expense);
      expect(d?.amount, 200);
      expect(d?.merchant, 'SWIGGY');
    });

    test('SIP detected as investment', () {
      final d = parser.parse('Rs.5000 debited for SIP in Axis Mutual Fund folio 12345');
      expect(d?.type, TransactionType.investment);
      expect(d?.amount, 5000);
    });

    test('salary credit detected as income', () {
      final d = parser.parse('Rs.50,000 credited to your account as SALARY');
      expect(d?.type, TransactionType.income);
      expect(d?.amount, 50000);
    });

    test('OTP messages are skipped', () {
      expect(parser.parse('123456 is your OTP for a txn of Rs.500. Do not share.'), isNull);
    });

    test('promotional cashback offer is skipped', () {
      expect(
        parser.parse('Get Rs.500 cashback on your next order! Offer valid till 31 Dec. T&C apply.'),
        isNull,
      );
    });

    test('promo with a link is skipped', () {
      expect(
        parser.parse('FLAT Rs.1000 off on electronics! Shop now https://bit.ly/xyz'),
        isNull,
      );
    });

    test('pre-approved loan offer is skipped', () {
      expect(
        parser.parse('Congratulations! You are eligible for a pre-approved loan offer of Rs.5,00,000. Apply now.'),
        isNull,
      );
    });

    test('legit cashback CREDIT with txn evidence is NOT filtered as promo', () {
      final d = parser.parse('Rs.50 cashback credited to a/c XX1234. Avl Bal Rs.500');
      expect(d, isNotNull);
      expect(d!.type, TransactionType.income);
      expect(d.amount, 50);
    });

    test('messages without an amount are skipped', () {
      expect(parser.parse('Your account statement is ready.'), isNull);
    });

    test('messages without a recognizable type are skipped', () {
      expect(parser.parse('Rs.500 is your minimum balance requirement.'), isNull);
    });
  });
}
