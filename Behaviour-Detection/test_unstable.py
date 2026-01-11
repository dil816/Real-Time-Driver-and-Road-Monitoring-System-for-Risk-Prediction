import paho.mqtt.client as mqtt
import numpy as np
import json
import time

BROKER = "localhost"
TOPIC = "vehicle/VEH_003/angle"

client = mqtt.Client()
client.connect(BROKER, 1883, 60)

print("Sending UNSTABLE steering data...")

# High-frequency sine + noise (UNSTABLE)
angles = np.cumsum(np.random.normal(0, 2.0, 200))
angles += np.random.normal(0, 4.0, 200)

for a in angles:
    payload = {"angle": float(a)}
    client.publish(TOPIC, json.dumps(payload))
    time.sleep(0.05)

print("Done.")
