import numpy as np
import pandas as pd

WINDOW_SIZE = 100
NUM_SEQUENCES_PER_CLASS = 300

rows = []
sequence_id = 0

def add_sequence(angles, label, seq_id):
    for a in angles:
        rows.append({
            "sequence_id": seq_id,
            "angle": int(a),
            "label": label
        })

# ---------------- SAFE ----------------
for _ in range(NUM_SEQUENCES_PER_CLASS):
    angles = np.cumsum(np.random.randint(-1, 2, WINDOW_SIZE))
    angles = np.clip(angles, -180, 180)
    add_sequence(angles, "SAFE", sequence_id)
    sequence_id += 1

# ---------------- FAST ----------------
for _ in range(NUM_SEQUENCES_PER_CLASS):
    angles = np.cumsum(np.random.randint(-5, 6, WINDOW_SIZE))
    angles = np.clip(angles, -180, 180)
    add_sequence(angles, "FAST", sequence_id)
    sequence_id += 1

# ---------------- UNSTABLE ----------------
for _ in range(NUM_SEQUENCES_PER_CLASS):
    angles = np.cumsum(np.random.randint(-10, 11, WINDOW_SIZE))
    angles = np.clip(angles, -180, 180)
    add_sequence(angles, "UNSTABLE", sequence_id)
    sequence_id += 1

df = pd.DataFrame(rows)
df.to_csv("steering_angles.csv", index=False)

print("CSV saved with sequence_id:", df.shape)
