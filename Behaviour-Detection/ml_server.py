import json
import time
import numpy as np
import paho.mqtt.client as mqtt
from collections import deque

WINDOW = 10
angles = deque(maxlen=WINDOW)
times = deque(maxlen=WINDOW)

def on_message(client, userdata, msg):
    data = json.loads(msg.payload.decode())
    angle = data["angle"]
    ts = data["timestamp"]

    angles.append(angle)
    times.append(ts)

    if len(angles) >= 5:
        analyze()

def analyze():
    diffs = np.diff(list(angles))
    speed = np.mean(np.abs(diffs))

    oscillation = np.std(diffs)

    risk = "LOW"

    if speed > 20:
        risk = "FAST STEERING"

    if oscillation > 15:
        risk = "UNSTABLE / JITTER"

    print(
        f"Angle={angles[-1]:3d} | "
        f"Speed={speed:5.1f} | "
        f"Osc={oscillation:5.1f} | "
        f"Risk={risk}"
    )

client = mqtt.Client()
client.on_message = on_message

client.connect("localhost", 1883, 60)
client.subscribe("steering/+/angle")

print("ML Server Started...")
client.loop_forever()
