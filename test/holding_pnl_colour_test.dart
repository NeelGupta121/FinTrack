// The holding P&L colour is semantic, so it is asserted on the resolved
// Color rather than on the text. A wrong colour with right text is exactly the
// failure mode that a text-only assertion lets through.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack/domain/entities/holding.dart';
import 'package:fintrack/presentation/common/theme/app_theme.dart';
import 'package:fintrack/presentation/investments/widgets/holding_card.dart';

Holding _h({required double qty, required double avg}) => Holding(
      id: 'h1',
      symbol: 'PPF',
      name: 'Public Provident Fund',
      type: 'other',
      quantity: qty,
      avgPrice: avg,
    );

/// Pumps a single card and returns the resolved colour of the P&L line.
Future<Color?> _pnlColor(
  WidgetTester tester, {
  required Holding holding,
  required double price,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: HoldingCard(holding: holding, currentPrice: price),
    ),
  ));
  await tester.pump();

  // The P&L line is the one carrying a '%' in parentheses.
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .where((w) => (w.data ?? '').contains('%'))
      .toList();
  expect(texts, isNotEmpty, reason: 'no P&L line rendered');
  return texts.first.style?.color;
}

void main() {
  late Color success, error, neutral;

  setUpAll(() {
    const t = AppTokens.dark;
    success = t.success;
    error = t.error;
    neutral = t.textSecondary;
  });

  testWidgets('a real gain reads as success', (tester) async {
    final c = await _pnlColor(tester,
        holding: _h(qty: 40, avg: 1000), price: 1200);
    expect(c, success);
  });

  testWidgets('a real loss reads as error', (tester) async {
    final c = await _pnlColor(tester,
        holding: _h(qty: 40, avg: 1585), price: 1472);
    expect(c, error);
  });

  testWidgets('a holding exactly at cost reads NEUTRAL, never as a gain',
      (tester) async {
    // The seeded PPF (1 unit at 150000, priced at 150000) rendered
    // '+₹0 (0.0%)' in success green under `pnl >= 0`, implying a profit that
    // does not exist.
    final c = await _pnlColor(tester,
        holding: _h(qty: 1, avg: 150000), price: 150000);
    expect(c, neutral);
    expect(c, isNot(success));
  });

  testWidgets('a flat holding carries no + sign', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: HoldingCard(
            holding: _h(qty: 1, avg: 150000), currentPrice: 150000),
      ),
    ));
    await tester.pump();
    final pnl = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .firstWhere((s) => s.contains('%') && s.contains('₹'));
    expect(pnl.startsWith('+'), isFalse,
        reason: 'zero is not a gain, so it must not be signed: $pnl');
  });
}
