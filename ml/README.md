# Expense Categorizer ML Model

TFLite model for classifying Indian bank/UPI transaction descriptions into expense categories.

## Setup

```bash
pip install tensorflow pandas numpy
```

## Train

```bash
python train_model.py
```

Outputs `expense_categorizer.tflite` (~50-100KB quantized).

## Categories

23 categories defined in `labels.txt`: food_delivery, groceries, transport_ride, transport_fuel, shopping_online, shopping_offline, bills_telecom, bills_electricity, bills_water, entertainment, health_medical, health_fitness, education, salary, freelance, investment, rent, emi, subscription, travel, personal_care, gifts, other.

## Generating More Training Data

1. **From real SMS**: Export bank SMS using SMS Backup & Restore, parse with regex, manually label a sample.

2. **Synthetic augmentation** — add rows to `training_data.csv`:
   - Vary bank names (HDFC, SBI, ICICI, Axis, Kotak, BOB, PNB, Canara, IDBI)
   - Vary SMS formats: `"Rs X debited"`, `"INR X paid"`, `"Debit of Rs X"`
   - Vary UPI handles: `@ybl`, `@axl`, `@paytm`, `@icici`, `@okaxis`, `@oksbi`
   - Add new merchants per category
   - Randomize amounts within realistic ranges

3. **LLM-assisted**: Prompt Gemini/GPT with: "Generate 50 Indian bank SMS messages for category X with varied banks, amounts, and merchant names in CSV format."

## Retraining

```bash
# Edit training_data.csv (add rows, fix labels)
python train_model.py
# New .tflite overwrites the old one
```

## Flutter Deployment

```dart
// pubspec.yaml
dependencies:
  tflite_flutter: ^0.10.4

// Usage
final interpreter = await Interpreter.fromAsset('assets/ml/expense_categorizer.tflite');
var input = hashText(description); // port hash_text() to Dart
var output = List.filled(23, 0.0).reshape([1, 23]);
interpreter.run([input], output);
String category = labels[output[0].indexOf(output[0].reduce(max))];
```

## Model Architecture

```
Input(64) → Dense(128, ReLU) → Dropout(0.3) → Dense(64, ReLU) → Dropout(0.2) → Dense(23, Softmax)
```

Feature extraction: deterministic text hashing (no vocabulary needed, works offline, ~1KB overhead).
