# 🚗 Real-Time Driver and Road Monitoring System for Risk Prediction

**An intelligent multi-sensor IoT and ML-based system designed to predict driving risks in real-time through driver condition monitoring, road environment analysis, and personalized behavioral tracking.**

---

## 📌 Project Information

**Project Code:** 25-26J-291  
**Degree Program:** BSc (Hons) in Information Technology  
**Institution:** Sri Lanka Institute of Information Technology (SLIIT)

**Project Repository Link:** [GitHub Repository](#)

---

## 👥 Group Members

| Student ID | Name             | Component                                                | Branch                                   |
| ---------- | ---------------- | -------------------------------------------------------- | ---------------------------------------- |
| IT22211514 | D.L.R Dilochana  | Fatigue Detection System for Long-Term Driver Monitoring | IT22211514-Dilochana-Fatigue-Detection   |
| IT22255860 | Pinsara T.H.A.K  | Multi-Sensor Driver Drowsiness Detection                 | IT22255860-Pinsara-Drowsiness-Detection  |
| IT22257468 | Samoda T.W.O     | Road Sign & Weather Condition Monitoring                 | IT22257468-Samoda-Road-Monitoring        |
| IT22134226 | Senadheera S.C.C | Personalized Driver Behavioral Deviation Detection       | IT22134226-Senadheera-Behavior-Detection |

---

## 🎓 Supervisors

- **Primary Supervisor:** [Supervisor Name]
- **Co-Supervisor:** [Co-Supervisor Name]

---

## 🧠 Project Overview

### Research Problem

**How can real-time monitoring of driver condition, road environment, and personalized driving behavior be integrated to predict risks and reduce accidents?**

The Real-Time Driver and Road Monitoring System addresses critical gaps in current road safety technologies by integrating multiple data streams—physiological signals, behavioral patterns, environmental conditions, and road information—to proactively predict and prevent accidents.

### Key Objectives

1. ✅ **Fatigue Detection** - Long-term driver monitoring using HRV analysis and behavioral indicators
2. ✅ **Drowsiness Detection** - Multi-sensor physiological and environmental monitoring
3. ✅ **Road Monitoring** - Real-time traffic sign detection and weather condition alerts
4. ✅ **Behavioral Analysis** - Personalized driving pattern deviation detection

### Why This Matters

- Driver fatigue and drowsiness are leading causes of road accidents globally
- Existing systems focus on single modalities and lack comprehensive risk assessment
- Generic detection systems generate false positives and miss personalized risk factors
- Environmental conditions significantly impact driving safety but are rarely integrated

Our solution provides a **holistic, adaptive, and intelligent approach** to road safety through multi-component collaboration.

---

## 🏗 System Architecture
<img width="4531" height="3415" alt="Untitled diagram-2026-01-11-155819" src="https://github.com/user-attachments/assets/777d71d2-c406-4203-b6a8-f868b4a969f0" />

The system follows a **modular distributed architecture**:

- **Sensor Layer:** Captures physiological, behavioral, and environmental data
- **Processing Layer:** ML models process data streams in real-time
- **Decision Layer:** Fuzzy logic and weighted fusion for risk assessment
- **Alert Layer:** Multi-modal warnings based on risk severity

---

## 🛠 Technology Stack

### Hardware Components

| Component          | Model       | Purpose                               |
| ------------------ | ----------- | ------------------------------------- |
| Microcontroller    | ESP32       | Main processing and communication hub |
| Camera Module      | ESP32-CAM   | Road sign and environment capture     |
| SpO₂ Sensor        | MAX30102    | Blood oxygen level monitoring         |
| Temperature Sensor | AHT20       | Cabin temperature monitoring          |
| Smartphone         | Android/iOS | GPS, processing, and user interface   |

### Software & Frameworks

#### Machine Learning

- **TensorFlow** - Deep learning framework
- **YOLOv8** - Real-time object detection
- **Scikit-learn** - Random Forest classifier
- **MobileNetV2** - Lightweight CNN for mobile deployment

#### Computer Vision

- **MediaPipe** - Face mesh and pose estimation
- **OpenCV** - Image processing and face detection

#### Mobile Development

- **Flutter** - Cross-platform mobile application
- **Dart** - Primary programming language

#### Backend & APIs

- **Python** - ML model training and inference
- **FastAPI** - RESTful API services
- **Google Weather API** - Weather condition data
- **Custom Traffic Sign API** - Cloud-based sign detection

#### Communication Protocols

- **Bluetooth Low Energy (BLE)** - ESP32 to smartphone
- **I2C** - Sensor communication
- **HTTP/HTTPS** - API communication

#### Development Tools

- **Git & GitHub** - Version control
- **Arduino IDE** - ESP32 firmware development
- **Jupyter Notebook** - Model training and analysis

---

## 📂 Project Structure

```
driver-road-monitoring-system/
│
├── fatigue-detection/               # IT22211514 - Fatigue Detection
│   ├── models/                      # Random Forest model files
│   ├── hrv_extraction/              # HRV feature extraction
│   ├── mediapipe_detection/         # Head pose and yawning detection
│   ├── fuzzy_fusion/                # Multi-stream data fusion
│   └── README.md
│
├── drowsiness-detection/            # IT22255860 - Drowsiness Detection
│   ├── cnn_model/                   # MobileNetV2 training and inference
│   ├── sensor_integration/          # MAX30102 and AHT20 integration
│   ├── esp32_firmware/              # ESP32 sensor code
│   ├── decision_fusion/             # Hybrid decision making
│   └── README.md
│
├── road-monitoring/                 # IT22257468 - Road & Weather Monitoring
│   ├── yolov8_model/                # Traffic sign detection model
│   ├── esp32_cam/                   # ESP32-CAM firmware
│   ├── flutter_app/                 # Mobile application
│   │   ├── lib/
│   │   ├── assets/
│   │   └── pubspec.yaml
│   ├── api_service/                 # Cloud API deployment
│   └── README.md
│
├── behavioral-detection/            # IT22134226 - Behavioral Deviation
│   ├── steering_analysis/           # Steering pattern monitoring
│   ├── anomaly_models/              # Statistical and ML anomaly detection
│   ├── personalization/             # Driver-specific baseline profiling
│   └── README.md
│
├── integration/                     # System integration
│   ├── risk_fusion/                 # Combined risk assessment
│   ├── alert_system/                # Multi-modal alert generation
│   └── dashboard/                   # Unified monitoring dashboard
│
├── datasets/                        # Training and test datasets
│   ├── SWELL/                       # HRV fatigue dataset
│   ├── traffic_signs/               # Traffic sign images
│   └── drowsiness_images/           # Drowsy/non-drowsy faces
│
│
└── README.md                        # This file
```

---

## ⚙️ Installation and Setup

### Prerequisites

```bash
# Python 3.8 or higher
python --version

# Node.js and npm (for any web interfaces)
node --version
npm --version

# Flutter SDK
flutter --version

# Arduino IDE with ESP32 support
```

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/driver-road-monitoring-system.git
cd driver-road-monitoring-system
```

### 2. Install Python Dependencies

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 3. Install Flutter Dependencies

```bash
cd road-monitoring/flutter_app
flutter pub get
```

### 4. Configure ESP32 Firmware

```bash
# Open Arduino IDE
# Install ESP32 board support
# Install required libraries:
#   - MAX30102
#   - AHT20
#   - BLE
# Upload firmware to ESP32 devices
```

### 5. Environment Configuration

Create `.env` files in respective component directories:

```env
# API Configuration
WEATHER_API_KEY=your_weather_api_key
TRAFFIC_SIGN_API_URL=your_api_url

# Database (if applicable)
MONGODB_URI=your_mongodb_connection_string

# Model Paths
FATIGUE_MODEL_PATH=./models/random_forest_fatigue.pkl
DROWSINESS_MODEL_PATH=./models/mobilenet_drowsiness.h5
YOLO_MODEL_PATH=./models/yolov8_traffic_signs.pt
```

### 6. Run the System

#### Fatigue Detection Module

```bash
cd fatigue-detection
python main.py
```

#### Drowsiness Detection Module

```bash
cd drowsiness-detection
python drowsiness_monitor.py
```

#### Road Monitoring Mobile App

```bash
cd road-monitoring/flutter_app
flutter run
```

#### Behavioral Detection Module

```bash
cd behavioral-detection
python behavior_monitor.py
```

---

## 📊 Component Details

### 1️⃣ Fatigue Detection System (IT22211514)

**Researcher:** D.L.R Dilochana

**Objective:** Long-term driver fatigue monitoring using physiological and behavioral indicators

**Key Features:**

- ❤️ Heart Rate Variability (HRV) analysis with 19 features
- 😴 Yawning detection using MediaPipe face mesh
- 🎯 Head pose estimation for attention monitoring
- 🌡️ Environmental factor integration (light, weather, GPS)
- 🧮 Fuzzy logic for multi-stream data fusion

**Performance:**

- **Accuracy:** 89% validation accuracy
- **Model:** Random Forest Classifier
- **Dataset:** SWELL (Stress, Workload, Emotion, Learning)
- **Classes:** 3-class (Relaxed, Time Pressure, Stressed)
- **Deployment:** CPU-only (no GPU required)

**Technologies:**

- Scikit-learn, MediaPipe, OpenCV
- Python, NumPy, Pandas

---

### 2️⃣ Drowsiness Detection System (IT22255860)

**Researcher:** Pinsara T.H.A.K

**Objective:** Multi-sensor drowsiness detection combining visual and physiological data

**Key Features:**

- 👁️ CNN-based facial drowsiness classification
- 🩸 Real-time SpO₂ monitoring (WHO-approved thresholds)
- 🌡️ Cabin temperature assessment
- ⚖️ Hybrid decision fusion (CNN + sensors)
- 📊 Weighted risk scoring system

**Performance:**

- **Model:** MobileNetV2 with ImageNet transfer learning
- **Output:** Binary classification (Drowsy/Not Drowsy)
- **Sensors:** MAX30102 (SpO₂), AHT20 (Temperature)
- **Sampling:** 100-sample buffer for SpO₂ accuracy

**Technologies:**

- TensorFlow, OpenCV, ESP32
- I2C Communication, BLE

---

### 3️⃣ Road & Weather Monitoring (IT22257468)

**Researcher:** Samoda T.W.O

**Objective:** Real-time road sign detection and weather-aware speed monitoring

**Key Features:**

- 🚦 Traffic sign detection (37 classes)
- 📍 GPS-based real-time speed tracking
- ⚠️ Overspeed warnings based on detected limits
- 🌦️ Live weather condition monitoring
- 📱 Mobile dashboard with visual alerts

**Performance:**

- **Accuracy:** 88.4% validation accuracy
- **Model:** YOLOv8 Nano (lightweight, fast)
- **Hardware:** ESP32-CAM
- **Latency:** Real-time processing with minimal delay

**Technologies:**

- YOLOv8, Flutter, BLE
- Google Weather API, Geolocator
- Haptic Feedback, Wakelock

---

### 4️⃣ Behavioral Deviation Detection (IT22134226)

**Researcher:** Senadheera S.C.C

**Objective:** Personalized driving behavior analysis for early risk detection

**Key Features:**

- 🎯 Real-time steering behavior monitoring
- 👤 Driver-specific baseline profiling
- 🔍 Hybrid anomaly detection (statistical + ML)
- 🔄 Adaptive threshold replacement
- 🔒 Privacy-preserving design (no identity storage)

**Performance:**

- **Approach:** Statistical baselines + ML anomaly models
- **Focus:** Steering patterns as primary indicator
- **Adaptation:** Long-term behavior drift support

**Technologies:**

- Python, Scikit-learn
- Statistical process control
- Isolation Forest, Local Outlier Factor

---

## 🧪 Testing

### Testing Methodology

#### Unit Testing

- Individual component testing for each detection module
- Sensor accuracy validation against ground truth
- ML model performance evaluation on validation sets

#### Integration Testing

- Multi-component data flow verification
- API endpoint correctness and error handling
- BLE communication stability testing

#### User Acceptance Testing

- Feedback from 2-3 test users per component
- Real-world driving scenario simulations
- Alert timing and accuracy assessment

### Test Results

| Component              | Test Type            | Result      |
| ---------------------- | -------------------- | ----------- |
| Fatigue Detection      | Model Accuracy       | 89% ✅      |
| Drowsiness Detection   | Real-time Processing | Pass ✅     |
| Traffic Sign Detection | Model Accuracy       | 88.4% ✅    |
| Behavioral Detection   | User Feedback        | Positive ✅ |
| BLE Communication      | Latency Test         | <100ms ✅   |
| Alert System           | Response Time        | <500ms ✅   |

### User Feedback Summary

**Positive Points:**

- Useful for basic safety alerts
- Real-time monitoring feels responsive
- Multi-modal alerts are effective

**Improvement Areas:**

- Users want alerts tuned to personal driving style _(addressed in behavioral component)_
- Request for offline sign detection _(planned enhancement)_
- Battery optimization for mobile app _(under development)_

---

## 🚧 Limitations

### Current Constraints

1. **Hardware Dependencies**

   - Requires specific sensor modules (MAX30102, AHT20)
   - ESP32-CAM needed for road monitoring
   - Smartphone with BLE and GPS required

2. **Processing Limitations**

   - Traffic sign detection requires cloud API (offline mode not yet implemented)
   - Real-time processing constrained by device capabilities

3. **Data Constraints**

   - Personalized baselines require initial calibration period
   - Limited training data for some edge cases
   - Weather API dependent on internet connectivity

4. **Environmental Factors**

   - Poor lighting affects camera-based detection
   - Extreme weather may impact sensor accuracy
   - GPS signal loss in tunnels or dense urban areas

5. **Accessibility**
   - Some features limited to specific smartphone models
   - Requires technical setup knowledge for initial deployment

---

## 🚀 Future Enhancements

### Planned Improvements

#### Short-term (6 months)

- ✨ **Offline Sign Detection** - On-device YOLOv8 deployment
- 🔋 **Battery Optimization** - Efficient sensor polling and processing
- 📱 **iOS Support** - Expand mobile app to iOS platform
- 🎨 **UI/UX Enhancement** - Improved dashboard and alert visualization

#### Medium-term (1 year)

- 🤖 **Advanced AI Integration** - Deep learning for behavior prediction
- 🚗 **CAN Bus Integration** - Direct vehicle telemetry access
- ☁️ **Cloud Analytics** - Long-term driver behavior insights
- 🌐 **Multi-language Support** - Interface localization

#### Long-term (2+ years)

- 🧠 **Federated Learning** - Privacy-preserving model improvement
- 🔗 **V2V Communication** - Vehicle-to-vehicle risk sharing
- 🏭 **Fleet Management** - Commercial vehicle monitoring system
- 📊 **Big Data Analytics** - Population-level safety insights

### Research Extensions

- Integration with autonomous driving assistance systems
- Predictive maintenance based on driving patterns
- Insurance risk scoring and dynamic premium calculation
- Smart city integration for traffic management

---

## 📜 License

This project is developed for **academic purposes** under the BSc (Hons) in Information Technology program at Sri Lanka Institute of Information Technology (SLIIT).

**Academic Use Only** - Not intended for commercial distribution without proper authorization.

---

## 🙏 Acknowledgements

We express our sincere gratitude to:

- **Project Supervisors** - For invaluable guidance, feedback, and support throughout the research
- **Sri Lanka Institute of Information Technology (SLIIT)** - For providing resources and facilities
- **SWELL Dataset Contributors** - For providing high-quality HRV training data
- **Open Source Community** - TensorFlow, YOLOv8, MediaPipe, Flutter, and all libraries used
- **Test Users** - For participating in prototype testing and providing constructive feedback
- **Family & Friends** - For continuous support and encouragement

---

## 📞 Contact & Support

For questions, suggestions, or collaboration opportunities:

- **Project Lead:** D.L.R Dilochana (IT22211514)
- **Email:** [project-email@example.com]
- **GitHub Issues:** [Report bugs or request features](https://github.com/your-org/driver-road-monitoring-system/issues)

---

## 📚 Publications & Presentations

- Research Paper: [Link to paper]
- Project Presentation: [Link to slides]
- Demo Video: [Link to video]

---

<div align="center">

**⚠️ Safety Notice**

This system is designed for **driver assistance and research purposes only**.  
It should **NOT replace** attentive driving practices, adherence to traffic regulations, or proper vehicle maintenance.  
Always remain alert and in control of your vehicle.

---

Made with ❤️ by Team 25-26J-291  
Sri Lanka Institute of Information Technology

</div>
