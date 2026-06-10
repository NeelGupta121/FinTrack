-- Seed data: system categories (23, matching ml/labels.txt) + sample account templates

insert into categories (user_id, name, slug, type, icon, is_system) values
  (null, 'Food Delivery', 'food_delivery', 'expense', '🍕', true),
  (null, 'Groceries', 'groceries', 'expense', '🛒', true),
  (null, 'Transport (Ride)', 'transport_ride', 'expense', '🚗', true),
  (null, 'Transport (Fuel)', 'transport_fuel', 'expense', '⛽', true),
  (null, 'Shopping (Online)', 'shopping_online', 'expense', '📦', true),
  (null, 'Shopping (Offline)', 'shopping_offline', 'expense', '🛍️', true),
  (null, 'Bills (Telecom)', 'bills_telecom', 'expense', '📱', true),
  (null, 'Bills (Electricity)', 'bills_electricity', 'expense', '💡', true),
  (null, 'Bills (Water)', 'bills_water', 'expense', '💧', true),
  (null, 'Entertainment', 'entertainment', 'expense', '🎬', true),
  (null, 'Health (Medical)', 'health_medical', 'expense', '🏥', true),
  (null, 'Health (Fitness)', 'health_fitness', 'expense', '💪', true),
  (null, 'Education', 'education', 'expense', '📚', true),
  (null, 'Salary', 'salary', 'income', '💰', true),
  (null, 'Freelance', 'freelance', 'income', '💻', true),
  (null, 'Investment', 'investment', 'income', '📈', true),
  (null, 'Rent', 'rent', 'expense', '🏠', true),
  (null, 'EMI', 'emi', 'expense', '🏦', true),
  (null, 'Subscription', 'subscription', 'expense', '🔄', true),
  (null, 'Travel', 'travel', 'expense', '✈️', true),
  (null, 'Personal Care', 'personal_care', 'expense', '💅', true),
  (null, 'Gifts', 'gifts', 'expense', '🎁', true),
  (null, 'Other', 'other', 'expense', '📌', true);

-- Sample account templates (inserted per-user by the app on signup, shown here for reference)
-- These would be created by the app's onboarding flow:
-- insert into accounts (user_id, name, type) values
--   (<user_id>, 'Cash', 'cash'),
--   (<user_id>, 'Bank Account', 'bank'),
--   (<user_id>, 'Credit Card', 'credit_card'),
--   (<user_id>, 'Demat/Investment', 'investment');
