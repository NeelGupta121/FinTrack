import 'package:flutter/material.dart';

class CategoryItem {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const CategoryItem(this.id, this.label, this.icon, this.color);
}

const categories = <CategoryItem>[
  CategoryItem('food_delivery', 'Food Delivery', Icons.delivery_dining, Color(0xFFFF6B35)),
  CategoryItem('transport_ride', 'Cab/Ride', Icons.local_taxi, Color(0xFF4CAF50)),
  CategoryItem('transport_auto', 'Auto/Bus', Icons.directions_bus, Color(0xFF66BB6A)),
  CategoryItem('shopping_online', 'Online Shop', Icons.shopping_cart, Color(0xFF9C27B0)),
  CategoryItem('shopping_offline', 'Offline Shop', Icons.store, Color(0xFFAB47BC)),
  CategoryItem('groceries', 'Groceries', Icons.local_grocery_store, Color(0xFF8BC34A)),
  CategoryItem('bills_telecom', 'Telecom', Icons.phone_android, Color(0xFF2196F3)),
  CategoryItem('bills_electricity', 'Electricity', Icons.bolt, Color(0xFFFFC107)),
  CategoryItem('bills_water', 'Water', Icons.water_drop, Color(0xFF03A9F4)),
  CategoryItem('bills_gas', 'Gas', Icons.local_fire_department, Color(0xFFFF5722)),
  CategoryItem('entertainment', 'Entertainment', Icons.movie, Color(0xFFE91E63)),
  CategoryItem('health_medical', 'Medical', Icons.local_hospital, Color(0xFFF44336)),
  CategoryItem('health_fitness', 'Fitness', Icons.fitness_center, Color(0xFFEF5350)),
  CategoryItem('education', 'Education', Icons.school, Color(0xFF3F51B5)),
  CategoryItem('rent_emi', 'Rent/EMI', Icons.home, Color(0xFF795548)),
  CategoryItem('investment_sip', 'Investment', Icons.trending_up, Color(0xFF009688)),
  CategoryItem('travel', 'Travel', Icons.flight, Color(0xFF00BCD4)),
  CategoryItem('personal_care', 'Personal Care', Icons.spa, Color(0xFFFF8A80)),
  CategoryItem('gifts_donations', 'Gifts', Icons.card_giftcard, Color(0xFFFFD54F)),
  CategoryItem('miscellaneous', 'Other', Icons.more_horiz, Color(0xFF9E9E9E)),
];

class CategoryPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;
  const CategoryPicker({super.key, this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: categories.length,
      itemBuilder: (ctx, i) {
        final cat = categories[i];
        final isSelected = cat.id == selected;
        return GestureDetector(
          onTap: () => onSelected(cat.id),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isSelected ? cat.color : cat.color.withOpacity(0.15),
                child: Icon(cat.icon, color: isSelected ? Colors.white : cat.color, size: 20),
              ),
              const SizedBox(height: 4),
              Text(cat.label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }
}
