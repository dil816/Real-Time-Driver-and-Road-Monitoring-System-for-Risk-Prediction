# ==========================================
# models.py - Pydantic Models for Data Validation
# ==========================================

from datetime import datetime
from typing import Dict, List, Optional, Literal, Any
from pydantic import BaseModel, Field


# ============ Serial Input Models ============

class HRVDataInput(BaseModel):
    """Raw HRV data from serial port"""
    type: Literal["hrv_data"]
    ibi: List[float] = Field(..., description="Inter-beat intervals in ms")
    timestamp: Optional[datetime] = None


class EnvironmentalDataInput(BaseModel):
    """Raw environmental data from serial port"""
    type: Literal["environmental"]
    environment: Dict[str, float]
    gps: Optional[Dict[str, float]] = None
    timestamp: Optional[datetime] = None


class BPMDataInput(BaseModel):
    """BPM display data (logging only)"""
    type: Literal["hrv_display"]
    BPM: float
    AvgBPM: float
    finger: bool
    progress: int
    timestamp: Optional[datetime] = None


# ============ Processed Data Models ============

class HRVFeatures(BaseModel):
    """Extracted HRV features"""
    MEAN_RR: float
    MEDIAN_RR: float
    SDRR: float
    RMSSD: float
    SDSD: float
    SDRR_RMSSD: float
    HR: float
    pNN25: float
    pNN50: float
    SD1: float
    SD2: float
    KURT: float
    SKEW: float
    SDRR_REL_RR: float
    RMSSD_REL_RR: float
    SDSD_REL_RR: float
    SDRR_RMSSD_REL_RR: float
    KURT_REL_RR: float
    SKEW_REL_RR: float


class PhysiologicalPrediction(BaseModel):
    """ML prediction from HRV features"""
    status: str
    prediction: int
    prediction_smooth: int
    label: str
    label_smooth: str
    confidence: float
    probabilities: Dict[str, float]
    timestamp: datetime


class EnvironmentalData(BaseModel):
    """Processed environmental data"""
    time_risk: str
    light_level: Dict[str, Any]  # ✓ Fixed: Any instead of any
    weather: Optional[Dict[str, Any]] = None  # ✓ Fixed
    driving_context: Optional[Dict[str, Any]] = None  # ✓ Fixed
    timestamp: datetime


class BehavioralData(BaseModel):
    """CNN-based behavioral inference"""
    x_mean: float
    y_mean: float
    z_mean: float
    mar_mean: float
    yawn_count: int
    yawn_frequency: float
    total_frames: int
    timestamp: datetime


# ============ Final Output Models ============

class FatigueAlert(BaseModel):
    """Alert level and recommended action"""
    level: str
    action: str
    color: str
    alert_type: str


class ComponentScore(BaseModel):
    """Individual component scoring"""
    score: float
    reliability: float
    fuzzy: Dict[str, float]


class FinalOutput(BaseModel):
    """Aggregated system output"""
    timestamp: datetime
    fatigue_score: float
    alert: FatigueAlert
    trend: str
    weights: Dict[str, float]
    components: Dict[str, Any]  # ✓ Fixed
    raw_sensor_data: Dict[str, Any]  # ✓ Fixed


# ==========================================
# config.py - Configuration Management
# ==========================================

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Serial Port Configuration
    SERIAL_PORT: str = "COM3"
    BAUDRATE: int = 115200
    SERIAL_TIMEOUT: float = 1.0

    # Model Paths
    HRV_MODEL_PATH: str = "./models/random_forest_model.pkl"
    MEDIAPIPE_MODEL_PATH: str = "./models/face_landmarker.task"

    # Processing Intervals
    HRV_WINDOW_SIZE: int = 100
    ENV_UPDATE_INTERVAL: int = 30  # seconds
    BEHAVIORAL_INTERVAL: int = 30  # seconds

    # Behavioral Detection
    BEHAVIORAL_BUFFER_SIZE: int = 300
    YAWN_MAR_THRESHOLD: float = 0.65
    YAWN_CONSEC_FRAMES: int = 3

    # API Configuration
    WEATHER_API_KEY: str = "your_api_key_here"
    WEATHER_CACHE_DURATION: int = 900  # 15 minutes

    # WebSocket Configuration
    WS_HOST: str = "localhost"
    WS_PORT: int = 8765

    # FastAPI Configuration
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    API_TITLE: str = "Driver Fatigue Detection System"
    API_VERSION: str = "2.0.0"

    # Queue Sizes
    MAX_QUEUE_SIZE: int = 100

    # Logging
    LOG_LEVEL: str = "INFO"

    class Config:
        env_file = ".env"


settings = Settings()

# ==========================================
# events.py - Event System for Loose Coupling
# ==========================================

from typing import Callable, Dict, List
import asyncio
from enum import Enum


class EventType(str, Enum):
    """System event types"""
    HRV_DATA_RECEIVED = "hrv_data_received"
    ENV_DATA_RECEIVED = "env_data_received"
    BPM_DATA_RECEIVED = "bpm_data_received"

    HRV_FEATURES_EXTRACTED = "hrv_features_extracted"
    ENV_DATA_PROCESSED = "env_data_processed"
    BEHAVIORAL_DATA_READY = "behavioral_data_ready"

    PHYSIOLOGICAL_PREDICTED = "physiological_predicted"

    FINAL_OUTPUT_READY = "final_output_ready"

    SYSTEM_ERROR = "system_error"


class EventBus:
    """Simple event bus for decoupling components"""

    def __init__(self):
        self._subscribers: Dict[EventType, List[Callable]] = {}
        self._async_subscribers: Dict[EventType, List[Callable]] = {}

    def subscribe(self, event_type: EventType, callback: Callable):
        """Subscribe to synchronous events"""
        if event_type not in self._subscribers:
            self._subscribers[event_type] = []
        self._subscribers[event_type].append(callback)

    def subscribe_async(self, event_type: EventType, callback: Callable):
        """Subscribe to asynchronous events"""
        if event_type not in self._async_subscribers:
            self._async_subscribers[event_type] = []
        self._async_subscribers[event_type].append(callback)

    def publish(self, event_type: EventType, data: any):
        """Publish synchronous event"""
        if event_type in self._subscribers:
            for callback in self._subscribers[event_type]:
                try:
                    callback(data)
                except Exception as e:
                    print(f"Error in event handler: {e}")

    async def publish_async(self, event_type: EventType, data: any):
        """Publish asynchronous event"""
        tasks = []
        if event_type in self._async_subscribers:
            for callback in self._async_subscribers[event_type]:
                tasks.append(asyncio.create_task(callback(data)))

        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)


# Global event bus instance
event_bus = EventBus()

# ==========================================
# services/serial_reader_service.py
# ==========================================

import json
import serial
import asyncio
from typing import Optional
# from config import settings
# from models import HRVDataInput, EnvironmentalDataInput, BPMDataInput
# from events import event_bus, EventType
import logging

logger = logging.getLogger(__name__)


class SerialReaderService:
    """Reads data from serial port and publishes to event bus"""

    def __init__(self):
        self.serial_conn: Optional[serial.Serial] = None
        self.running = False

    async def connect(self) -> bool:
        """Establish serial connection"""
        try:
            self.serial_conn = serial.Serial(
                port=settings.SERIAL_PORT,
                baudrate=settings.BAUDRATE,
                timeout=settings.SERIAL_TIMEOUT
            )
            logger.info(f"Connected to {settings.SERIAL_PORT}")
            await asyncio.sleep(2)
            return True
        except serial.SerialException as e:
            logger.error(f"Serial connection failed: {e}")
            return False

    async def start(self):
        """Start reading from serial port"""
        if not await self.connect():
            raise ConnectionError("Cannot start serial reader")

        self.running = True
        asyncio.create_task(self._read_loop())
        logger.info("Serial reader started")

    async def stop(self):
        """Stop reading and close connection"""
        self.running = False
        if self.serial_conn and self.serial_conn.is_open:
            self.serial_conn.close()
        logger.info("Serial reader stopped")

    async def _read_loop(self):
        """Main reading loop"""
        while self.running:
            try:
                if self.serial_conn.in_waiting > 0:
                    line = self.serial_conn.readline().decode('utf-8', errors='ignore').strip()
                    if line:
                        await self._process_line(line)
                else:
                    await asyncio.sleep(0.01)
            except Exception as e:
                logger.error(f"Read error: {e}")
                await asyncio.sleep(1)

    async def _process_line(self, line: str):
        """Parse and route data based on type"""
        try:
            data = json.loads(line)
            data_type = data.get('type')

            if data_type == 'hrv_data':
                hrv_data = HRVDataInput(**data)
                await event_bus.publish_async(EventType.HRV_DATA_RECEIVED, hrv_data)

            elif data_type == 'environmental':
                env_data = EnvironmentalDataInput(**data)
                await event_bus.publish_async(EventType.ENV_DATA_RECEIVED, env_data)

            elif data_type == 'hrv_display':
                bpm_data = BPMDataInput(**data)
                await event_bus.publish_async(EventType.BPM_DATA_RECEIVED, bpm_data)
                # Log only
                logger.info(f"BPM: {bpm_data.BPM:.1f} | Avg: {bpm_data.AvgBPM}")

        except json.JSONDecodeError:
            pass
        except Exception as e:
            logger.error(f"Line processing error: {e}")


# ==========================================
# services/hrv_processor_service.py
# ==========================================

from collections import deque
from datetime import datetime
import numpy as np
from scipy.stats import skew, kurtosis
from typing import Optional
# from models import HRVDataInput, HRVFeatures
# from events import event_bus, EventType
# from config import settings
import logging

logger = logging.getLogger(__name__)


class HRVProcessorService:
    """Processes HRV data and extracts features"""

    def __init__(self):
        self.feature_queue = deque(maxlen=settings.HRV_WINDOW_SIZE)
        self.feature_count = 0
        self.last_process_time = 0

        # Subscribe to HRV data events
        event_bus.subscribe_async(EventType.HRV_DATA_RECEIVED, self.on_hrv_data)

    async def on_hrv_data(self, data: HRVDataInput):
        """Handle incoming HRV data"""
        ibi_array = np.array(data.ibi)
        features = self._extract_features(ibi_array)

        if features:
            self.feature_queue.append(features)
            self.feature_count += 1

            # Check if we should trigger aggregation
            current_time = datetime.now().timestamp()
            if current_time - self.last_process_time >= settings.ENV_UPDATE_INTERVAL:
                await self._aggregate_and_publish()
                self.last_process_time = current_time

    def _remove_outliers(self, rr: np.ndarray, threshold: float = 0.25) -> np.ndarray:
        """Remove outliers from RR intervals"""
        if len(rr) < 3:
            return rr

        cleaned = [rr[0]]
        for i in range(1, len(rr) - 1):
            avg_neighbor = (rr[i - 1] + rr[i + 1]) / 2
            diff_percent = abs(rr[i] - avg_neighbor) / avg_neighbor
            if diff_percent < threshold:
                cleaned.append(rr[i])
        cleaned.append(rr[-1])

        return np.array(cleaned)

    def _extract_features(self, ibi_values: np.ndarray) -> Optional[HRVFeatures]:
        """Extract 19 HRV features"""
        if len(ibi_values) < 10:
            return None

        rr = np.array(ibi_values, dtype=float)
        rr = rr[(rr >= 300) & (rr <= 2000)]

        if len(rr) < 10:
            return None

        rr = self._remove_outliers(rr)
        if len(rr) < 10:
            return None

        # Calculate features
        mean_rr = np.mean(rr)
        median_rr = np.median(rr)
        mean_hr = 60000 / mean_rr

        diff_rr = np.diff(rr)
        sdnn = np.std(rr, ddof=1)
        rmssd = np.sqrt(np.mean(diff_rr ** 2))
        sdsd = np.std(diff_rr, ddof=1)
        sdrr_rmssd = sdnn / rmssd if rmssd != 0 else np.nan

        pnn25 = np.sum(np.abs(diff_rr) > 25) / len(diff_rr) * 100 if len(diff_rr) > 0 else 0
        pnn50 = np.sum(np.abs(diff_rr) > 50) / len(diff_rr) * 100 if len(diff_rr) > 0 else 0

        sd1 = np.sqrt(0.5 * (sdsd ** 2))
        sd2 = np.sqrt(np.maximum(0, 2 * (sdnn ** 2) - 0.5 * (sdsd ** 2)))

        kurt = kurtosis(rr, fisher=True) if len(rr) > 2 else np.nan
        skewness = skew(rr) if len(rr) > 2 else np.nan

        sdrr_rel = sdnn / mean_rr if mean_rr != 0 else np.nan
        rmssd_rel = rmssd / mean_rr if mean_rr != 0 else np.nan
        sdsd_rel = sdsd / mean_rr if mean_rr != 0 else np.nan
        sdrr_rmssd_rel = sdrr_rmssd / mean_rr if mean_rr != 0 else np.nan
        kurt_rel = kurt / mean_rr if mean_rr != 0 else np.nan
        skew_rel = skewness / mean_rr if mean_rr != 0 else np.nan

        return HRVFeatures(
            MEAN_RR=mean_rr, MEDIAN_RR=median_rr, SDRR=sdnn, RMSSD=rmssd,
            SDSD=sdsd, SDRR_RMSSD=sdrr_rmssd, HR=mean_hr, pNN25=pnn25,
            pNN50=pnn50, SD1=sd1, SD2=sd2, KURT=kurt, SKEW=skewness,
            SDRR_REL_RR=sdrr_rel, RMSSD_REL_RR=rmssd_rel, SDSD_REL_RR=sdsd_rel,
            SDRR_RMSSD_REL_RR=sdrr_rmssd_rel, KURT_REL_RR=kurt_rel,
            SKEW_REL_RR=skew_rel
        )

    async def _aggregate_and_publish(self):
        """Aggregate features and publish for ML inference"""
        if not self.feature_queue:
            return

        features_list = list(self.feature_queue)
        await event_bus.publish_async(EventType.HRV_FEATURES_EXTRACTED, features_list)


# ==========================================
# services/environmental_processor_service.py
# ==========================================

from datetime import datetime
import time
import requests
from typing import Optional, Dict
# from models import EnvironmentalDataInput, EnvironmentalData
# from events import event_bus, EventType
# from config import settings
import logging

logger = logging.getLogger(__name__)


class EnvironmentalProcessorService:
    """Processes environmental sensor data"""

    def __init__(self):
        self.last_weather_update = 0
        self.weather_cache = {}

        event_bus.subscribe_async(EventType.ENV_DATA_RECEIVED, self.on_env_data)

    async def on_env_data(self, data: EnvironmentalDataInput):
        """Process environmental data"""
        processed = EnvironmentalData(
            time_risk=self._get_time_risk_factor(),
            light_level=self._classify_light_level(data.environment.get('lux', 0)),
            weather=None,
            driving_context=None,
            timestamp=datetime.now()
        )

        # Add GPS-based data if available
        if data.gps:
            processed.weather = self._get_weather(
                data.gps.get('lat'), data.gps.get('lng')
            )
            processed.driving_context = self._determine_driving_context(
                data.gps.get('lat'), data.gps.get('lng'), data.gps.get('speed_kmh', 0)
            )

        await event_bus.publish_async(EventType.ENV_DATA_PROCESSED, processed)

    def _get_time_risk_factor(self) -> str:
        """Calculate risk based on circadian rhythm"""
        hour = datetime.now().hour

        if 2 <= hour < 6:
            return 'high'
        elif 12 <= hour < 14:
            return 'moderate_high'
        elif (6 <= hour < 8) or (22 <= hour or hour < 2):
            return 'moderate'
        else:
            return 'low'

    def _classify_light_level(self, lux: float) -> Dict:
        """Classify light conditions"""
        if lux < 1:
            condition = 'dark'
        elif lux < 10:
            condition = 'very_dim'
        elif lux < 50:
            condition = 'dim'
        elif lux < 200:
            condition = 'indoor'
        elif lux < 1000:
            condition = 'overcast'
        else:
            condition = 'bright'

        return {'lux': lux, 'light_condition': condition}

    def _get_weather(self, lat: float, lon: float) -> Optional[Dict]:
        """Fetch weather data with caching"""
        current_time = time.time()

        if current_time - self.last_weather_update < settings.WEATHER_CACHE_DURATION:
            return self.weather_cache

        try:
            url = f"http://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={settings.WEATHER_API_KEY}"
            response = requests.get(url, timeout=5)

            if response.status_code == 200:
                data = response.json()
                weather_info = {
                    'condition': data['weather'][0]['main'],
                    'description': data['weather'][0]['description'],
                    'rain': 'rain' in data,
                    'rain_1h': data.get('rain', {}).get('1h', 0),
                    'clouds': data['clouds']['all'],
                    'visibility': data.get('visibility', 10000)
                }

                self.weather_cache = weather_info
                self.last_weather_update = current_time
                return weather_info
        except Exception as e:
            logger.error(f"Weather API error: {e}")
            return self.weather_cache

    def _determine_driving_context(self, lat: float, lon: float, speed: float) -> Optional[Dict]:
        """Determine road type and context"""
        try:
            headers = {'User-Agent': 'FatigueDetectionSystem/2.0'}
            url = f"https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lon}&format=json"
            response = requests.get(url, headers=headers, timeout=5)
            response.raise_for_status()

            data = response.json()
            return {
                'road_name': data.get('name', 'N/A'),
                'road_type': data.get('type', 'N/A'),
                'drive_speed': speed
            }
        except Exception as e:
            logger.error(f"Driving context error: {e}")
            return None


# ==========================================
# services/behavioral_processor_service.py
# ==========================================

import cv2
import mediapipe as mp
import numpy as np
from collections import deque
from datetime import datetime
import asyncio
from typing import Optional
# from models import BehavioralData
# from events import event_bus, EventType
# from config import settings
import logging

logger = logging.getLogger(__name__)


class BehavioralProcessorService:
    """CNN-based behavioral analysis using MediaPipe"""

    def __init__(self):
        self.buffer = deque(maxlen=settings.BEHAVIORAL_BUFFER_SIZE)
        self.yawn_counter = 0
        self.total_yawns = 0
        self.yawning = False
        self.last_publish_time = 0

        self._init_mediapipe()

    def _init_mediapipe(self):
        """Initialize MediaPipe Face Landmarker"""
        BaseOptions = mp.tasks.BaseOptions
        FaceLandmarker = mp.tasks.vision.FaceLandmarker
        FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
        VisionRunningMode = mp.tasks.vision.RunningMode

        options = FaceLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=settings.MEDIAPIPE_MODEL_PATH),
            running_mode=VisionRunningMode.VIDEO,
            output_face_blendshapes=True,
            output_facial_transformation_matrixes=True,
            num_faces=1
        )
        self.landmarker = FaceLandmarker.create_from_options(options)

    async def process_frame(self, frame: np.ndarray, timestamp_ms: int):
        """Process single video frame"""
        img_h, img_w, _ = frame.shape

        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)

        results = self.landmarker.detect_for_video(mp_image, timestamp_ms)

        if results.face_landmarks:
            for face_landmarks in results.face_landmarks:
                x_angle, y_angle, z_angle, _ = self._calculate_head_pose(
                    face_landmarks, img_w, img_h
                )

                mar = self._calculate_mouth_aspect_ratio(face_landmarks, img_w, img_h)
                is_yawning = self._process_yawn_detection(mar)

                data_point = {
                    'timestamp': timestamp_ms,
                    'x_angle': float(x_angle),
                    'y_angle': float(y_angle),
                    'z_angle': float(z_angle),
                    'yawning': is_yawning,
                    'yawn_count': self.total_yawns,
                    'mar': float(mar)
                }

                self.buffer.append(data_point)

                # Check if we should publish aggregated data
                current_time = datetime.now().timestamp()
                if current_time - self.last_publish_time >= settings.BEHAVIORAL_INTERVAL:
                    await self._aggregate_and_publish()
                    self.last_publish_time = current_time

    def _calculate_mouth_aspect_ratio(self, face_landmarks, img_w: int, img_h: int) -> float:
        """Calculate MAR for yawn detection"""
        MOUTH_VERTICAL_INDICES = [(13, 14), (78, 308), (81, 311)]

        if not face_landmarks or len(face_landmarks) < 312:
            return 0

        total_vertical_dist = 0
        for top_idx, bottom_idx in MOUTH_VERTICAL_INDICES:
            top = face_landmarks[top_idx]
            bottom = face_landmarks[bottom_idx]
            dx = (top.x - bottom.x) * img_w
            dy = (top.y - bottom.y) * img_h
            total_vertical_dist += np.sqrt(dx ** 2 + dy ** 2)

        left = face_landmarks[61]
        right = face_landmarks[291]
        dx = (left.x - right.x) * img_w
        dy = (left.y - right.y) * img_h
        horizontal_dist = np.sqrt(dx ** 2 + dy ** 2)

        if horizontal_dist == 0:
            return 0

        mar = (total_vertical_dist / len(MOUTH_VERTICAL_INDICES)) / horizontal_dist
        return mar

    def _calculate_head_pose(self, face_landmarks, img_w: int, img_h: int):
        """Calculate head pose angles"""
        face_3d = []
        face_2d = []
        target_indices = [1, 33, 61, 199, 263, 291]

        nose_2d = None
        for idx in target_indices:
            lm = face_landmarks[idx]
            if idx == 1:
                nose_2d = (lm.x * img_w, lm.y * img_h)

            x, y = int(lm.x * img_w), int(lm.y * img_h)
            face_2d.append([x, y])
            face_3d.append([x, y, lm.z])

        face_2d = np.array(face_2d, dtype=np.float64)
        face_3d = np.array(face_3d, dtype=np.float64)

        focal_length = 1 * img_w
        cam_matrix = np.array([
            [focal_length, 0, img_w / 2],
            [0, focal_length, img_h / 2],
            [0, 0, 1]
        ])
        dist_matrix = np.zeros((4, 1), dtype=np.float64)

        success, rot_vec, trans_vec = cv2.solvePnP(face_3d, face_2d, cam_matrix, dist_matrix)

        rmat, _ = cv2.Rodrigues(rot_vec)
        angles, _, _, _, _, _ = cv2.RQDecomp3x3(rmat)

        x_angle = angles[0] * 360
        y_angle = angles[1] * 360
        z_angle = angles[2] * 360

        return x_angle, y_angle, z_angle, nose_2d

    def _process_yawn_detection(self, mar: float) -> bool:
        """Detect yawning based on MAR"""
        if mar > settings.YAWN_MAR_THRESHOLD:
            self.yawn_counter += 1
            if self.yawn_counter >= settings.YAWN_CONSEC_FRAMES:
                if not self.yawning:
                    self.total_yawns += 1
                    self.yawning = True
        else:
            self.yawn_counter = 0
            self.yawning = False

        return self.yawning

    async def _aggregate_and_publish(self):
        """Aggregate buffer data and publish"""
        if not self.buffer:
            return

        buffer_list = list(self.buffer)

        behavioral_data = BehavioralData(
            x_mean=np.mean([d['x_angle'] for d in buffer_list]),
            y_mean=np.mean([d['y_angle'] for d in buffer_list]),
            z_mean=np.mean([d['z_angle'] for d in buffer_list]),
            mar_mean=np.mean([d['mar'] for d in buffer_list]),
            yawn_count=max([d['yawn_count'] for d in buffer_list]),
            yawn_frequency=sum([d['yawning'] for d in buffer_list]) / len(buffer_list),
            total_frames=len(buffer_list),
            timestamp=datetime.now()
        )

        await event_bus.publish_async(EventType.BEHAVIORAL_DATA_READY, behavioral_data)


# ==========================================
# services/ml_inference_service.py
# ==========================================

import joblib
import pandas as pd
import numpy as np
from pathlib import Path
from collections import deque
from datetime import datetime
from typing import List
# from models import HRVFeatures, PhysiologicalPrediction
# from events import event_bus, EventType
# from config import settings
import logging

logger = logging.getLogger(__name__)


class MLInferenceService:
    """Machine learning inference for stress/fatigue prediction"""

    def __init__(self):
        self.model = None
        self.prediction_history = deque(maxlen=5)
        self.stress_labels = {0: 'Relaxed', 1: 'Normal', 2: 'Stressed'}

        self._load_model()
        event_bus.subscribe_async(EventType.HRV_FEATURES_EXTRACTED, self.on_features_ready)

    def _load_model(self):
        """Load trained ML model"""
        try:
            model_path = Path(settings.HRV_MODEL_PATH)
            if not model_path.exists():
                raise FileNotFoundError(f"Model not found: {model_path}")

            self.model = joblib.load(model_path)
            logger.info(f"Model loaded: {model_path.name}")
        except Exception as e:
            logger.error(f"Model loading failed: {e}")
            raise

    async def on_features_ready(self, features_list: List[HRVFeatures]):
        """Perform inference on extracted features"""
        if not features_list:
            return

        # Convert to DataFrame
        df = pd.DataFrame([f.dict() for f in features_list])
        df_filled = df.fillna(df.median())

        try:
            # Predict
            predictions = self.model.predict(df_filled)
            probabilities = self.model.predict_proba(df_filled)

            # Aggregate predictions
            pred = int(np.argmax(np.bincount(predictions)))
            prob = np.mean(probabilities, axis=0)

            # Smoothing with history
            self.prediction_history.append(pred)
            if len(self.prediction_history) >= 3:
                smoothed = int(np.median(list(self.prediction_history)))
            else:
                smoothed = pred

            # Create prediction object
            prediction = PhysiologicalPrediction(
                status='success',
                prediction=pred,
                prediction_smooth=smoothed,
                label=self.stress_labels[pred],
                label_smooth=self.stress_labels[smoothed],
                confidence=float(max(prob)),
                probabilities={
                    'relaxed': float(prob[0]),
                    'normal': float(prob[1]),
                    'stressed': float(prob[2])
                },
                timestamp=datetime.now()
            )

            await event_bus.publish_async(EventType.PHYSIOLOGICAL_PREDICTED, prediction)
            logger.info(f"Prediction: {prediction.label_smooth} (conf: {prediction.confidence:.2f})")

        except Exception as e:
            logger.error(f"Inference error: {e}")


# ==========================================
# services/aggregator_service.py
# ==========================================

from typing import Optional
from datetime import datetime
# from models import (
#     EnvironmentalData, PhysiologicalPrediction,
#     BehavioralData, FinalOutput
# )
# from events import event_bus, EventType
# from config import settings
import logging

logger = logging.getLogger(__name__)


class AggregatorService:
    """Aggregates data from all three sources"""

    def __init__(self):
        self.env_data: Optional[EnvironmentalData] = None
        self.phys_data: Optional[PhysiologicalPrediction] = None
        self.behav_data: Optional[BehavioralData] = None

        # Subscribe to all data sources
        event_bus.subscribe_async(EventType.ENV_DATA_PROCESSED, self.on_env_data)
        event_bus.subscribe_async(EventType.PHYSIOLOGICAL_PREDICTED, self.on_phys_data)
        event_bus.subscribe_async(EventType.BEHAVIORAL_DATA_READY, self.on_behav_data)

    async def on_env_data(self, data: EnvironmentalData):
        """Store environmental data"""
        self.env_data = data
        await self._try_aggregate()

    async def on_phys_data(self, data: PhysiologicalPrediction):
        """Store physiological prediction"""
        self.phys_data = data
        await self._try_aggregate()

    async def on_behav_data(self, data: BehavioralData):
        """Store behavioral data"""
        self.behav_data = data
        await self._try_aggregate()

    async def _try_aggregate(self):
        """Check if all data is available and aggregate"""
        if not all([self.env_data, self.phys_data, self.behav_data]):
            return

        # Create combined JSON
        combined_data = {
            'environment': self.env_data.dict(),
            'physiological': self.phys_data.dict(),
            'behaviour': self.behav_data.dict()
        }

        # Publish to fuzzy logic processor
        await event_bus.publish_async(EventType.FINAL_OUTPUT_READY, combined_data)

        logger.info("Data aggregated - sent to fuzzy processor")

        # Reset for next cycle
        self.env_data = None
        self.phys_data = None
        self.behav_data = None


# ==========================================
# services/fuzzy_logic_service.py
# ==========================================

from typing import Dict, Tuple
from datetime import datetime
# from models import FinalOutput, FatigueAlert
# from events import event_bus, EventType
import logging

logger = logging.getLogger(__name__)


class FuzzyLogicService:
    """Fuzzy logic system for final fatigue assessment"""

    def __init__(self):
        self.alert_threshold = {
            'safe': 0.3,
            'caution': 0.5,
            'warning': 0.7,
            'critical': 0.85
        }
        self.fatigue_history = []

        event_bus.subscribe_async(EventType.FINAL_OUTPUT_READY, self.process_data)

    async def process_data(self, sensor_json: Dict):
        """Main fuzzy inference engine"""
        timestamp = datetime.now().isoformat()

        env_data = sensor_json.get('environment', {})
        phys_data = sensor_json.get('physiological', {})
        behav_data = sensor_json.get('behaviour', {})

        # Fuzzification
        env_fuzzy = self._fuzzify_environmental(env_data)
        phys_fuzzy = self._fuzzify_physiological(phys_data)
        behav_fuzzy = self._fuzzify_behavioral(behav_data, env_data['light_level']['lux'])

        # Adaptive weights
        weights = self._calculate_adaptive_weights(env_fuzzy, phys_fuzzy, behav_fuzzy, env_data)

        # Fuzzy inference
        fatigue_score = (
                env_fuzzy['score'] * weights['environmental'] +
                phys_fuzzy['score'] * weights['physiological'] +
                behav_fuzzy['score'] * weights['behavioral']
        )

        # Defuzzification
        alert = self._defuzzify(fatigue_score)

        # Track history
        self.fatigue_history.append({'timestamp': timestamp, 'score': fatigue_score})
        if len(self.fatigue_history) > 20:
            self.fatigue_history.pop(0)

        # Calculate trend
        trend = self._calculate_trend()

        # Build result
        result = FinalOutput(
            timestamp=datetime.now(),
            fatigue_score=round(fatigue_score, 3),
            alert=alert,
            trend=trend,
            weights={
                'X_environmental': round(weights['environmental'], 3),
                'Y_physiological': round(weights['physiological'], 3),
                'Z_behavioral': round(weights['behavioral'], 3)
            },
            components={
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
                    'score': round(behav_fuzzy['score'], 3),
                    'reliability': round(behav_fuzzy['reliability'], 2),
                    'fuzzy': {k: round(v, 3) for k, v in behav_fuzzy['fuzzy'].items()},
                    'indicators': behav_fuzzy['indicators']
                }
            },
            raw_sensor_data=sensor_json
        )

        # Broadcast final result (for WebSocket, API, etc.)
        await event_bus.publish_async(EventType.FINAL_OUTPUT_READY, result)
        logger.info(f"Fatigue: {result.alert.level} | Score: {fatigue_score:.2f}")

    # ... (Include all fuzzy logic methods from original FuzzyProcessor)
    # _fuzzify, _fuzzify_environmental, _fuzzify_physiological, _fuzzify_behavioral
    # _calculate_adaptive_weights, _defuzzify, _calculate_trend

    def _defuzzify(self, fatigue_score: float) -> FatigueAlert:
        """Convert score to alert level"""
        if fatigue_score >= self.alert_threshold['critical']:
            return FatigueAlert(
                level='CRITICAL',
                action='STOP VEHICLE IMMEDIATELY',
                color='red',
                alert_type='audible_haptic_visual'
            )
        elif fatigue_score >= self.alert_threshold['warning']:
            return FatigueAlert(
                level='WARNING',
                action='Take break within 10 minutes',
                color='orange',
                alert_type='visual_audible'
            )
        elif fatigue_score >= self.alert_threshold['caution']:
            return FatigueAlert(
                level='CAUTION',
                action='Monitor closely',
                color='yellow',
                alert_type='visual'
            )
        else:
            return FatigueAlert(
                level='SAFE',
                action='Normal driving',
                color='green',
                alert_type='none'
            )

    def _calculate_trend(self) -> str:
        """Calculate fatigue trend"""
        if len(self.fatigue_history) < 3:
            return 'stable'

        recent_scores = [h['score'] for h in self.fatigue_history[-3:]]
        if all(recent_scores[i] < recent_scores[i + 1] for i in range(len(recent_scores) - 1)):
            return 'increasing'
        elif all(recent_scores[i] > recent_scores[i + 1] for i in range(len(recent_scores) - 1)):
            return 'decreasing'
        return 'stable'


# ==========================================
# api/app.py - FastAPI Application
# ==========================================

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from typing import List
import asyncio
import json
import logging

# from config import settings
# from events import event_bus, EventType
# from models import FinalOutput

# Import all services
# from services.serial_reader_service import SerialReaderService
# from services.hrv_processor_service import HRVProcessorService
# from services.environmental_processor_service import EnvironmentalProcessorService
# from services.behavioral_processor_service import BehavioralProcessorService
# from services.ml_inference_service import MLInferenceService
# from services.aggregator_service import AggregatorService
# from services.fuzzy_logic_service import FuzzyLogicService

logger = logging.getLogger(__name__)


# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"WebSocket connected. Total: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
        logger.info(f"WebSocket disconnected. Total: {len(self.active_connections)}")

    async def broadcast(self, data: dict):
        disconnected = []
        for connection in self.active_connections:
            try:
                await connection.send_json(data)
            except Exception:
                disconnected.append(connection)

        for conn in disconnected:
            self.active_connections.remove(conn)


manager = ConnectionManager()

# Service instances
services = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle management"""
    logger.info("Starting Fatigue Detection System...")

    # Initialize all services
    services['serial_reader'] = SerialReaderService()
    services['hrv_processor'] = HRVProcessorService()
    services['env_processor'] = EnvironmentalProcessorService()
    services['behavioral_processor'] = BehavioralProcessorService()
    services['ml_inference'] = MLInferenceService()
    services['aggregator'] = AggregatorService()
    services['fuzzy_logic'] = FuzzyLogicService()

    # Subscribe to final output for WebSocket broadcast
    event_bus.subscribe_async(EventType.FINAL_OUTPUT_READY, broadcast_final_output)

    # Start serial reader
    await services['serial_reader'].start()

    logger.info("✓ All services initialized")

    yield

    # Cleanup
    logger.info("Shutting down services...")
    await services['serial_reader'].stop()


async def broadcast_final_output(data: FinalOutput):
    """Broadcast final output to all WebSocket clients"""
    await manager.broadcast(data.dict() if hasattr(data, 'dict') else data)


# Create FastAPI app
app = FastAPI(
    title=settings.API_TITLE,
    version=settings.API_VERSION,
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ==========================================
# API Endpoints
# ==========================================

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "running",
        "service": settings.API_TITLE,
        "version": settings.API_VERSION
    }


@app.get("/api/v1/status")
async def get_status():
    """Get system status"""
    return {
        "serial_connected": services['serial_reader'].serial_conn is not None,
        "model_loaded": services['ml_inference'].model is not None,
        "active_connections": len(manager.active_connections)
    }


@app.get("/api/v1/history")
async def get_fatigue_history():
    """Get recent fatigue score history"""
    return {
        "history": services['fuzzy_logic'].fatigue_history
    }


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time data streaming"""
    await manager.connect(websocket)
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)


# ==========================================
# main.py - Application Entry Point
# ==========================================

import uvicorn
import logging
# from config import settings

logging.basicConfig(
    level=settings.LOG_LEVEL,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

if __name__ == "__main__":
    uvicorn.run(
        "api.app:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=False,
        log_level=settings.LOG_LEVEL.lower()
    )

# ==========================================
# camera_service.py - Separate Camera Process
# ==========================================

import cv2
import asyncio
import time
# from services.behavioral_processor_service import BehavioralProcessorService
# from config import settings
import logging

logger = logging.getLogger(__name__)


async def run_camera_service():
    """Run camera processing in separate process"""
    processor = BehavioralProcessorService()
    cap = cv2.VideoCapture(0)

    logger.info("Camera service started")

    try:
        while cap.isOpened():
            success, frame = cap.read()
            if not success:
                break

            frame = cv2.flip(frame, 1)
            timestamp_ms = int(time.time() * 1000)

            # Process frame asynchronously
            await processor.process_frame(frame, timestamp_ms)

            # Optional: Display frame
            cv2.imshow('Fatigue Detection', frame)

            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

            await asyncio.sleep(0.01)  # ~100 FPS max

    finally:
        cap.release()
        cv2.destroyAllWindows()
        logger.info("Camera service stopped")


# ==========================================
# PROJECT STRUCTURE
# ==========================================

"""
fatigue_detection_system/
│
├── models.py                      # Pydantic models for data validation
├── config.py                      # Configuration management
├── events.py                      # Event bus for loose coupling
│
├── services/
│   ├── __init__.py
│   ├── serial_reader_service.py          # Serial port reader
│   ├── hrv_processor_service.py          # HRV feature extraction
│   ├── environmental_processor_service.py # Environmental data processing
│   ├── behavioral_processor_service.py    # MediaPipe behavioral analysis
│   ├── ml_inference_service.py           # ML model inference
│   ├── aggregator_service.py             # Data aggregation
│   └── fuzzy_logic_service.py            # Fuzzy logic fatigue assessment
│
├── api/
│   ├── __init__.py
│   └── app.py                     # FastAPI application
│
├── camera_service.py              # Separate camera processing service
├── main.py                        # Main entry point
│
├── models/
│   ├── random_forest_model.pkl    # Trained ML model
│   └── face_landmarker.task       # MediaPipe model
│
├── requirements.txt
├── .env                           # Environment variables
└── README.md
"""

# ==========================================
# requirements.txt
# ==========================================

"""
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
pydantic-settings==2.1.0
websockets==12.0
pyserial==3.5
numpy==1.24.3
pandas==2.0.3
scikit-learn==1.3.0
scipy==1.11.2
opencv-python==4.8.1.78
mediapipe==0.10.8
joblib==1.3.2
requests==2.31.0
python-multipart==0.0.6
"""

# ==========================================
# .env (Example)
# ==========================================

"""
SERIAL_PORT=COM3
BAUDRATE=115200
HRV_MODEL_PATH=./models/random_forest_model.pkl
MEDIAPIPE_MODEL_PATH=./models/face_landmarker.task
WEATHER_API_KEY=your_openweather_api_key
WS_HOST=localhost
WS_PORT=8765
API_HOST=0.0.0.0
API_PORT=8000
LOG_LEVEL=INFO
"""

# ==========================================
# README.md
# ==========================================

"""
# Driver Fatigue Detection System v2.0

## Architecture Overview

This system uses an **event-driven, loosely-coupled architecture** with FastAPI for real-time driver fatigue detection.

### Key Components

1. **SerialReaderService**: Reads JSON data from ESP32
   - HRV data (IBI arrays)
   - Environmental data (sensors)
   - BPM display data (logging only)

2. **HRVProcessorService**: 
   - Extracts 19 HRV features
   - Aggregates features over 30-second windows
   - Publishes to ML inference

3. **EnvironmentalProcessorService**:
   - Processes sensor data
   - Fetches weather data (cached)
   - Determines driving context

4. **BehavioralProcessorService**:
   - MediaPipe face landmark detection
   - Head pose estimation
   - Yawn detection (MAR)
   - Aggregates over 30-second windows

5. **MLInferenceService**:
   - Random Forest model for stress detection
   - Smoothed predictions

6. **AggregatorService**:
   - Combines all three data sources
   - Synchronizes 30-second intervals

7. **FuzzyLogicService**:
   - Adaptive fuzzy inference
   - Final fatigue scoring
   - Alert generation

### Data Flow

```
Serial Port → SerialReader → [Events] → Processors
                                            ↓
                                    HRV → ML Model → Prediction
                                    ENV → Processing → Context
                                    Camera → MediaPipe → Behavior
                                            ↓
                                      Aggregator
                                            ↓
                                     Fuzzy Logic
                                            ↓
                                    Final Output → WebSocket
```

### Running the System

#### 1. Start FastAPI Server (Main Application)
```bash
python main.py
```

#### 2. Start Camera Service (Separate Process)
```bash
python camera_service.py
```

### API Endpoints

- `GET /`: Health check
- `GET /api/v1/status`: System status
- `GET /api/v1/history`: Fatigue score history
- `WebSocket /ws`: Real-time data stream

### WebSocket Output Format

```json
{
  "timestamp": "2026-01-18T10:30:00",
  "fatigue_score": 0.65,
  "alert": {
    "level": "WARNING",
    "action": "Take break within 10 minutes",
    "color": "orange",
    "alert_type": "visual_audible"
  },
  "trend": "increasing",
  "weights": {
    "X_environmental": 0.25,
    "Y_physiological": 0.45,
    "Z_behavioral": 0.30
  },
  "components": {
    "environmental": {...},
    "physiological": {...},
    "behavioral": {...}
  }
}
```

## Advantages Over Previous Design

### 1. **Loose Coupling**
   - Event-driven architecture
   - Services don't directly depend on each other
   - Easy to add/remove/modify components

### 2. **Resource Optimization**
   - Async/await for non-blocking I/O
   - Efficient queue management
   - Camera runs in separate process

### 3. **Scalability**
   - FastAPI supports high concurrency
   - Easy to scale with multiple workers
   - WebSocket for real-time updates

### 4. **Maintainability**
   - Clear separation of concerns
   - Single responsibility per service
   - Type safety with Pydantic

### 5. **Testability**
   - Services can be tested independently
   - Event bus makes mocking easy
   - Clear interfaces

### 6. **Configuration Management**
   - Centralized settings
   - Environment variables
   - Easy deployment

## Key Improvements

1. **Thread Safety**: Used asyncio instead of threading where possible
2. **Type Safety**: Pydantic models for all data structures
3. **Error Handling**: Proper exception handling at all levels
4. **Logging**: Structured logging throughout
5. **API First**: RESTful API + WebSocket
6. **Separation**: Camera runs independently from main app

## Testing

```bash
# Install dependencies
pip install -r requirements.txt

# Run tests (create tests/ directory)
pytest tests/

# Start system
python main.py

# In another terminal
python camera_service.py
```

## Deployment

```bash
# Production deployment
uvicorn api.app:app --host 0.0.0.0 --port 8000 --workers 4

# With systemd (camera service)
systemctl start camera-service
```
"""

# ==========================================
# EXAMPLE: Client Integration
# ==========================================

"""
# JavaScript WebSocket Client Example

const ws = new WebSocket('ws://localhost:8765/ws');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);

  console.log('Fatigue Score:', data.fatigue_score);
  console.log('Alert Level:', data.alert.level);

  // Update UI
  updateDashboard(data);

  if (data.alert.level === 'CRITICAL') {
    triggerEmergencyAlert();
  }
};

function updateDashboard(data) {
  document.getElementById('fatigue-score').textContent = 
    (data.fatigue_score * 100).toFixed(1) + '%';

  document.getElementById('alert-level').textContent = 
    data.alert.level;

  document.getElementById('alert-level').style.color = 
    data.alert.color;
}
"""