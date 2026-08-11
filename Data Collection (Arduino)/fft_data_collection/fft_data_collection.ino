const int MIC_PIN = A0;

//sampling settings
const unsigned long SAMPLE_PERIOD = 200;      //microseconds = 5 kHz
const unsigned long RECORD_TIME = 150000000UL; //150 seconds (microseconds)

unsigned long startTime;
unsigned long lastSample;

void setup()
{
    Serial.begin(1000000);

    while (Serial.available() == 0)
    {
        //wait
    }

    //wait for pressed key to start recording
    while (Serial.available()) 
        Serial.read();   //clear the input buffer

    startTime = micros();
    lastSample = startTime;
}

void loop()
{
    unsigned long now = micros();

    //stop after 20 seconds
    if (now - startTime >= RECORD_TIME)
    {
        while (1);
    }

    //sample every 500 us
    if (now - lastSample >= SAMPLE_PERIOD)
    {
        lastSample += SAMPLE_PERIOD;

        int sample = analogRead(MIC_PIN);

        Serial.println(sample);
    }
}