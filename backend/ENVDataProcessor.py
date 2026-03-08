import logging
import time
from datetime import datetime

import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ENVDataProcessor:
    def __init__(self, weather_api_key):
        self.motorway_mapping = {"motorway": "Highway", "trunk": "A1 / Main Highway", "primary": "Main Road",
                                 "secondary": "Normal Road", "tertiary": "Local Road", "residential": "Street",
                                 "path": "Path", "service": "Service Road"
                                 }
        self.weather_api_key = weather_api_key
        self.last_weather_update = 0
        self.weather_cache = {}

    def get_weather(self, lat, lon):
        current_time = time.time()

        if current_time - self.last_weather_update < 900:
            return self.weather_cache

        try:
            url = f"http://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={self.weather_api_key}"
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
            print(f"Weather API Error: {e}")
            return self.weather_cache

    @staticmethod
    def classify_light_level(lux):
        if lux < 1:
            light_condition = 'dark'
        elif lux < 10:
            light_condition = 'very_dim'
        elif lux < 50:
            light_condition = 'dim'
        elif lux < 200:
            light_condition = 'indoor'
        elif lux < 1000:
            light_condition = 'overcast'
        else:
            light_condition = 'bright'

        return {'lux': lux, 'light_condition': light_condition}

    @staticmethod
    def get_time_risk_factor():
        current_hour = datetime.now().hour

        # High risk: 2-6 AM (circadian low)
        if 2 <= current_hour < 6:
            return 'very_high'
        # Moderate-high: 12-2 PM (post-lunch dip)
        elif 12 <= current_hour < 14:
            return 'moderate_high'
        # Moderate: 6-8 AM, 10 PM-2 AM
        elif (6 <= current_hour < 8) or (22 <= current_hour or current_hour < 2):
            return 'moderate'
        # Low risk: 8 AM-12 PM, 2-10 PM
        else:
            return 'low'

    @staticmethod
    def calculate_heat_index(temp_c, humidity):
        temp_f = (temp_c * 9 / 5) + 32

        if temp_f < 80:
            return temp_c

        hi = -42.379 + 2.04901523 * temp_f + 10.14333127 * humidity
        hi -= 0.22475541 * temp_f * humidity - 0.00683783 * temp_f * temp_f
        hi -= 0.05481717 * humidity * humidity + 0.00122874 * temp_f * temp_f * humidity
        hi += 0.00085282 * temp_f * humidity * humidity - 0.00000199 * temp_f * temp_f * humidity * humidity

        heat_index_c = (hi - 32) * 5 / 9
        return heat_index_c

    @staticmethod
    def determine_driving_context(lat, lon, speed, radius=10):
        headers = {
            'User-Agent': 'RoadDetailsApp/1.0'
        }

        try:
            response = requests.get(f"https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lon}&format=json",
                                    headers=headers)
            response.raise_for_status()
            data = response.json()
            road_info = {
                'road_name': data.get('name', 'N/A'),
                'road_type': data.get('type', 'N/A'),
                'drive_speed': speed,
            }

            return road_info
        except requests.exceptions.RequestException as e:
            print(f"Error drive context ENV")
            return {
                'road_name': 'N/A',
                'road_type': 'N/A',
                'drive_speed': speed,
            }

    def determine_driving_context1(self, lat, lon, speed, radius=10):
        try:
            query = f"""
                [out:json];
                way(around:{radius},{lat},{lon})["highway"];
                out tags;
                """
            response = requests.post("https://overpass.kumi.systems/api/interpreter", data=query)
            if response.status_code != 200:
                print(response)
                return {}
            data = response.json()
            if len(data["elements"]) == 0:
                return {}
            road = data["elements"][0]["tags"]
            return {
                "road_name": road.get("name", "Unknown Road"),
                "road_type": self.motorway_mapping.get(road.get("highway", "Unknown Type"), "Unknown"),
                "road_maxspeed": road.get("maxspeed", "Unknown maxspeed"),
            }

        except requests.exceptions.RequestException as e:
            print(f"Error fetching data: {e}")
            return None

    def process_environmental_data(self, serialdata):
        if serialdata is None:
            return None

        data = {
            "time_risk": self.get_time_risk_factor(),
            "light_level": self.classify_light_level(
                serialdata['environment'].get('lux')
            ),
        }
        if serialdata.get('gps'):
            data['weather'] = self.get_weather(
                serialdata['gps'].get('lat'),
                serialdata['gps'].get('lng')
            )
            data['driving_context'] = self.determine_driving_context(
                serialdata['gps'].get('lat'),
                serialdata['gps'].get('lng'),
                serialdata['gps'].get('speed_kmh')
            )
        return data
