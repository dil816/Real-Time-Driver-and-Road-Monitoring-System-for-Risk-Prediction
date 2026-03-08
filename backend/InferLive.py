import numpy as np
import tensorflow as tf
import paho.mqtt.client as mqtt
from collections import deque
import json
from DriverProfiler import DriverProfiler
from InstantDetector import InstantDetector
import socket


def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


BROKER = get_local_ip()
PORT = 1883
TOPIC = "vehicle/+/angle"
WINDOW_SIZE = 100

LABELS = ["SAFE", "FAST", "UNSTABLE"]
DEVICE_BUFFERS = {}
PROFILERS = {}
INSTANT_DETECTORS = {}

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
            INSTANT_DETECTORS[device_id] = InstantDetector()

        buf = DEVICE_BUFFERS[device_id]
        buf.append(angle)

        # --- 1. INSTANTANEOUS PHYSICS DETECTION (1.5s Sliding Window) ---
        instant_detector = INSTANT_DETECTORS[device_id]
        instant_alert = instant_detector.analyze(angle)

        if instant_alert:
            print(f"\n[{device_id}] {instant_alert}\n")

            # Broadcast the anomaly immediately with current profile stats
            if device_id in PROFILERS:
                prof = PROFILERS[device_id]
                st_m = prof.st_mean
                lt_m = prof.lt_mean
                rnk = prof.last_rank
            else:
                st_m, lt_m, rnk = 100.0, 100.0, "S"

            profile_payload = {
                "device_id": device_id,
                "st_mean": st_m,
                "lt_mean": lt_m,
                "rank": rnk,
                "alerts": [instant_alert]
            }
            client.publish(f"vehicle/{device_id}/profile", json.dumps(profile_payload))

        # --- 2. DEEP LEARNING PROFILING (5s Sliding Window) ---
        if len(buf) == WINDOW_SIZE:
            # Rule: Stop considering the prediction if the angle is identically the same across the whole window (Vehicle Stopped)
            if max(buf) == min(buf):
                run_inference(device_id, buf, stopped=True)
            else:
                run_inference(device_id, buf, stopped=False)

    except Exception as e:
        print("Error:", e)


def run_inference(device_id, buffer, stopped=False):
    if stopped:
        label = "NONE"
        confidence = 1.0
        print(f"[{device_id}] Prediction: {label} (Vehicle Stopped)")
    else:
        features = extract_features(np.array(buffer))
        preds = model.predict(features, verbose=0)[0]

        label = LABELS[np.argmax(preds)]
        confidence = np.max(preds)

        print(f"[{device_id}] Prediction: {label} (confidence={confidence:.2f})")

    # ----- Continuous Driver Profiling -----
    if device_id not in PROFILERS:
        PROFILERS[device_id] = DriverProfiler(device_id)

    profiler = PROFILERS[device_id]
    notifications = profiler.update(label)

    for notification in notifications:
        print(f"\n[{device_id}] {notification}\n")

    # ----- Broadcast Profile to Flutter App over MQTT -----
    profile_payload = {
        "device_id": device_id,
        "st_mean": profiler.st_mean,
        "lt_mean": profiler.lt_mean,
        "rank": profiler.last_rank,
        "alerts": notifications,
        "prediction": label
    }
    client.publish(f"vehicle/{device_id}/profile", json.dumps(profile_payload))


client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

print(f"===================================================")
print(f"🚀 AUTO-DETECTED BROKER IP: {BROKER}")
print(f"👉 Put '{BROKER}' in your ESP32 steer_sensor.ino!")
print(f"===================================================")

client.connect(BROKER, PORT, 60)
print("Waiting for angle data...")
client.loop_forever()
