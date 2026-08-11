const int MIC_PIN = A0;
const int SAMPLE_TIME = 10;

unsigned long millisCurrent;
unsigned long millisLast = 0;
unsigned long millisElapsed = 0;

int baseline = 0;
int sampleBufferValue = 0;

const int NOISE_FLOOR = 60;   //adjust this (start ~60–70)

void setup() {
  Serial.begin(115200);

  long sum = 0;
  for (int i = 0; i < 200; i++) {
    sum += analogRead(MIC_PIN);
    delay(5);
  }
  baseline = sum / 200;
}

void loop() {
  millisCurrent = millis();
  millisElapsed = millisCurrent - millisLast;

  int sample = analogRead(MIC_PIN);

  // keep adaptive baseline
  baseline = (baseline * 99 + sample) / 100;

  int deviation = abs(sample - baseline);

  if (deviation > sampleBufferValue) {
    sampleBufferValue = deviation;
  }

  if (millisElapsed >= SAMPLE_TIME) {

    //subtract noise floor
    int output = sampleBufferValue - NOISE_FLOOR;
    if (output < 0) output = 0;

    Serial.print(0);        // min line
    Serial.print(" ");
    Serial.print(300);      // max line
    Serial.print(" ");
    Serial.println(output); // your signal

    sampleBufferValue = 0;
    millisLast = millisCurrent;
  }
}