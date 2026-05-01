import asyncio
import json
import socket
import threading
from collections import deque

import numpy as np
import paho.mqtt.client as mqtt
import tensorflow as tf
from aiohttp import web

from DriverProfiler import DriverProfiler
from InstantDetector import InstantDetector


# ─────────────────────────────────────────────
# Network helpers
# ─────────────────────────────────────────────
def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


# ─────────────────────────────────────────────
# MQTT Config (hardware side — untouched)
# ─────────────────────────────────────────────
BROKER = get_local_ip()
PORT = 1883
TOPIC = "vehicle/+/angle"
WINDOW_SIZE = 100

LABELS = ["SAFE", "FAST", "UNSTABLE"]
DEVICE_BUFFERS = {}
PROFILERS = {}
INSTANT_DETECTORS = {}

# ─────────────────────────────────────────────
# Shared state between MQTT thread & HTTP server
# ─────────────────────────────────────────────
LATEST_PROFILES: dict[str, dict] = {}  # device_id → latest profile payload
WS_CLIENTS: set = set()  # active aiohttp WebSocket connections
_event_loop: asyncio.AbstractEventLoop | None = None  # set when async loop starts

print("Loading the model...")
model = tf.keras.models.load_model("steering_model.keras")
print("Model loaded ✔")


# ─────────────────────────────────────────────
# ML helpers
# ─────────────────────────────────────────────
def extract_features(angles):
    velocity = np.diff(angles)
    accel = np.diff(velocity)
    return np.array([
        np.mean(np.abs(velocity)),
        np.std(velocity),
        np.std(accel),
        np.max(np.abs(accel)),
    ]).reshape(1, -1)


# ─────────────────────────────────────────────
# Thread-safe broadcast to all WebSocket clients
# ─────────────────────────────────────────────
def broadcast_profile(payload: dict):
    """Called from the MQTT thread — schedules a coroutine on the asyncio loop."""
    if _event_loop is None:
        return
    msg = json.dumps(payload)
    asyncio.run_coroutine_threadsafe(_async_broadcast(msg), _event_loop)


async def _async_broadcast(msg: str):
    dead = set()
    for ws in WS_CLIENTS:
        try:
            await ws.send_str(msg)
        except Exception:
            dead.add(ws)
    WS_CLIENTS.difference_update(dead)


# ─────────────────────────────────────────────
# MQTT callbacks (hardware pipeline — untouched)
# ─────────────────────────────────────────────
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

        # --- 1. INSTANTANEOUS PHYSICS DETECTION (1.5 s sliding window) ---
        instant_detector = INSTANT_DETECTORS[device_id]
        instant_alert = instant_detector.analyze(angle)

        if instant_alert:
            print(f"\n[{device_id}] {instant_alert}\n")

            if device_id in PROFILERS:
                prof = PROFILERS[device_id]
                st_m = prof.st_mean
                lt_m = prof.lt_mean
                rnk = prof.last_rank
            else:
                st_m, lt_m, rnk = 100.0, 100.0, "S"

            alert_payload = {
                "device_id": device_id,
                "st_mean": st_m,
                "lt_mean": lt_m,
                "rank": rnk,
                "alerts": [instant_alert],
                "prediction": "INSTANT"
            }
            # Publish to MQTT (hardware / other MQTT subscribers)
            client.publish(f"vehicle/{device_id}/profile", json.dumps(alert_payload))
            # Push to Flutter via WebSocket
            LATEST_PROFILES[device_id] = alert_payload
            broadcast_profile(alert_payload)

        # --- 2. DEEP LEARNING PROFILING (5 s sliding window) ---
        if len(buf) == WINDOW_SIZE:
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
        confidence = float(np.max(preds))
        print(f"[{device_id}] Prediction: {label} (confidence={confidence:.2f})")

    if device_id not in PROFILERS:
        PROFILERS[device_id] = DriverProfiler(device_id)

    profiler = PROFILERS[device_id]
    notifications = profiler.update(label)

    for notification in notifications:
        print(f"\n[{device_id}] {notification}\n")

    profile_payload = {
        "device_id": device_id,
        "st_mean": profiler.st_mean,
        "lt_mean": profiler.lt_mean,
        "rank": profiler.last_rank,
        "alerts": notifications,
        "prediction": label
    }

    # Publish to MQTT (hardware pipeline — unchanged)
    client.publish(f"vehicle/{device_id}/profile", json.dumps(profile_payload))

    # Push to Flutter via WebSocket + cache latest
    LATEST_PROFILES[device_id] = profile_payload
    broadcast_profile(profile_payload)


# ─────────────────────────────────────────────
# aiohttp HTTP + WebSocket server
# ─────────────────────────────────────────────
async def handle_devices(request):
    """GET /devices — list of all known device IDs."""
    return web.json_response(list(LATEST_PROFILES.keys()))


async def handle_profile(request):
    """GET /profile/{device_id} — latest profile snapshot."""
    device_id = request.match_info["device_id"]
    if device_id not in LATEST_PROFILES:
        raise web.HTTPNotFound(reason=f"Device '{device_id}' not seen yet")
    return web.json_response(LATEST_PROFILES[device_id])


async def handle_ws(request):
    """WS /ws — live push of every new profile update."""
    ws = web.WebSocketResponse(heartbeat=30)
    await ws.prepare(request)
    WS_CLIENTS.add(ws)
    print(f"[WS] Client connected ({len(WS_CLIENTS)} total)")

    # Send a snapshot of all known devices immediately on connect
    if LATEST_PROFILES:
        await ws.send_str(json.dumps({
            "type": "snapshot",
            "profiles": list(LATEST_PROFILES.values())
        }))

    try:
        async for _ in ws:
            pass  # Flutter only listens; we don't expect messages from the app
    finally:
        WS_CLIENTS.discard(ws)
        print(f"[WS] Client disconnected ({len(WS_CLIENTS)} total)")

    return ws


async def start_http_server():
    global _event_loop
    _event_loop = asyncio.get_running_loop()

    app = web.Application()
    app.router.add_get("/devices", handle_devices)
    app.router.add_get("/profile/{device_id}", handle_profile)
    app.router.add_get("/ws", handle_ws)

    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", 8765)
    await site.start()

    print(f"")
    print(f"===================================================")
    print(f"🚀 AUTO-DETECTED BROKER IP: {BROKER}")
    print(f"👉 Put '{BROKER}' in your ESP32 steer_sensor.ino!")
    print(f"")
    print(f"📡 HTTP/WS SERVER:  http://{BROKER}:8765")
    print(f"   REST:  GET http://{BROKER}:8765/devices")
    print(f"   REST:  GET http://{BROKER}:8765/profile/<device_id>")
    print(f"   WS  :  ws://{BROKER}:8765/ws")
    print(f"   👉 Use '{BROKER}:8765' in your Flutter app!")
    print(f"===================================================")
    print(f"")

    # Keep the coroutine alive forever
    while True:
        await asyncio.sleep(3600)


def run_http_server():
    """Run the aiohttp server in its own thread with its own event loop."""
    asyncio.run(start_http_server())


# ─────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────
if __name__ == "__main__":
    # Start HTTP/WS server in a background thread
    http_thread = threading.Thread(target=run_http_server, daemon=True)
    http_thread.start()

    # MQTT loop (blocking — hardware pipeline unchanged)
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(BROKER, PORT, 60)
    print("Waiting for angle data...")
    client.loop_forever()
