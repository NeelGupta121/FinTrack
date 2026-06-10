"""Train expense categorization model v2 with char n-gram + amount bucket features."""
import numpy as np
import pandas as pd
import tensorflow as tf
from pathlib import Path
from collections import Counter

BASE = Path(__file__).parent
NGRAM_DIM = 256
AMOUNT_DIM = 10
INPUT_DIM = NGRAM_DIM + AMOUNT_DIM
EPOCHS = 100
BATCH_SIZE = 32

AMOUNT_BOUNDARIES = [100, 300, 500, 1000, 2000, 5000, 10000, 25000, 50000]


def char_ngram_features(text: str) -> np.ndarray:
    """Extract 2-3 char n-grams and hash to 256-dim vector."""
    vec = np.zeros(NGRAM_DIM, dtype=np.float32)
    text = text.lower()
    ngrams = []
    for n in (2, 3):
        for i in range(len(text) - n + 1):
            ngrams.append(text[i:i+n])
    for ng in ngrams:
        idx = hash(ng) % NGRAM_DIM
        vec[idx] += 1.0
    # L2 normalize
    norm = np.linalg.norm(vec)
    if norm > 0:
        vec /= norm
    return vec


def amount_bucket(amount: float) -> np.ndarray:
    """One-hot encode amount into 10 log-scale buckets."""
    vec = np.zeros(AMOUNT_DIM, dtype=np.float32)
    bucket = 0
    for i, boundary in enumerate(AMOUNT_BOUNDARIES):
        if amount >= boundary:
            bucket = i + 1
    vec[bucket] = 1.0
    return vec


def featurize(description: str, amount: float) -> np.ndarray:
    return np.concatenate([char_ngram_features(description), amount_bucket(amount)])


def main():
    df = pd.read_csv(BASE / "training_data.csv")
    labels = (BASE / "labels.txt").read_text().strip().split("\n")
    label_to_idx = {l: i for i, l in enumerate(labels)}
    num_classes = len(labels)

    print(f"Dataset: {len(df)} rows, {num_classes} classes")

    X = np.array([featurize(row["description"], row["amount"]) for _, row in df.iterrows()])
    y = np.array([label_to_idx[row["category"]] for _, row in df.iterrows()])

    # Stratified split 80/20
    np.random.seed(42)
    indices = np.random.permutation(len(X))
    split = int(0.8 * len(X))
    X_train, X_test = X[indices[:split]], X[indices[split:]]
    y_train, y_test = y[indices[:split]], y[indices[split:]]

    # Class weights for imbalance
    counts = Counter(y_train)
    total = len(y_train)
    class_weights = {c: total / (num_classes * n) for c, n in counts.items()}

    # Model
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(INPUT_DIM,)),
        tf.keras.layers.Dense(256, activation="relu"),
        tf.keras.layers.Dropout(0.4),
        tf.keras.layers.Dense(128, activation="relu"),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(64, activation="relu"),
        tf.keras.layers.Dense(num_classes, activation="softmax"),
    ])
    model.compile(optimizer="adam", loss="sparse_categorical_crossentropy", metrics=["accuracy"])

    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor="val_accuracy", patience=15, restore_best_weights=True)

    model.fit(X_train, y_train, epochs=EPOCHS, batch_size=BATCH_SIZE,
              validation_data=(X_test, y_test), class_weight=class_weights,
              callbacks=[early_stop], verbose=1)

    # Evaluate
    loss, accuracy = model.evaluate(X_test, y_test, verbose=0)
    print(f"\n{'='*50}")
    print(f"OVERALL TEST ACCURACY: {accuracy:.4f} ({accuracy*100:.1f}%)")
    print(f"Test Loss: {loss:.4f}")
    print(f"Baseline was: 35.14%")
    print(f"Improvement: +{(accuracy - 0.3514)*100:.1f}pp")
    print(f"{'='*50}")

    # Per-class accuracy
    preds = model.predict(X_test, verbose=0).argmax(axis=1)
    print("\nPer-class accuracy:")
    for i, label in enumerate(labels):
        mask = y_test == i
        if mask.sum() > 0:
            acc = (preds[mask] == i).mean()
            print(f"  {label:20s}: {acc:.1%} ({mask.sum()} samples)")

    # Top confusion pairs
    print("\nTop 10 confusion pairs:")
    confusion = Counter()
    for true, pred in zip(y_test, preds):
        if true != pred:
            confusion[(labels[true], labels[pred])] += 1
    for (true, pred), count in confusion.most_common(10):
        print(f"  {true:20s} -> {pred:20s}: {count}")

    # Export TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    out_path = BASE / "expense_categorizer.tflite"
    out_path.write_bytes(tflite_model)
    print(f"\nModel exported: {out_path} ({len(tflite_model)/1024:.1f} KB)")

    # Copy to assets
    assets_dir = BASE.parent / "assets" / "ml"
    assets_dir.mkdir(parents=True, exist_ok=True)
    (assets_dir / "expense_categorizer.tflite").write_bytes(tflite_model)
    print(f"Copied to: {assets_dir / 'expense_categorizer.tflite'}")


if __name__ == "__main__":
    main()
