


/* Comment this out to disable prints and save space */
#define BLYNK_PRINT Serial

#include <ESP8266WiFi.h>
#include <BlynkSimpleEsp8266.h>
#include <SoftwareSerial.h>
SoftwareSerial mySerial(13,15);   // gpio_13(rx2),gpio_15(tx2)

char auth[] = "";   // lgOn
char ssid[] = "";
char pass[] = "";

char rdBuf;

     
BLYNK_WRITE(V2) {
  char pinValue = param.asInt();
   if (pinValue >= 0) 
    Serial1.print(pinValue);
        
   
}     

void serialEvent(){

   
/*
    while (mySerial.available()) {
   
      rdBuf = (char)mySerial.read();
      Blynk.virtualWrite(V2,rdBuf);
      Serial.print("test" + rdBuf);
      Serial1.print("test" + rdBuf);
      mySerial.print("test" + rdBuf);
    }*/
}
  
      
void setup(){
    Serial.begin(9600);     // TX0,RX0    Debug console
    mySerial.setTimeout(2000);
    mySerial.begin(9600);   // TX2,RX2
    Serial1.begin(9600);    // TX1
    Blynk.begin(auth, ssid, pass);
    }
  
void loop() {
    Blynk.run();

   
}


  
