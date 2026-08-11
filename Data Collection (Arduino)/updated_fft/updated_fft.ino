const int MIC_PIN = A0;

//sampling settings
const unsigned long SAMPLE_PERIOD = 200;         // 200 us = 5 kHz
const unsigned long RECORD_TIME = 150000000UL;   // 150 seconds

//baseline settings
int baseline = 0;
const int NOISE_FLOOR = 5;

unsigned long startTime;
unsigned long lastSample;
unsigned long lastBaselineUpdate;

void setup()
{
    Serial.begin(1000000);

    //allow microphone to stabilize
    delay(3000);

    //baseline calibration
    long sum = 0;

    for (int i = 0; i < 500; i++)
    {
        sum += analogRead(MIC_PIN);
        delay(2);
    }


    baseline = sum / 500;

    //wait for key press to start recording
    while (Serial.available() == 0)
    {
        //wait
    }

    while (Serial.available())
    {
        Serial.read();
    }

    startTime = micros();
    lastSample = startTime;
    lastBaselineUpdate = millis();
}

void loop()
{
    unsigned long now = micros();

    //stop after record time
    if (now - startTime >= RECORD_TIME)
    {
        while (1);
    }

    //sample at 5 kHz
    if (now - lastSample >= SAMPLE_PERIOD)
    {
        lastSample += SAMPLE_PERIOD;

        //raw sample
        int rawSample = analogRead(MIC_PIN);

        //update baseline slowly every 5 ms
        if (millis() - lastBaselineUpdate >= 5)
        {
            baseline =
                (baseline * 99 + rawSample) / 100;

            lastBaselineUpdate = millis();
        }

        //compute deviation from baseline
        int processed =
            abs(rawSample - baseline) - NOISE_FLOOR;

        if (processed < 0)
        {
            processed = 0;
        }

        //output:
        //raw,processed
        Serial.print(rawSample);
        Serial.print(",");
        Serial.println(processed);
    }
}