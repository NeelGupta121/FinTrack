import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// The canonical category catalogue.
///
/// This used to live in `expenses/widgets/category_picker.dart` and carried a
/// hardcoded `Color` per entry (23 raw literals outside theme control). Two
/// problems came out of that:
///
///  1. `CategoryIcon` maintained its OWN parallel map keyed on 12 short slugs
///     (`food`, `transport`, …) while transactions actually store the picker's
///     ids (`food_delivery`, `transport_ride`, …). Only 7 of 23 ids resolved,
///     so 16 categories — including `food_delivery`, the most common one in an
///     Indian expense tracker — silently fell through to a generic plate.
///  2. The 23 literals were a rainbow of saturated Material hues, which is the
///     loudest "default template" signal in a UI.
///
/// Both are fixed by having ONE list that owns the id, the label and the icon,
/// with the tint derived from the two-hue [AppTokens.chartRamp] by position.
/// Categories stay distinguishable at a glance without introducing 23 hues.
///
/// It lives under `common/` rather than under `expenses/` because
/// `common/widgets/category_icon.dart` consumes it, and a shared widget must
/// not depend on a feature folder. `category_picker.dart` re-exports it so
/// existing importers are unaffected.
@immutable
class CategoryItem {
  final String id;
  final String label;
  final IconData icon;
  const CategoryItem(this.id, this.label, this.icon);
}

const categories = <CategoryItem>[
  CategoryItem('food_delivery', 'Food Delivery', Icons.delivery_dining_rounded),
  CategoryItem('groceries', 'Groceries', Icons.local_grocery_store_rounded),
  CategoryItem('transport_ride', 'Cab/Ride', Icons.local_taxi_rounded),
  CategoryItem('transport_fuel', 'Fuel', Icons.local_gas_station_rounded),
  CategoryItem('shopping_online', 'Online Shop', Icons.shopping_cart_rounded),
  CategoryItem('shopping_offline', 'Offline Shop', Icons.storefront_rounded),
  CategoryItem('bills_telecom', 'Telecom', Icons.phone_android_rounded),
  CategoryItem('bills_electricity', 'Electricity', Icons.bolt_rounded),
  CategoryItem('bills_water', 'Water', Icons.water_drop_rounded),
  CategoryItem('entertainment', 'Entertainment', Icons.movie_rounded),
  CategoryItem('health_medical', 'Medical', Icons.local_hospital_rounded),
  CategoryItem('health_fitness', 'Fitness', Icons.fitness_center_rounded),
  CategoryItem('education', 'Education', Icons.school_rounded),
  CategoryItem('salary', 'Salary', Icons.account_balance_rounded),
  CategoryItem('freelance', 'Freelance', Icons.work_rounded),
  CategoryItem('investment', 'Investment', Icons.trending_up_rounded),
  CategoryItem('rent', 'Rent', Icons.home_rounded),
  CategoryItem('emi', 'EMI', Icons.credit_card_rounded),
  CategoryItem('subscription', 'Subscription', Icons.subscriptions_rounded),
  CategoryItem('travel', 'Travel', Icons.flight_rounded),
  CategoryItem('personal_care', 'Personal Care', Icons.spa_rounded),
  CategoryItem('gifts', 'Gifts', Icons.card_giftcard_rounded),
  CategoryItem('other', 'Other', Icons.more_horiz_rounded),
];

/// Lookup helpers. All tolerate a null or unknown id and fall back to `other`,
/// so a transaction carrying a legacy or Hive-UUID `category_id` renders
/// sensibly instead of blank.
abstract final class CategoryCatalog {
  static final Map<String, int> _indexById = {
    for (var i = 0; i < categories.length; i++) categories[i].id: i,
  };

  /// Also accepts the 12 short slugs the previous `CategoryIcon` map used, so
  /// any transaction written against the old key space still resolves.
  static const Map<String, String> _legacyAliases = <String, String>{
    'food': 'food_delivery',
    'transport': 'transport_ride',
    'shopping': 'shopping_online',
    'bills': 'bills_telecom',
    'health': 'health_medical',
  };

  static int indexOf(String? id) {
    if (id == null) return -1;
    final direct = _indexById[id];
    if (direct != null) return direct;
    final alias = _legacyAliases[id];
    return alias == null ? -1 : (_indexById[alias] ?? -1);
  }

  static CategoryItem? find(String? id) {
    final i = indexOf(id);
    return i < 0 ? null : categories[i];
  }

  static IconData iconFor(String? id) =>
      find(id)?.icon ?? Icons.more_horiz_rounded;

  static String labelFor(String? id) => find(id)?.label ?? 'Other';

  /// Categories whose money flows IN. These get the emerald hue; everything
  /// else stays in the indigo family.
  static const Set<String> _incomeLike = <String>{
    'salary',
    'freelance',
    'investment',
  };

  /// Tint for a category plate.
  ///
  /// An earlier version indexed straight into [AppTokens.chartRamp], which
  /// interleaves indigo and emerald tints. Two problems showed up on screen:
  /// adjacent categories alternated hue so the grid read as random decoration
  /// rather than a system, and the pale steps (ramp indices 4-7) were almost
  /// invisible as a 16%-opacity plate on a near-black canvas.
  ///
  /// Now the hue carries meaning — emerald means money in, indigo means money
  /// out — and only high-chroma steps are used, so every plate is legible in
  /// both themes.
  static Color tintFor(String? id) {
    final i = indexOf(id);
    if (i < 0) return const Color(0xFF818CF8); // indigo 400 fallback
    if (_incomeLike.contains(categories[i].id)) {
      return const Color(0xFF34D399); // emerald 400
    }
    // Two indigo steps give mild differentiation between neighbours without
    // introducing a second hue.
    return i.isEven ? const Color(0xFF6366F1) : const Color(0xFF818CF8);
  }
}
