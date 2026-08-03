// Proves the container-level pattern before the feature suites rely on it.
import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack/presentation/expenses/expense_providers.dart';

import 'harness/app_harness.dart';

void main() {
  setUpAll(initTestHive);
  tearDownAll(closeTestHive);
  setUp(resetBoxes);

  test('pattern: real notifier writes, real provider reads it back', () async {
    final c = makeContainer();

    await c.read(addExpenseProvider).add(
          amount: 3300,
          categoryId: 'food_delivery',
          date: DateTime.now(),
          merchant: 'Swiggy',
        );

    final list = await readAsync(c, expenseListProvider);
    expect(list.length, 1);
    expect(list.first.amount, 3300);
    expect(list.first.type, 'expense');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
