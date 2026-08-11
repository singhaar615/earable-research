const int MIC_PIN = A0;           //out signal from MIC
const int SAMPLE_TIME = 10;       //time window to calculate sound intensity (ms)

unsigned long millisCurrent;      //current time stamp
unsigned long millisLast = 0;     //last time stamp since previous value printed
unsigned long millisElapsed = 0;  //time since last print

int baseline = 0;                 // "silence"
int sampleBufferValue = 0;        //max deviation in sample window

const int NOISE_FLOOR = 60;       //approx. noise to subtract later

void setup() {
  Serial.begin(115200);           //start serial communication

  long sum = 0;                   //temp variable summing readings

  //200 samples of silence for baseline
  for (int i = 0; i < 200; i++) {
    sum += analogRead(MIC_PIN);   //sum mic values
    delay(5);                     //delay so measure 1 second of silence
  }
  baseline = sum / 200;           //avg value --> baseline
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
    int output = sampleBufferValue - NOISE_FLOOR;  //subtract noise
    if (output < 0) output = 0;

    //force fixed y-axis on serial plotting
    Serial.print(0);              //min y axis value (plotted constant)
    Serial.print(" ");      
    Serial.print(300);            //max y axis value (plotted constant)
    Serial.print(" ");
    Serial.println(output);       //mic signal

    sampleBufferValue = 0;        //reset
    millisLast = millisCurrent;   //update last timestamp
  }
}