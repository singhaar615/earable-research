const int MIC_PIN = A0;
const int THRESHOLD = 40;   // increase if too sensitive

int baseline = 0;

void setup() {
  Serial.begin(115200);

  // Calibrate baseline during silence
  long sum = 0;
  for (int i = 0; i < 200; i++) {
    sum += analogRead(MIC_PIN);
    delay(5);
  }
  baseline = sum / 200;

  Serial.print("Baseline: ");
  Serial.println(baseline);
}

void loop() {
  int sample = analogRead(MIC_PIN);
  int deviation = abs(sample - baseline);

  if (deviation > THRESHOLD) {
    Serial.println(0);   // noise detected
  } else {
    Serial.println(1);   // silent
  }

  delay(10);
}