import paho.mqtt.client as mqtt
import numpy as np
import json
import time

BROKER = "localhost"
TOPIC = "vehicle/VEH_002/angle"

client = mqtt.Client()
client.connect(BROKER, 1883, 60)

print("Sending FAST steering data...")

# Large-amplitude, rapid changes (FAST)
angles = np.cumsum(np.random.normal(0, 2.5, 200))

for a in angles:
    payload = {"angle": float(a)}
    client.publish(TOPIC, json.dumps(payload))
    time.sleep(0.03)

print("Done.")
