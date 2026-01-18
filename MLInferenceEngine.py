import asyncio
import logging
from collections import deque
from typing import Optional, List

import joblib
import numpy as np
import pandas as pd

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class MLInferenceEngine:

    def __init__(self):
        self.predictions = deque(maxlen=1000)
        self.model = None
        self.lock = asyncio.Lock()
        self.inference_failures = 0

    def load_model(self, model_path: Optional[str] = None):
        self.model = joblib.load('random_forest_model.pkl')
        logger.info("ML model loaded (placeholder)")

    async def predict(self, df: pd.DataFrame) -> Optional[np.ndarray]:
        if self.model is None:
            logger.warning("Model not loaded")
            return None
        try:
            feature_cols = [col for col in df.columns if col != 'timestamp']
            X = df[feature_cols]
            predictions = self.model.predict(X)
            async with self.lock:
                for i, pred in enumerate(predictions):
                    self.predictions.append({
                        'timestamp': df.iloc[i]['timestamp'],
                        'prediction': pred
                    })
            logger.info(f"Generated {len(predictions)} predictions successfully")
            logger.info(f"{predictions}")
            return predictions
        except Exception as e:
            self.inference_failures += 1
            logger.error(f"Inference failed (count: {self.inference_failures}): {e}")
            return None

    async def get_recent_predictions(self, n: int = 10) -> List[dict]:
        async with self.lock:
            return list(self.predictions)[-n:]
