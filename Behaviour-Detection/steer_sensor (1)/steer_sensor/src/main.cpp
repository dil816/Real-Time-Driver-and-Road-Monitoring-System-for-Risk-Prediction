#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

/* CONFIG */

const char* WIFI_SSID = "CPixel 6 Pro";
const char* WIFI_PASS = "chamindu";

const char* MQTT_BROKER = "10.199.89.127";
const int   MQTT_PORT   = 1883;

const char* DEVICE_ID  = "VEH_001";
const char* MQTT_TOPIC = "vehicle/VEH_001/angle";

/* KY-040 ENCODER CONFIG */

#define PIN_A 18   // CLK
#define PIN_B 19   // DT

const int   STEPS_PER_REV = 360;
const float DEG_PER_STEP = 360.0 / STEPS_PER_REV;

/* OBJECTS */

WiFiClient espClient;
PubSubClient mqttClient(espClient);

/* ENCODER STATE */

volatile int stepCount = 0;
volatile uint8_t lastState = 0;

portMUX_TYPE mux = portMUX_INITIALIZER_UNLOCKED;

/* TIMING */

unsigned long lastPublishTime = 0;
const unsigned long PUBLISH_INTERVAL = 50; // 20 Hz

/* QUADRATURE LOOKUP TABLE
   index = (lastState << 2) | currentState
*/
const int8_t encoderTable[16] = {
   0, -1, +1,  0,
  +1,  0,  0, -1,
  -1,  0,  0, +1,
   0, +1, -1,  0
};

/* ENCODER ISR */

void IRAM_ATTR encoderISR() {
  uint8_t A = digitalRead(PIN_A);
  uint8_t B = digitalRead(PIN_B);
  uint8_t currentState = (A << 1) | B;

  uint8_t index = (lastState << 2) | currentState;

  portENTER_CRITICAL_ISR(&mux);
  stepCount += encoderTable[index];
  lastState = currentState;
  portEXIT_CRITICAL_ISR(&mux);
}

/* WIFI */

void setupWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi connected");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
}

/* MQTT */

void reconnectMQTT() {
  while (!mqttClient.connected()) {
    Serial.print("Connecting to MQTT...");
    if (mqttClient.connect(DEVICE_ID)) {
      Serial.println("connected");
    } else {
      Serial.print("failed, rc=");
      Serial.print(mqttClient.state());
      delay(2000);
    }
  }
}

/* SETUP */

void setup() {
  Serial.begin(115200);

  pinMode(PIN_A, INPUT_PULLUP);
  pinMode(PIN_B, INPUT_PULLUP);

  // Initialize encoder state
  lastState = (digitalRead(PIN_A) << 1) | digitalRead(PIN_B);
  stepCount = 0;  

  attachInterrupt(digitalPinToInterrupt(PIN_A), encoderISR, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_B), encoderISR, CHANGE);

  setupWiFi();
  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);

  Serial.println("System started (KY-040 encoder)");
}

/* LOOP */

void loop() {
  if (!mqttClient.connected()) {
    reconnectMQTT();
  }
  mqttClient.loop();

  unsigned long now = millis();
  if (now - lastPublishTime >= PUBLISH_INTERVAL) {
    lastPublishTime = now;

    int steps;
    portENTER_CRITICAL(&mux);
    steps = stepCount;
    portEXIT_CRITICAL(&mux);

    float angle = round(steps / 2.0) * DEG_PER_STEP;
    angle = constrain(angle, -180.0, 180.0);

    StaticJsonDocument<64> doc;
    doc["angle"] = angle;

    char payload[64];
    serializeJson(doc, payload);

    mqttClient.publish(MQTT_TOPIC, payload);

    Serial.print("Published angle: ");
    Serial.println(angle, 2);
  }
}