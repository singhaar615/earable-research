const int MIC_PIN = A0;           //out signal from MIC
const int SAMPLE_TIME = 10;       //time window to calculate sound intensity (ms)
const int OFFSET = 100;

unsigned long millisCurrent;      //current timestamp
unsigned long millisLast = 0;     //last timestamp when value was printed
unsigned long millisElapsed = 0;  //time since last print

int baseline = 0;                 //"silence"

void setup() {
  Serial.begin(115200);           //start serial communication at higher baud
  }        

void loop() {
  millisCurrent = millis();                      //get current time
  millisElapsed = millisCurrent - millisLast;    //time elapsed since last output

  int sample = (analogRead(MIC_PIN)) - OFFSET;   //get current raw mic signal

  if (millisElapsed >= SAMPLE_TIME) {
  Serial.print(0);              //min y axis value (plotted constant)
  Serial.print(" ");      
  Serial.print(300);            //max y axis value (plotted constant)
  Serial.print(" ");
  Serial.println(sample);       //mic signal

  millisLast = millisCurrent;     //update last timestamp
  }
}


