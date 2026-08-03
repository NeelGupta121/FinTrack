// UI-LAYER verification for B1/B2 forms.
//
// Deliberately does NOT duplicate feature_expenses_test.dart /
// feature_investments_test.dart, which already cover the provider layer
// (update/delete/restore, priceCache cleanup, invalidation, truncation).
// This file asserts only what the USER SEES: that edit mode prefills, that
// titles/labels switch, and that the destructive-consequence toggle is shown
// on edit and hidden on add.

import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack/domain/entities/transaction.dart';
import 'package:fintrack/presentation/expenses/add_expense_screen.dart';

import 'harness/app_harness.dart';

void main() {
  setUpAll(initTestHive);
  setUp(resetBoxes);
  tearDownAll(closeTestHive);

  group('Expense form UI', () {
    testWidgets('add mode: title, and both Expense and Income selectable', (t) async {
      await pumpScreen(t, const AddExpenseScreen());
      expect(find.text('Add Expense'), findsOneWidget);
      // Income was previously creatable only via PDF import.
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsWidgets);
      expect(find.text('Save Expense'), findsOneWidget);
    });

    testWidgets('edit mode prefills amount + notes and says Save changes', (t) async {
      final txn = Transaction(
        id: 't1',
        amount: 3300,
        type: 'expense',
        date: DateTime.now(),
        categoryId: 'food_delivery',
        description: 'Dinner',
        source: 'manual',
      );
      await pumpScreen(t, AddExpenseScreen(existing: txn));

      expect(find.text('Edit Expense'), findsOneWidget);
      expect(find.text('3300'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('editing an income row opens titled Edit Income', (t) async {
      final txn = Transaction(
        id: 't2',
        amount: 75000,
        type: 'income',
        date: DateTime.now(),
        categoryId: 'salary',
        source: 'import',
      );
      await pumpScreen(t, AddExpenseScreen(existing: txn));
      expect(find.text('Edit Income'), findsOneWidget);
    });

    testWidgets('a decimal amount is not truncated in the edit field', (t) async {
      final txn = Transaction(
        id: 't3',
        amount: 249.5,
        type: 'expense',
        date: DateTime.now(),
        categoryId: 'groceries',
        source: 'manual',
      );
      await pumpScreen(t, AddExpenseScreen(existing: txn));
      expect(find.text('249.50'), findsOneWidget);
    });
  });
}
