import paho.mqtt.client as mqtt
import numpy as np
import json
import time

BROKER = "localhost"
TOPIC = "vehicle/VEH_001/angle"

client = mqtt.Client()
client.connect(BROKER, 1883, 60)

print("Sending SAFE steering data...")

# Low-amplitude, smooth steering (SAFE)
angles = np.cumsum(np.random.normal(0, 0.3, 200))

for a in angles:
    payload = {"angle": float(a)}
    client.publish(TOPIC, json.dumps(payload))
    time.sleep(0.05)

print("Done.")
