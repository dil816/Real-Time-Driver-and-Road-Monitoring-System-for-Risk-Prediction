import json
import os
import math
import time


class DriverProfiler:
    """
    An Online Unsupervised Continuous Learning Module for tracking driver patterns.
    Uses Exponential Moving Averages (EMA) to maintain short-term trip data and
    long-term lifetime data. Detects concept drift (behavior shifts) using Z-Scores.
    """

    # Mapping categorical AI predictions to numerical scores
    SCORE_MAP = {
        "SAFE": 100.0,
        "FAST": 50.0,
        "UNSTABLE": 0.0
    }

    def __init__(self, device_id, save_file="driver_profile.json", alpha_short=0.1, alpha_long=0.005, z_threshold=2.5):
        """
        :param alpha_short: Learning rate for the short-term memory (trip). Higher = forgets faster.
        :param alpha_long: Learning rate for the long-term memory (lifetime). Lower = learns slowly.
        :param z_threshold: Number of standard deviations before triggering a drift alert.
        """
        self.device_id = device_id
        self.save_file = save_file
        self.alpha_short = alpha_short
        self.alpha_long = alpha_long
        self.z_threshold = z_threshold

        # Short-term memory (Current Trip / Recent window)
        self.st_mean = None

        # Long-term memory (Lifetime Driver Profile)
        self.lt_mean = None
        self.lt_var = 0.0
        self.total_samples = 0

        self.last_rank = None
        self.last_save_time = time.time()
        self.load_profile()

    def load_profile(self):
        """Load the long-term historical profile from disk to learn continuously forever."""
        if os.path.exists(self.save_file):
            try:
                with open(self.save_file, "r") as f:
                    data = json.load(f)
                    if self.device_id in data:
                        profile = data[self.device_id]
                        self.lt_mean = profile.get("lt_mean")
                        self.lt_var = profile.get("lt_var", 0.0)
                        self.total_samples = profile.get("total_samples", 0)
                        self.last_rank = self.get_rank(self.lt_mean)
                        print(
                            f"[{self.device_id}] Profiler loaded. Lifetime Score: {self.lt_mean:.1f} ({self.last_rank})")
            except Exception as e:
                print(f"Error loading profile: {e}. Starting fresh.")

    def save_profile(self):
        """Save the long-term profile to disk."""
        data = {}
        if os.path.exists(self.save_file):
            try:
                with open(self.save_file, "r") as f:
                    data = json.load(f)
            except Exception:
                pass

        data[self.device_id] = {
            "lt_mean": self.lt_mean,
            "lt_var": self.lt_var,
            "total_samples": self.total_samples
        }

        try:
            with open(self.save_file, "w") as f:
                json.dump(data, f, indent=4)
        except Exception as e:
            print(f"Error saving profile: {e}")

    def get_rank(self, score):
        """Assign a rank based on the score."""
        if score is None:
            return "Unranked"
        if score >= 95.0: return "Rank S (Elite)"
        if score >= 85.0: return "Rank A (Excellent)"
        if score >= 70.0: return "Rank B (Good)"
        if score >= 50.0: return "Rank C (Average)"
        if score >= 35.0: return "Rank D (Aggressive)"
        return "Rank F (Dangerous)"

    def update(self, label):
        """
        Process a new prediction label.
        Returns a list of notification strings (if any events occurred).
        """
        notifications = []

        # If vehicle is stopped, do not apply any rank changes or learn anything new
        if label == "NONE":
            # Periodically save progress to disk (strictly every 30 seconds)
            current_time = time.time()
            if current_time - self.last_save_time >= 30.0:
                self.save_profile()
                self.last_save_time = current_time
            return notifications

        score = self.SCORE_MAP.get(label, 50.0)

        # Initialization Phase
        if self.lt_mean is None:
            self.lt_mean = score
            self.st_mean = score
            self.total_samples = 1
            return notifications

        if self.st_mean is None:
            self.st_mean = self.lt_mean

        self.total_samples += 1

        # 1. Update Short-Term (Trip) Memory
        self.st_mean = (self.alpha_short * score) + ((1 - self.alpha_short) * self.st_mean)

        # 2. Update Long-Term (Lifetime) Memory (Welford's online algorithm for variance/EMA)
        diff = score - self.lt_mean

        # Asymmetric Penalty: If the event score is worse than the historical average, learn 10x faster (penalize heavily)
        current_alpha_long = min(1.0, self.alpha_long * 10) if score < self.lt_mean else self.alpha_long

        self.lt_mean = (current_alpha_long * score) + ((1 - current_alpha_long) * self.lt_mean)

        # Incremental variance for Z-Score
        self.lt_var = (1 - current_alpha_long) * (self.lt_var + current_alpha_long * (diff ** 2))

        # 3. Concept Drift Detection (Z-Score)
        # Avoid division by zero early on
        if self.total_samples > 100 and self.lt_var > 0:
            std_dev = math.sqrt(self.lt_var)
            z_score = (self.st_mean - self.lt_mean) / std_dev

            # Check if short-term behavior drifted significantly from long-term profile
            if abs(z_score) > self.z_threshold:
                direction = "improved \U0001f44d" if z_score > 0 else "degraded \U000026a0\U0000fe0f"

                # Prevent spamming: We dynamically 'absorb' the shift by gently nudging the
                # long-term mean towards the short-term, or we just notify once and let it restabilize.
                notifications.append(
                    f"\u26A1 PATTERN SHIFT DETECTED: Driving behavior has {direction}! "
                    f"(Trip Avg: {self.st_mean:.1f} vs Lifetime Avg: {self.lt_mean:.1f})"
                )

                # Dampen the short-term memory slightly to avoid alert spamming for the same continuous event
                self.st_mean = (self.st_mean + self.lt_mean) / 2.0

                # 4. Rank Change Detection
        current_rank = self.get_rank(self.lt_mean)
        if self.last_rank and current_rank != self.last_rank:
            notifications.append(
                f"\U0001f3c6 RANK UPDATE: Your driving rank changed from {self.last_rank} to {current_rank}!")
        self.last_rank = current_rank

        # Periodically save progress to disk (strictly every 30 seconds)
        current_time = time.time()
        if current_time - self.last_save_time >= 30.0:
            self.save_profile()
            self.last_save_time = current_time

        return notifications
