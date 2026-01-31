import asyncio
import logging
import time
from collections import deque
from datetime import datetime
from typing import Optional, Dict, List
import cv2
import mediapipe as mp
import numpy as np

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class BehaviouralDetectorAsync:
    def __init__(self, model_path, buffer_size=500, behavioural_interval=30):
        self.running = False
        self.model_path = model_path
        self.buffer_size = buffer_size
        self.behavioral_interval = behavioural_interval
        self.source = 0
        self.cap = None
        self.fps = 30
        self.yawn_counter = 0
        self.total_yawns = 0
        self.yawning = False
        self.YAWN_MAR_THRESHOLD = 0.65
        self.YAWN_CONSEC_FRAMES = 3
        self.MOUTH_VERTICAL_INDICES = [(13, 14), (78, 308), (81, 311)]
        self.bhv_feature_queue = deque(maxlen=buffer_size)
        self.buffer_lock = asyncio.Lock()
        self.predictions = deque(maxlen=1000)
        self.predictions_lock = asyncio.Lock()
        self.frame_queue = asyncio.Queue(maxsize=100)
        self.frames_processed = 0
        self.inference_failures = 0
        self.landmarker = None
        self._init_mediapipe()

    def _init_mediapipe(self):
        BaseOptions = mp.tasks.BaseOptions
        FaceLandmarker = mp.tasks.vision.FaceLandmarker
        FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
        VisionRunningMode = mp.tasks.vision.RunningMode
        self.options = FaceLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=self.model_path),
            running_mode=VisionRunningMode.VIDEO,
            output_face_blendshapes=True,
            output_facial_transformation_matrixes=True,
            num_faces=1
        )
        self.FaceLandmarker = FaceLandmarker
        self.landmarker = FaceLandmarker.create_from_options(self.options)
        logger.info("MediaPipe Face Landmarker initialized")

    async def connect(self) -> bool:
        try:
            self.cap = cv2.VideoCapture(self.source)
            if not self.cap.isOpened():
                logger.error(f"Failed to open video source: {self.source}")
                return False
            logger.info(f"Video capture initialized: {self.source}")
            return True
        except Exception as e:
            logger.error(f"Error initializing video capture: {e}")
            return False

    def calculate_mouth_aspect_ratio(self, face_landmarks, img_w, img_h):
        if not face_landmarks or len(face_landmarks) < 312:
            return 0
        total_vertical_dist = 0
        for top_idx, bottom_idx in self.MOUTH_VERTICAL_INDICES:
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
        mar = (total_vertical_dist / len(self.MOUTH_VERTICAL_INDICES)) / horizontal_dist
        return mar

    @staticmethod
    def calculate_head_pose(face_landmarks, img_w, img_h):
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

    @staticmethod
    def get_direction_text(x_angle, y_angle):
        if y_angle < -10:
            return "Looking Left"
        elif y_angle > 10:
            return "Looking Right"
        elif x_angle < -10:
            return "Looking Down"
        elif x_angle > 10:
            return "Looking Up"
        else:
            return "Forward"

    def process_yawn_detection(self, mar):
        if mar > self.YAWN_MAR_THRESHOLD:
            self.yawn_counter += 1
            if self.yawn_counter >= self.YAWN_CONSEC_FRAMES:
                if not self.yawning:
                    self.total_yawns += 1
                    self.yawning = True
        else:
            self.yawn_counter = 0
            self.yawning = False
        return self.yawning

    async def process_frame(self, frame: np.ndarray, timestamp_ms: int) -> Optional[Dict]:
        try:
            img_h, img_w, _ = frame.shape
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
            results = self.landmarker.detect_for_video(mp_image, timestamp_ms)
            if results.face_landmarks:
                for face_landmarks in results.face_landmarks:
                    x_angle, y_angle, z_angle, nose_2d = self.calculate_head_pose(
                        face_landmarks, img_w, img_h
                    )
                    direction_text = self.get_direction_text(x_angle, y_angle)
                    mar = self.calculate_mouth_aspect_ratio(face_landmarks, img_w, img_h)
                    is_yawning = self.process_yawn_detection(mar)
                    data_point = {
                        "timestamp": timestamp_ms,
                        "x_angle": float(x_angle),
                        "y_angle": float(y_angle),
                        "z_angle": float(z_angle),
                        "yawning": bool(is_yawning),
                        "yawn_count": int(self.total_yawns),
                        "mar": float(mar),
                        "direction": direction_text
                    }
                    async with self.buffer_lock:
                        self.bhv_feature_queue.append(data_point)
                    self.frames_processed += 1
                    return data_point
            return None
        except Exception as e:
            self.inference_failures += 1
            logger.error(f"Error processing frame: {e}")
            return None

    async def queue_frame(self):
        self.running = True
        frame_interval = 1.0 / self.fps
        while self.running:
            try:
                start_time = time.time()
                loop = asyncio.get_event_loop()
                ret, frame = await loop.run_in_executor(None, self.cap.read)
                if not ret:
                    logger.warning("Failed to read frame")
                    await asyncio.sleep(0.1)
                    continue
                frame = cv2.flip(frame, 1)
                timestamp_ms = int(time.time() * 1000)
                await asyncio.wait_for(
                    self.frame_queue.put((frame, timestamp_ms)),
                    timeout=0.05
                )
                elapsed = time.time() - start_time
                sleep_time = max(0, frame_interval - elapsed)
                await asyncio.sleep(sleep_time)
            except asyncio.CancelledError:
                logger.info("Video read loop cancelled")
                break
            except asyncio.TimeoutError:
                logger.warning("Behavioral detector queue full, dropping frame")
            except Exception as e:
                logger.error(f"Error in video read loop: {e}")
                await asyncio.sleep(0.1)

    async def processing_loop(self):
        self.running = True
        logger.info("Behavioral detector processing loop started")
        while self.running:
            try:
                frame, timestamp_ms = await asyncio.wait_for(
                    self.frame_queue.get(),
                    timeout=1.0
                )
                result = await self.process_frame(frame, timestamp_ms)
                if result:
                    async with self.predictions_lock:
                        self.predictions.append(result)
            except asyncio.TimeoutError:
                continue
            except asyncio.CancelledError:
                logger.info("Behavioral detector processing loop cancelled")
                break
            except Exception as e:
                logger.error(f"Error in behavioral processing loop: {e}")

    async def aggregation_loop(self):
        self.running = True
        last_run_time = time.time()
        logger.info("Behavioral detector aggregation loop started")
        while self.running:
            try:
                current_time = time.time()
                if current_time - last_run_time >= self.behavioral_interval:
                    async with self.buffer_lock:
                        buffer_copy = list(self.bhv_feature_queue)
                    if len(buffer_copy) > 0:
                        features = {
                            'x_mean': float(np.mean([d['x_angle'] for d in buffer_copy])),
                            'y_mean': float(np.mean([d['y_angle'] for d in buffer_copy])),
                            'z_mean': float(np.mean([d['z_angle'] for d in buffer_copy])),
                            'mar_mean': float(np.mean([d['mar'] for d in buffer_copy])),
                            'yawn_count': int(np.max([d['yawn_count'] for d in buffer_copy])),
                            'yawn_frequency': float(np.sum([d['yawning'] for d in buffer_copy]) / len(buffer_copy)),
                            'total_frames': len(buffer_copy),
                            'timestamp': datetime.now().isoformat()
                        }
                        logger.info(f"Behavioral features aggregated: {features}")
                        async with self.predictions_lock:
                            self.predictions.append({
                                'type': 'aggregated',
                                'features': features
                            })
                    last_run_time = current_time
                await asyncio.sleep(1)
            except asyncio.CancelledError:
                logger.info("Behavioral detector aggregation loop cancelled")
                break
            except Exception as e:
                logger.error(f"Error in behavioral aggregation loop: {e}")

    async def get_recent_predictions(self, n: int = 10) -> List[dict]:
        """Get recent predictions."""
        async with self.predictions_lock:
            return list(self.predictions)[-n:]

    async def get_recent_aggregated(self, n: int = 5) -> List[dict]:
        """Get recent aggregated features only."""
        async with self.predictions_lock:
            aggregated = [p for p in self.predictions if p.get('type') == 'aggregated']
            return aggregated[-n:]

    async def get_stats(self) -> dict:
        """Get processing statistics."""
        async with self.buffer_lock:
            buffer_size = len(self.bhv_feature_queue)

        return {
            'frames_processed': self.frames_processed,
            'inference_failures': self.inference_failures,
            'queue_size': self.frame_queue.qsize(),
            'buffer_size': buffer_size,
            'buffer_capacity': self.buffer_size,
            'total_yawns': self.total_yawns,
            'current_yawning': self.yawning
        }

    def cleanup(self):
        self.running = False
        if self.landmarker:
            self.landmarker.close()
        logger.info("Behavioral detector cleaned up")
        if self.cap:
            self.cap.release()
            cv2.destroyAllWindows()
            logger.info("Video capture released")
