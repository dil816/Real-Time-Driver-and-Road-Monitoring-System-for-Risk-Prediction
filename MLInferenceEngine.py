from datetime import datetime

import joblib
import asyncio
import logging
import numpy as np
import pandas as pd
from collections import deque
from typing import Optional, List

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class MLInferenceEngine:
    def __init__(self):
        self.predictions = deque(maxlen=1000)
        self.hrv_prediction_history = deque(maxlen=5)
        self.stress_labels = {0: 'Relaxed', 1: 'Normal', 2: 'Stressed'}
        self.model = None
        self.lock = asyncio.Lock()
        self.inference_failures = 0

    def load_model(self, model_path: Optional[str] = None):
        self.model = joblib.load('random_forest_model.pkl')
        logger.info("ML model loaded (placeholder)")

    async def predict(self, df: pd.DataFrame) :
        if self.model is None:
            logger.warning("Model not loaded")
            return None
        try:
            feature_cols = [col for col in df.columns if col != 'timestamp']
            X = df[feature_cols]
            prediction = self.model.predict(X)
            probabilities = self.model.predict_proba(X)
            pred = int(np.argmax(np.bincount(prediction)))
            prob = np.mean(probabilities, axis=0)
            self.hrv_prediction_history.append(pred)
            if len(self.hrv_prediction_history) >= 3:
                smoothed = int(np.median(list(self.hrv_prediction_history)))
            else:
                smoothed = pred
            data = {
                'status': 'success',
                'prediction': int(pred),
                'prediction_smooth': int(smoothed),
                'label': self.stress_labels[pred],
                'label_smooth': self.stress_labels[smoothed],
                'confidence': float(max(prob)),
                'probabilities': {
                    'relaxed': float(prob[0]),
                    'normal': float(prob[1]),
                    'stressed': float(prob[2])
                },
                'timestamp': datetime.now()
            }

            # async with self.lock:
            #     for i, pred in enumerate(prediction):
            #         self.predictions.append({
            #             'timestamp': df.iloc[i]['timestamp'],
            #             'prediction': pred
            #         })
            # logger.info(f"Generated {len(predictions)} predictions successfully")
            # logger.info(f"{predictions}")
            # return predictions
            return data
        except Exception as e:
            self.inference_failures += 1
            logger.error(f"Inference failed (count: {self.inference_failures}): {e}")
            return None

    async def get_recent_predictions(self, n: int = 10) -> List[dict]:
        async with self.lock:
            return list(self.predictions)[-n:]
