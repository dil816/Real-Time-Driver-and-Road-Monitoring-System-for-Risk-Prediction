import time
from collections import deque

import numpy as np


class InstantDetector:
    """
    A short-window physics module to detect instantaneous steering anomalies
    (severe swerves or rapid oscillations) without waiting for the 5-second ML buffer.
    """

    def __init__(self, window_size=30, velocity_threshold=15.0, accel_threshold=8.0, oscillation_threshold=3,
                 cooldown=3.0):
        # 30 samples at 20Hz = 1.5 seconds of physical history
        self.buffer = deque(maxlen=window_size)
        self.velocity_threshold = velocity_threshold
        self.accel_threshold = accel_threshold
        self.oscillation_threshold = oscillation_threshold

        # Prevent the system from spamming the same alert 20 times a second
        self.last_alert_time = 0
        self.cooldown = cooldown

    def analyze(self, angle):
        """
        Ingests a single raw angle, checks the 1.5s buffer for violent math,
        and returns a string alert immediately if a threshold is broken.
        """
        self.buffer.append(angle)

        # We need a full 1.5 seconds to do proper calculus
        if len(self.buffer) < self.buffer.maxlen:
            return None

        # Check cooldown to prevent alert spamming
        current_time = time.time()
        if (current_time - self.last_alert_time) < self.cooldown:
            return None

        # Convert buffer to numpy array for physics extraction
        angles = np.array(self.buffer)
        velocity = np.diff(angles)
        accel = np.diff(velocity)

        # 1. Detect pure violent swerving (Jerk/Accel)
        max_vel = np.max(np.abs(velocity))
        max_acc = np.max(np.abs(accel))

        if max_vel > self.velocity_threshold and max_acc > self.accel_threshold:
            self.last_alert_time = current_time
            return f"🚨 [INSTANT] Severe swerve or jerk detected! (Vel: {max_vel:.1f})"

        # 2. Detect rapid oscillations (e.g., losing control on ice)
        # Count how many times the velocity crosses zero (changing steering direction wildly)
        zero_crossings = np.where(np.diff(np.sign(velocity)))[0]
        if len(zero_crossings) >= self.oscillation_threshold:
            self.last_alert_time = current_time
            return f"🚨 [INSTANT] Rapid steering oscillations detected ({len(zero_crossings)} changes in 1.5s)!"

        return None
