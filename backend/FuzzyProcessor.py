import warnings
from datetime import datetime
from typing import Dict, Tuple

warnings.filterwarnings('ignore')


class FuzzyProcessor:
    """
    Adaptive Fuzzy Logic System for Driver Fatigue Detection
    Integrates Environmental, Physiological, and Behavioral data
    """

    def __init__(self):
        self.alert_threshold = {
            'safe': 0.3,
            'caution': 0.5,
            'warning': 0.7,
            'critical': 0.85
        }
        self.fatigue_history = []

    @staticmethod
    def fuzzify(value: float, low: Tuple[float, float],
                medium: Tuple[float, float], high: Tuple[float, float]) -> Dict[str, float]:
        """
        Fuzzify a crisp value into fuzzy membership values
        Returns membership degrees for low, medium, and high
        """
        membership = {'low': 0.0, 'medium': 0.0, 'high': 0.0}

        # Low membership
        if value <= low[1]:
            membership['low'] = 1.0
        elif low[1] < value < medium[0]:
            membership['low'] = (medium[0] - value) / (medium[0] - low[1])
            membership['medium'] = (value - low[1]) / (medium[0] - low[1])

        # Medium membership
        elif medium[0] <= value <= medium[1]:
            membership['medium'] = 1.0
        elif medium[1] < value < high[0]:
            membership['medium'] = (high[0] - value) / (high[0] - medium[1])
            membership['high'] = (value - medium[1]) / (high[0] - medium[1])

        # High membership
        elif value >= high[0]:
            membership['high'] = 1.0

        return membership

    def fuzzify_environmental(self, env_data: Dict) -> Dict:
        """
        Fuzzify environmental parameters
        """
        # Time risk mapping
        time_risk_map = {
            'low': 0.2,
            'moderate': 0.5,
            'moderate_high': 0.7,
            'high': 0.9
        }

        time_risk = time_risk_map.get(env_data.get('time_risk', 'moderate'), 0.5)

        # Light level risk (lux-based)
        lux = env_data['light_level']['lux']
        if lux < 10:
            light_risk = 0.95  # Very dim/dark
        elif lux < 50:
            light_risk = 0.8
        elif lux < 200:
            light_risk = 0.5
        else:
            light_risk = 0.2

        # Weather risk
        weather = env_data['weather']
        if weather.get('rain', False):
            weather_risk = 0.7
        elif weather.get('clouds', 0) > 80:
            weather_risk = 0.5
        else:
            weather_risk = 0.2

        # Speed-based risk
        speed = env_data['driving_context']['drive_speed']
        if speed < 0.5:
            speed_risk = 0.3  # Stopped/very slow
        elif speed < 30:
            speed_risk = 0.35  # Urban slow
        elif speed < 60:
            speed_risk = 0.45  # Normal
        elif speed < 80:
            speed_risk = 0.6  # Fast
        else:
            speed_risk = 0.75  # High-speed highway

        # Weighted environmental score
        env_score = (time_risk * 0.35 + light_risk * 0.30 +
                     weather_risk * 0.20 + speed_risk * 0.15)

        # Sensor reliability (based on light conditions)
        if lux < 10:
            reliability = 0.4  # Very low light - poor reliability
        elif lux < 50:
            reliability = 0.6
        elif lux > 100:
            reliability = 0.9
        else:
            reliability = 0.75

        fuzzy_membership = self.fuzzify(env_score, (0, 0.3), (0.3, 0.6), (0.6, 1.0))

        return {
            'score': env_score,
            'fuzzy': fuzzy_membership,
            'reliability': reliability,
            'components': {
                'time_risk': time_risk,
                'light_risk': light_risk,
                'weather_risk': weather_risk,
                'speed_risk': speed_risk,
                'lux_value': lux
            }
        }

    def fuzzify_physiological(self, phys_data: Dict) -> Dict:
        """
        Fuzzify physiological parameters from HRV/PPG analysis
        """
        if phys_data.get('status') != 'success':
            return {
                'score': 0.5,
                'fuzzy': {'low': 0, 'medium': 1, 'high': 0},
                'reliability': 0.3
            }

        # Extract stress probability
        probabilities = phys_data.get('probabilities', {})
        stress_level = probabilities.get('stressed', 0.4)
        relaxed_level = probabilities.get('relaxed', 0.5)
        normal_level = probabilities.get('normal', 0.1)
        confidence = phys_data.get('confidence', 0.5)

        # Calculate physiological fatigue score
        # Higher stress and lower relaxation indicate fatigue
        # Stressed state is the strongest indicator of fatigue
        phys_score = stress_level * 0.65 + (1 - relaxed_level) * 0.25 + normal_level * 0.1

        # Reliability based on prediction confidence
        if confidence > 0.65:
            reliability = 0.9
        elif confidence > 0.5:
            reliability = 0.75
        elif confidence > 0.4:
            reliability = 0.6
        else:
            reliability = 0.45

        fuzzy_membership = self.fuzzify(phys_score, (0, 0.3), (0.3, 0.6), (0.6, 1.0))

        return {
            'score': phys_score,
            'fuzzy': fuzzy_membership,
            'reliability': reliability,
            'label': phys_data.get('label', 'Unknown'),
            'confidence': confidence,
            'stress_level': stress_level
        }

    def fuzzify_behavioral(self, behave_data: Dict, light_level: float) -> Dict:
        """
        Fuzzify behavioral parameters from camera analysis
        Uses actual head pose (x_mean, y_mean, z_mean), MAR, and yawn data
        """
        if not behave_data:
            return {
                'score': 0.3,
                'fuzzy': {'low': 0.7, 'medium': 0.3, 'high': 0},
                'reliability': 0.3
            }

        # MAR (Mouth Aspect Ratio) - higher values indicate yawning/open mouth
        mar_mean = behave_data.get('mar_mean', 0.3)
        mar_score = min(1.0, mar_mean / 0.6)  # Normalize (typical yawn MAR > 0.5)

        # Yawn detection
        yawn_count = behave_data.get('yawn_count', 0)
        total_frames = behave_data.get('total_frames', 300)
        yawn_frequency = yawn_count / total_frames if total_frames > 0 else 0

        # Yawn score based on count
        if yawn_count >= 3:
            yawn_score = 0.9
        elif yawn_count >= 2:
            yawn_score = 0.7
        elif yawn_count >= 1:
            yawn_score = 0.5
        else:
            yawn_score = 0.0

        # Head pose analysis (x, y, z coordinates)
        x_mean = behave_data.get('x_mean', 0)  # Lateral movement
        y_mean = behave_data.get('y_mean', 0)  # Vertical movement (nodding)
        z_mean = behave_data.get('z_mean', 0)  # Forward/backward

        head_pose_score = 0

        # Y-axis: Nodding (negative y indicates head dropping)
        # Typical alert: y ~ -5 to -10, drowsy: y < -15
        if y_mean < -15:
            head_pose_score += 0.7  # Significant head drop
        elif y_mean < -10:
            head_pose_score += 0.4  # Moderate head drop

        # X-axis: Lateral tilt (indicates loss of posture control)
        if abs(x_mean) > 10:
            head_pose_score += 0.5
        elif abs(x_mean) > 5:
            head_pose_score += 0.3

        # Z-axis: Forward/backward lean
        if abs(z_mean) > 5:
            head_pose_score += 0.3

        head_pose_score = min(1.0, head_pose_score)

        # Combined behavioral score with updated weights
        # MAR and yawn are strong indicators, head pose provides context
        behave_score = min(1.0,
                           mar_score * 0.35 +
                           yawn_score * 0.40 +
                           head_pose_score * 0.25
                           )

        # Camera reliability based on lighting conditions
        if light_level < 5:
            reliability = 0.3  # Very poor in darkness
        elif light_level < 20:
            reliability = 0.5  # Poor in very dim light
        elif light_level < 50:
            reliability = 0.7  # Moderate
        elif light_level > 100:
            reliability = 0.95  # Excellent
        else:
            reliability = 0.8  # Good

        fuzzy_membership = self.fuzzify(behave_score, (0, 0.3), (0.3, 0.6), (0.6, 1.0))

        return {
            'score': behave_score,
            'fuzzy': fuzzy_membership,
            'reliability': reliability,
            'indicators': {
                'mar_score': round(mar_score, 3),
                'yawn_count': yawn_count,
                'yawn_score': yawn_score,
                'head_pose_score': round(head_pose_score, 3),
                'head_position': {
                    'x': round(x_mean, 2),
                    'y': round(y_mean, 2),
                    'z': round(z_mean, 2)
                }
            }
        }

    @staticmethod
    def calculate_adaptive_weights(env_fuzzy: Dict, phys_fuzzy: Dict,
                                   behave_fuzzy: Dict, env_data: Dict) -> Dict[str, float]:
        """
        Calculate adaptive weights (X, Y, Z) using fuzzy rules
        """
        # Base weights on sensor reliability
        total_reliability = (env_fuzzy['reliability'] +
                             phys_fuzzy['reliability'] +
                             behave_fuzzy['reliability'])

        w_env = env_fuzzy['reliability'] / total_reliability
        w_phys = phys_fuzzy['reliability'] / total_reliability
        w_behave = behave_fuzzy['reliability'] / total_reliability

        # Fuzzy Rule 1: Very low light AND behavioral unreliable → Boost physiological heavily
        lux = env_data['light_level']['lux']
        if lux < 10 and behave_fuzzy['reliability'] < 0.5:
            w_phys += 0.20
            w_behave -= 0.15
            w_env -= 0.05
        elif lux < 50 and behave_fuzzy['reliability'] < 0.7:
            w_phys += 0.12
            w_behave -= 0.08
            w_env -= 0.04

        # Fuzzy Rule 2: High environmental risk → Increase environmental weight
        if env_fuzzy['fuzzy']['high'] > 0.6:
            w_env += 0.12
            w_phys -= 0.06
            w_behave -= 0.06
        elif env_fuzzy['fuzzy']['high'] > 0.4:
            w_env += 0.08
            w_phys -= 0.04
            w_behave -= 0.04

        # Fuzzy Rule 3: Clear behavioral indicators AND good reliability → Boost behavioral
        if behave_fuzzy['fuzzy']['high'] > 0.6 and behave_fuzzy['reliability'] > 0.75:
            w_behave += 0.18
            w_phys -= 0.09
            w_env -= 0.09
        elif behave_fuzzy['fuzzy']['medium'] > 0.5 and behave_fuzzy['reliability'] > 0.7:
            w_behave += 0.10
            w_phys -= 0.05
            w_env -= 0.05

        # Fuzzy Rule 4: Nighttime/high risk time → Increase environmental weight
        time_risk = env_data.get('time_risk', 'moderate')
        if time_risk == 'high':
            w_env += 0.12
            w_phys -= 0.06
            w_behave -= 0.06
        elif time_risk == 'moderate_high':
            w_env += 0.08
            w_phys -= 0.04
            w_behave -= 0.04

        # Fuzzy Rule 5: High physiological stress → Trust physiological more
        if phys_fuzzy.get('stress_level', 0) > 0.65 and phys_fuzzy['reliability'] > 0.7:
            w_phys += 0.10
            w_env -= 0.05
            w_behave -= 0.05

        # Normalize weights to sum to 1.0
        total = w_env + w_phys + w_behave

        return {
            'environmental': max(0.05, w_env / total),  # Minimum 5%
            'physiological': max(0.05, w_phys / total),
            'behavioral': max(0.05, w_behave / total)
        }

    def defuzzify(self, fatigue_score: float) -> Dict:
        """
        Defuzzification: Convert fuzzy fatigue score to alert level
        """
        if fatigue_score >= self.alert_threshold['critical']:
            return {
                'level': 'CRITICAL',
                'action': 'STOP VEHICLE IMMEDIATELY - Driver severely fatigued',
                'color': 'red',
                'alert_type': 'audible_haptic_visual'
            }
        elif fatigue_score >= self.alert_threshold['warning']:
            return {
                'level': 'WARNING',
                'action': 'Take break within 10 minutes',
                'color': 'orange',
                'alert_type': 'visual_audible'
            }
        elif fatigue_score >= self.alert_threshold['caution']:
            return {
                'level': 'CAUTION',
                'action': 'Monitor closely - Consider rest stop',
                'color': 'yellow',
                'alert_type': 'visual'
            }
        else:
            return {
                'level': 'SAFE',
                'action': 'Normal driving condition',
                'color': 'green',
                'alert_type': 'none'
            }

    def process_sensor_data(self, sensor_json: Dict) -> Dict:
        """
        Main fuzzy inference engine
        """
        timestamp = datetime.now().isoformat()

        # Extract data sections
        env_data = sensor_json.get('environment', {})
        phys_data = sensor_json.get('physiological', {})
        behave_data = sensor_json.get('behaviour', {})  # Updated key name

        # Fuzzification stage
        env_fuzzy = self.fuzzify_environmental(env_data)
        phys_fuzzy = self.fuzzify_physiological(phys_data)
        behave_fuzzy = self.fuzzify_behavioral(behave_data, env_data['light_level']['lux'])

        # Calculate adaptive weights
        weights = self.calculate_adaptive_weights(env_fuzzy, phys_fuzzy, behave_fuzzy, env_data)

        # Fuzzy inference: Weighted aggregation
        fatigue_score = (
                env_fuzzy['score'] * weights['environmental'] +
                phys_fuzzy['score'] * weights['physiological'] +
                behave_fuzzy['score'] * weights['behavioral']
        )

        # Defuzzification: Determine alert
        alert = self.defuzzify(fatigue_score)

        # Store history
        self.fatigue_history.append({
            'timestamp': timestamp,
            'score': fatigue_score
        })

        # Keep only last 20 readings
        if len(self.fatigue_history) > 20:
            self.fatigue_history.pop(0)

        # Calculate trend
        trend = 'stable'
        if len(self.fatigue_history) >= 3:
            recent_scores = [h['score'] for h in self.fatigue_history[-3:]]
            if all(recent_scores[i] < recent_scores[i + 1] for i in range(len(recent_scores) - 1)):
                trend = 'increasing'
            elif all(recent_scores[i] > recent_scores[i + 1] for i in range(len(recent_scores) - 1)):
                trend = 'decreasing'

        # Build result
        result = {
            'timestamp': timestamp,
            'fatigue_score': round(fatigue_score, 3),
            'alert': alert,
            'trend': trend,
            'weights': {
                'X_environmental': round(weights['environmental'], 3),
                'Y_physiological': round(weights['physiological'], 3),
                'Z_behavioral': round(weights['behavioral'], 3)
            },
            'components': {
                'environmental': {
                    'score': round(env_fuzzy['score'], 3),
                    'reliability': round(env_fuzzy['reliability'], 2),
                    'fuzzy': {k: round(v, 3) for k, v in env_fuzzy['fuzzy'].items()},
                    'details': env_fuzzy['components']
                },
                'physiological': {
                    'score': round(phys_fuzzy['score'], 3),
                    'reliability': round(phys_fuzzy['reliability'], 2),
                    'label': phys_fuzzy.get('label', 'Unknown'),
                    'confidence': round(phys_fuzzy.get('confidence', 0), 3),
                    'stress_level': round(phys_fuzzy.get('stress_level', 0), 3),
                    'fuzzy': {k: round(v, 3) for k, v in phys_fuzzy['fuzzy'].items()}
                },
                'behavioral': {
                    'score': round(behave_fuzzy['score'], 3),
                    'reliability': round(behave_fuzzy['reliability'], 2),
                    'fuzzy': {k: round(v, 3) for k, v in behave_fuzzy['fuzzy'].items()},
                    'indicators': behave_fuzzy['indicators']
                }
            },
            'raw_sensor_data': sensor_json
        }

        return result
