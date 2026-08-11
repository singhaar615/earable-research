const int MIC_PIN = A0;           //out signal from MIC
const int SAMPLE_TIME = 10;       //time window to calculate sound intensity (ms)

unsigned long millisCurrent;      //current time stamp
unsigned long millisLast = 0;     //last time stamp since previous value printed
unsigned long millisElapsed = 0;  //time since last print

int baseline = 0;                 // "silence"
int sampleBufferValue = 0;        //max deviation in sample window

const int NOISE_FLOOR = 60;       //approx. noise to subtract later

const unsigned long WARMUP_DURATION = 5000;   // 5 seconds silent
const unsigned long RECORD_DURATION = 20000;  // 20 seconds recording

unsigned long phaseStart = 0;
enum State { WARMUP, RECORDING, DONE };
State state = WARMUP;

void setup() {
  Serial.begin(115200);           //start serial communication

  long sum = 0;                   //temp variable summing readings

  //200 samples of silence for baseline
  for (int i = 0; i < 200; i++) {
    sum += analogRead(MIC_PIN);   //sum mic values
    delay(5);                     //delay so measure 1 second of silence
  }
  
  baseline = sum / 200;           //avg value --> baseline
  phaseStart = millis();

}

void loop() {
  millisCurrent = millis();       //get current time
  millisElapsed = millisCurrent - millisLast;  //calculate time elapsed from last --> current

  int sample = analogRead(MIC_PIN);   //get current mic signal

  //baseline adjusts over time
  //99% of old + 1% of new --> subtly move towards sample
  baseline = (baseline * 99 + sample) / 100;

  int deviation = abs(sample - baseline); //distance between baseline and sound intensity

  //assign max value immediately
  if (deviation > sampleBufferValue) {
    sampleBufferValue = deviation;
  }

  //only runs if hit 10 ms mark
  if (millisElapsed >= SAMPLE_TIME) {
  unsigned long elapsed = millis() - phaseStart;

  if (state == WARMUP && elapsed >= WARMUP_DURATION) {
    state = RECORDING;
    phaseStart = millis();  // reset timer for recording phase
  }

  if (state == RECORDING) {
    if (millis() - phaseStart >= RECORD_DURATION) {
      state = DONE;
    } else {
      int output = sampleBufferValue - NOISE_FLOOR;
      if (output < 0) output = 0;

      Serial.print(0);
      Serial.print(" ");
      Serial.print(300);
      Serial.print(" ");
      Serial.println(output);
    }
  }

  sampleBufferValue = 0;
  millisLast = millisCurrent;
}
}