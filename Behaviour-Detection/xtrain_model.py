import numpy as np
import pandas as pd
import tensorflow as tf

WINDOW_SIZE = 100

LABEL_MAP = {
    "SAFE": 0,
    "FAST": 1,
    "UNSTABLE": 2
}

def extract_features(angles):
    velocity = np.diff(angles)
    accel = np.diff(velocity)

    return [
        np.mean(np.abs(velocity)),
        np.std(velocity),
        np.std(accel),
        np.max(np.abs(accel)),
    ]

# ---------------- LOAD CSV ----------------
df = pd.read_csv("steering_angles.csv")
df["label"] = df["label"].map(LABEL_MAP)

X = []
y = []

# ---------------- SEQUENCE-BASED WINDOWING ----------------
for seq_id, group in df.groupby("sequence_id"):
    angles = group["angle"].values

    if len(angles) != WINDOW_SIZE:
        continue  # safety check

    label = group["label"].iloc[0]

    X.append(extract_features(angles))
    y.append(label)

X = np.array(X)
y = np.array(y)

print("X shape:", X.shape)
print("y shape:", y.shape)

# ---------------- MODEL ----------------
model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(4,)),
    tf.keras.layers.Dense(32, activation="relu"),
    tf.keras.layers.Dense(16, activation="relu"),
    tf.keras.layers.Dense(3, activation="softmax"),
])

model.compile(
    optimizer="adam",
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"]
)

model.summary()

model.fit(
    X, y,
    epochs=40,
    batch_size=32,
    shuffle=True
)

model.save("steering_model.keras")
print("model trained")
