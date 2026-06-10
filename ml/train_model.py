"""Train expense categorization model and export to TFLite."""
import numpy as np
import pandas as pd
import tensorflow as tf
from pathlib import Path

BASE = Path(__file__).parent
NUM_FEATURES = 64
EPOCHS = 50
BATCH_SIZE = 32


def hash_text(text: str, num_features: int = NUM_FEATURES) -> np.ndarray:
    """Hash text into a fixed-size feature vector using multiple hash seeds."""
    vec = np.zeros(num_features, dtype=np.float32)
    tokens = text.lower().split()
    for token in tokens:
        for i in range(num_features):
            h = hash(f"{token}_{i}") % 1000000
            vec[i] += (h / 1000000.0) - 0.5
    if tokens:
        vec /= len(tokens)
    return vec


def main():
    # Load data
    df = pd.read_csv(BASE / "training_data.csv")
    labels = (BASE / "labels.txt").read_text().strip().split("\n")
    label_to_idx = {l: i for i, l in enumerate(labels)}
    num_classes = len(labels)

    # Prepare features
    X = np.array([hash_text(row["description"]) for _, row in df.iterrows()])
    y = np.array([label_to_idx[row["category"]] for _, row in df.iterrows()])

    # Train/test split (80/20)
    indices = np.random.permutation(len(X))
    split = int(0.8 * len(X))
    X_train, X_test = X[indices[:split]], X[indices[split:]]
    y_train, y_test = y[indices[:split]], y[indices[split:]]

    # Build model
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(NUM_FEATURES,)),
        tf.keras.layers.Dense(128, activation="relu"),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(64, activation="relu"),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(num_classes, activation="softmax"),
    ])
    model.compile(optimizer="adam", loss="sparse_categorical_crossentropy", metrics=["accuracy"])

    # Train
    model.fit(X_train, y_train, epochs=EPOCHS, batch_size=BATCH_SIZE,
              validation_data=(X_test, y_test), verbose=1)

    # Evaluate
    loss, accuracy = model.evaluate(X_test, y_test, verbose=0)
    print(f"\nTest Accuracy: {accuracy:.4f}")
    print(f"Test Loss: {loss:.4f}")

    # Per-class accuracy
    preds = model.predict(X_test, verbose=0).argmax(axis=1)
    print("\nPer-class accuracy:")
    for i, label in enumerate(labels):
        mask = y_test == i
        if mask.sum() > 0:
            acc = (preds[mask] == i).mean()
            print(f"  {label:20s}: {acc:.2%} ({mask.sum()} samples)")

    # Export to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    out_path = BASE / "expense_categorizer.tflite"
    out_path.write_bytes(tflite_model)
    print(f"\nModel exported: {out_path} ({len(tflite_model) / 1024:.1f} KB)")


if __name__ == "__main__":
    main()
