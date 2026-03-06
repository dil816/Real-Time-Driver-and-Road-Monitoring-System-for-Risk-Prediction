import logging
import queue
import threading
import time
from collections import deque
from datetime import datetime

import cv2
import mediapipe as mp
import numpy as np
import tensorflow as tf

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class BehaviouralDetectorSync:
    def __init__(self, model_path, buffer_size=500, behavioural_interval=30):
        self.model_path = model_path
        self.buffer_size = buffer_size
        self.CLASS_NAMES = ["Drowsy", "Not Drowsy"]
        self.face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")
        self.stop_event = threading.Event()
        self.buffer_lock = threading.Lock()
        self.behavioral_interval = behavioural_interval
        self.bhv_feature_queue = deque(maxlen=buffer_size)
        self.drowsiness_feature_queue = deque(maxlen=30)
        self.behavioral_queue = queue.LifoQueue(maxsize=10)
        self.drowsiness_queue = queue.LifoQueue(maxsize=10)
        self.yawning = False
        self.total_yawns = 0
        self.yawn_counter = 0
        self.YAWN_CONSEC_FRAMES = 3
        self.YAWN_MAR_THRESHOLD = 0.65
        self.MOUTH_VERTICAL_INDICES = [(13, 14), (78, 308), (81, 311)]
        self.landmarker = None
        self.interpreter = None
        self.input_details = None
        self.output_details = None
        self._init_mediapipe()

    def _init_mediapipe(self):
        if self.landmarker is not None:
            try:
                self.landmarker.close()
            except Exception as e:
                logger.warning(f"Closing existing landmarker: {e}")

        self.interpreter = tf.lite.Interpreter(model_path="drowsiness_model.tflite")
        self.interpreter.allocate_tensors()
        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()
        logger.info(f"TFLite loaded")

        base_options = mp.tasks.BaseOptions
        face_landmarker = mp.tasks.vision.FaceLandmarker
        face_landmarker_options = mp.tasks.vision.FaceLandmarkerOptions
        vision_running_mode = mp.tasks.vision.RunningMode
        self.options = face_landmarker_options(
            base_options=base_options(model_asset_path=self.model_path),
            running_mode=vision_running_mode.VIDEO,
            output_face_blendshapes=True,
            output_facial_transformation_matrixes=True,
            num_faces=1
        )
        self.landmarker = face_landmarker.create_from_options(self.options)
        logger.info(f"mediapipe loaded")

    def calculate_mouth_aspect_ratio(self, face_landmarks, img_w, img_h):
        if not face_landmarks or len(face_landmarks) < 312:
            return 0
        try:
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
        except (IndexError, AttributeError) as e:
            logger.error(f"Error calculating MAR: {e}")
            return 0

    @staticmethod
    def calculate_head_pose(face_landmarks, img_w, img_h):
        try:
            face_3d = []
            face_2d = []
            target_indices = [1, 33, 61, 199, 263, 291]
            nose_2d = None
            for idx in target_indices:
                if idx >= len(face_landmarks):
                    logger.warning(f"Landmark index {idx} out of range")
                    return 0, 0, 0, None
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
            if not success:
                logger.warning("solvePnP failed")
                return 0, 0, 0, nose_2d
            rmat, _ = cv2.Rodrigues(rot_vec)
            angles, _, _, _, _, _ = cv2.RQDecomp3x3(rmat)
            x_angle = angles[0] * 360
            y_angle = angles[1] * 360
            z_angle = angles[2] * 360
            return x_angle, y_angle, z_angle, nose_2d
        except Exception as e:
            logger.error(f"Error calculating head pose: {e}")
            return 0, 0, 0, None

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

    def drowsiness_frame_preprocess(self, frame_bgr: np.ndarray):
        gray = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2GRAY)
        faces = self.face_cascade.detectMultiScale(gray, scaleFactor=1.2, minNeighbors=6, minSize=(100, 100))
        if len(faces) == 0:
            return None
        x, y, w, h = faces[0]
        face_bgr = frame_bgr[y:y + h, x:x + w]
        face_rgb = cv2.cvtColor(face_bgr, cv2.COLOR_BGR2RGB)
        face_resized = cv2.resize(face_rgb, (224, 224), interpolation=cv2.INTER_LINEAR)
        img = face_resized.astype("float32") / 255.0
        img = np.expand_dims(img, axis=0)
        return img

    def drowsiness_aggregation_loop(self):
        aggregated_predicts = []
        start_time = time.time()
        while not self.stop_event.is_set():
            try:
                if not self.drowsiness_feature_queue:
                    time.sleep(0.05)
                    continue
                image_frame = self.drowsiness_feature_queue.pop()
                self.interpreter.set_tensor(self.input_details[0]["index"], image_frame)
                self.interpreter.invoke()
                predicts = self.interpreter.get_tensor(self.output_details[0]["index"])
                aggregated_predicts.append(predicts)
                if time.time() - start_time >= 4:
                    if len(aggregated_predicts) > 0:
                        agg_preds_np = np.vstack(aggregated_predicts)
                        if agg_preds_np.shape[1] == 1:
                            avg_conf = float(np.mean(agg_preds_np))
                            is_drowsy = avg_conf > 0.5
                            label = self.CLASS_NAMES[0] if is_drowsy else self.CLASS_NAMES[1]
                            confidence = avg_conf * 100 if is_drowsy else (1 - avg_conf) * 100
                        else:
                            avg_preds = np.mean(agg_preds_np, axis=0)
                            idx = int(np.argmax(avg_preds))
                            label = self.CLASS_NAMES[idx]
                            confidence = float(avg_preds[idx]) * 100
                            is_drowsy = idx == 0
                        feature = {
                            "label": label,
                            "confidence": confidence,
                        }
                        if self.drowsiness_queue.full():
                            try:
                                self.drowsiness_queue.get_nowait()
                            except queue.Empty:
                                pass
                        self.drowsiness_queue.put_nowait(feature)
                        logger.info(f"[4s Aggregated] Label: {label}, Confidence: {confidence:.2f}%")
                    else:
                        logger.warning("[4s Aggregated] No predictions collected in this window.")
                    aggregated_predicts = []
                    start_time = time.time()
            except IndexError:
                time.sleep(0.05)
            except Exception as e:
                logger.error(f"Error in aggregation loop: {e}", exc_info=True)
                time.sleep(0.1)

    # def drowsiness_aggregation_loop1(self):
    #     while not self.stop_event.is_set():
    #         try:
    #             img = self.drowsiness_feature_queue.pop()
    #             self.interpreter.set_tensor(self.input_details[0]["index"], img)
    #             self.interpreter.invoke()
    #             preds = self.interpreter.get_tensor(self.output_details[0]["index"])
    #
    #             if preds.shape[1] == 1:
    #                 conf = float(preds[0][0])
    #                 is_drowsy = conf > 0.5
    #                 label = self.CLASS_NAMES[0] if is_drowsy else self.CLASS_NAMES[1]
    #                 confidence = conf * 100 if is_drowsy else (1 - conf) * 100
    #                 # print(f"lable: {label} confidence: {confidence}")
    #             else:
    #                 idx = int(np.argmax(preds))
    #                 label = self.CLASS_NAMES[idx]
    #                 confidence = float(preds[0][idx]) * 100
    #                 is_drowsy = idx == 0
    #                 print(f"lable: {label} confidence: {confidence}")
    #         except Exception as e:
    #             logger.error(f"Error agg loop: {e}")
    #             time.sleep(0.1)

    def aggregation_loop(self):
        last_run_time = time.time()
        while not self.stop_event.is_set():
            try:
                current_time = time.time()
                if current_time - last_run_time >= self.behavioral_interval:
                    with self.buffer_lock:
                        buffer_copy = list(self.bhv_feature_queue)
                    if len(buffer_copy) > 0:
                        features = {
                            'x_mean': float(np.mean([d['x_angle'] for d in buffer_copy])),
                            'y_mean': float(np.mean([d['y_angle'] for d in buffer_copy])),
                            'z_mean': float(np.mean([d['z_angle'] for d in buffer_copy])),
                            'mar_mean': float(np.mean([d['mar'] for d in buffer_copy])),
                            'yawn_count': int(np.max([d['yawn_count'] for d in buffer_copy])),
                            'yawn_frequency': float(np.sum([d['yawning'] for d in buffer_copy]) / len(buffer_copy)),
                            'total_frames': len(buffer_copy)
                        }
                        logger.info(f"{datetime.now()} aggregated: {features}")
                        if self.behavioral_queue.full():
                            try:
                                self.behavioral_queue.get_nowait()
                            except queue.Empty:
                                pass
                        self.behavioral_queue.put_nowait(features)
                        last_run_time = current_time
                time.sleep(0.1)
            except Exception as e:
                logger.error(f"Error aggregation loop: {e}")
                time.sleep(0.1)

    def process_frame(self, frame, timestamp_ms):
        try:
            img_h, img_w, _ = frame.shape
            preprocessed = self.drowsiness_frame_preprocess(frame)
            if preprocessed is None:
                return
            img = preprocessed
            self.drowsiness_feature_queue.append(img)
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
            results = self.landmarker.detect_for_video(mp_image, timestamp_ms)
            if results.face_landmarks:
                for face_landmarks in results.face_landmarks:
                    x_angle, y_angle, z_angle, nose_2d = self.calculate_head_pose(
                        face_landmarks, img_w, img_h
                    )
                    mar = self.calculate_mouth_aspect_ratio(face_landmarks, img_w, img_h)
                    is_yawning = self.process_yawn_detection(mar)
                    data_point = {
                        "timestamp": timestamp_ms,
                        "x_angle": float(x_angle),
                        "y_angle": float(y_angle),
                        "z_angle": float(z_angle),
                        "yawning": bool(is_yawning),
                        "yawn_count": int(self.total_yawns),
                        "mar": float(mar)
                    }
                    with self.buffer_lock:
                        self.bhv_feature_queue.append(data_point)
        except Exception as e:
            logger.error(f"Error process frame: {e}")

    def camera_loop(self, camera_index=0):
        cap = cv2.VideoCapture(camera_index)
        try:
            while cap.isOpened() and not self.stop_event.is_set():
                success, frame = cap.read()
                if not success:
                    break
                frame = cv2.flip(frame, 1)
                timestamp_ms = int(time.time() * 1000)
                self.process_frame(frame, timestamp_ms)
        except Exception as e:
            logger.error(f"Error camera loop: {e}")
        finally:
            cap.release()
