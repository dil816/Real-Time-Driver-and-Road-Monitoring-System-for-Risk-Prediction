import numpy as np
import tensorflow as tf
import paho.mqtt.client as mqtt
from collections import deque
import json

BROKER = "localhost"
PORT = 1883
TOPIC = "vehicle/+/angle"
WINDOW_SIZE = 100

LABELS = ["SAFE", "FAST", "UNSTABLE"]
DEVICE_BUFFERS = {}

print("Loading the model...")
model = tf.keras.models.load_model("steering_model.keras")
print("Model loaded ✔")

def extract_features(angles):
    velocity = np.diff(angles)
    accel = np.diff(velocity)

    return np.array([
        np.mean(np.abs(velocity)),
        np.std(velocity),
        np.std(accel),
        np.max(np.abs(accel)),
    ]).reshape(1, -1)

def on_connect(client, userdata, flags, rc):
    print("Connected to MQTT broker")
    client.subscribe(TOPIC)

def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode())
        angle = float(payload["angle"])
        device_id = msg.topic.split("/")[1]

        if device_id not in DEVICE_BUFFERS:
            DEVICE_BUFFERS[device_id] = deque(maxlen=WINDOW_SIZE)

        buf = DEVICE_BUFFERS[device_id]
        buf.append(angle)

        if len(buf) == WINDOW_SIZE:
            run_inference(device_id, buf)

    except Exception as e:
        print("Error:", e)

def run_inference(device_id, buffer):
    features = extract_features(np.array(buffer))
    preds = model.predict(features, verbose=0)[0]

    label = LABELS[np.argmax(preds)]
    confidence = np.max(preds)

    print(f"[{device_id}] Prediction: {label} (confidence={confidence:.2f})")

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

client.connect(BROKER, PORT, 60)
print("Waiting for angle data...")
client.loop_forever()
