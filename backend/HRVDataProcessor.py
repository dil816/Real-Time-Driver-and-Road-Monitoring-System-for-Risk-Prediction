import logging
import numpy as np
from typing import Optional
from scipy.stats import kurtosis, skew

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class HRVDataProcessor:
    @staticmethod
    def remove_outliers(rr: np.ndarray, threshold: float = 0.25) -> np.ndarray:
        """Remove outliers from RR intervals (critical for PPG)"""
        # print(rr)
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

    @staticmethod
    def extract_features(ibi_values: np.ndarray, remove_outliers: bool = True) -> Optional[dict]:
        """
        Extract 19 HRV features from IBI data

        Args:
            ibi_values: Inter-beat intervals in milliseconds (5-minute window)
            remove_outliers: Whether to filter outliers

        Returns:
            Dictionary with 19 HRV features
        """
        if len(ibi_values) < 10:
            logger.warning(f"Insufficient IBI data: {len(ibi_values)} beats")
            return None

        rr = np.array(ibi_values, dtype=float)

        # Filter valid range
        rr = rr[(rr >= 300) & (rr <= 2000)]
        if len(rr) < 10:
            logger.warning("No valid IBIs after filtering")
            return None

        # Remove outliers (important for PPG)
        if remove_outliers:
            rr_original_len = len(rr)
            rr = HRVDataProcessor.remove_outliers(rr)
            if len(rr) < 10:
                logger.warning("Insufficient data after outlier removal")
                return None
            if len(rr) < rr_original_len:
                logger.debug(f"Removed {rr_original_len - len(rr)} outliers")

        # Basic statistics
        mean_rr = np.mean(rr)
        median_rr = np.median(rr)
        mean_hr = 60000 / mean_rr

        # Time-domain features
        diff_rr = np.diff(rr)
        sdnn = np.std(rr, ddof=1)
        rmssd = np.sqrt(np.mean(diff_rr ** 2))
        sdsd = np.std(diff_rr, ddof=1)
        sdrr_rmssd = sdnn / rmssd if rmssd != 0 else np.nan
        pnn25 = np.sum(np.abs(diff_rr) > 25) / len(diff_rr) * 100 if len(diff_rr) > 0 else 0
        pnn50 = np.sum(np.abs(diff_rr) > 50) / len(diff_rr) * 100 if len(diff_rr) > 0 else 0

        # Poincaré features
        sd1 = np.sqrt(0.5 * (sdsd ** 2))
        sd2 = np.sqrt(np.maximum(0, 2 * (sdnn ** 2) - 0.5 * (sdsd ** 2)))

        # Statistical features
        kurt = kurtosis(rr, fisher=True) if len(rr) > 2 else np.nan
        skewness = skew(rr) if len(rr) > 2 else np.nan

        # Relative features (normalized by mean_rr)
        sdrr_rel = sdnn / mean_rr if mean_rr != 0 else np.nan
        rmssd_rel = rmssd / mean_rr if mean_rr != 0 else np.nan
        sdsd_rel = sdsd / mean_rr if mean_rr != 0 else np.nan
        sdrr_rmssd_rel = sdrr_rmssd / mean_rr if mean_rr != 0 and not np.isnan(sdrr_rmssd) else np.nan
        kurt_rel = kurt / mean_rr if mean_rr != 0 and not np.isnan(kurt) else np.nan
        skew_rel = skewness / mean_rr if mean_rr != 0 and not np.isnan(skewness) else np.nan

        # Create feature dictionary
        features = {
            'MEAN_RR': mean_rr,
            'MEDIAN_RR': median_rr,
            'SDRR': sdnn,
            'RMSSD': rmssd,
            'SDSD': sdsd,
            'SDRR_RMSSD': sdrr_rmssd,
            'HR': mean_hr,
            'pNN25': pnn25,
            'pNN50': pnn50,
            'SD1': sd1,
            'SD2': sd2,
            'KURT': kurt,
            'SKEW': skewness,
            'SDRR_REL_RR': sdrr_rel,
            'RMSSD_REL_RR': rmssd_rel,
            'SDSD_REL_RR': sdsd_rel,
            'SDRR_RMSSD_REL_RR': sdrr_rmssd_rel,
            'KURT_REL_RR': kurt_rel,
            'SKEW_REL_RR': skew_rel,
        }

        return features
