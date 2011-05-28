// Connection:
// * An Arduino Ethernet Shield
// * D3: The output pin of the Geiger counter (active low or high)
//
// Requirements:
// EthernetDHCP
// http://gkaindl.com/software/arduino-ethernet
//
// Reference:
// * http://www.sparkfun.com/products/9848
// 
// Created by @kotobuki
// Modified by @freaklabs

#include <SPI.h>
#include <Ethernet.h>
#include <EthernetDHCP.h>
#include <limits.h>

#include "PrivateSettings.h"

// The IP address of api.pachube.com
byte serverIpAddress[] = {
  173, 203, 98, 29 };

// The TCP client
Client client(serverIpAddress, 80);

String csvData = "";

// Sampling interval (e.g. 60,000ms = 1min)
unsigned long updateIntervalInMillis = 0;

// The next time to feed
unsigned long nextExecuteMillis = 0;

// Value to store counts per minute
int count = 0;

// Event flag signals when a geiger event has occurred
volatile unsigned char eventFlag = 0; 

// The last connection time to disconnect from the server
// after uploaded feeds
long lastConnectionTime = 0;

// The conversion coefficient from cpm to µSv/h
float conversionCoefficient = 0;

// NetRAD - this is specific to the NetRAD board
const int speakerPin = 6;  // pin number of piezo speaker
const int ledPin = 7;      // pin number of event LED

void setup() {
  Serial.begin(57600);

  // Set the conversion coefficient from cpm to µSv/h
  switch (tubeModel) {
  case LND_712:
    // Reference:
    // http://www.lndinc.com/products/348/
    //
    // 1,000CPS ≒ 0.14mGy/h
    // 60,000CPM ≒ 140µGy/h
    // 1CPM ≒ 0.002333µGy/h
    conversionCoefficient = 0.002333;
    Serial.println("Tube model: LND 712");
    break;
  case SBM_20:
    // Reference:
    // http://www.libelium.com/wireless_sensor_networks_to_control_radiation_levels_geiger_counters
    conversionCoefficient = 0.0057;
    Serial.println("Tube model: SBM-20");
    break;
  case J408GAMMA:
    // Reference:
    // http://garden.seeedstudio.com/index.php?title=Geiger_Counter
    //
    // 300CPS = 0.0084µGy/s
    // 18,000CPM = 30.24µGy/h
    // 1CPM = 0.00168µGy/h
    conversionCoefficient = 0.00168;
    Serial.println("Tube model: J408gamma");
    break;
  case J306BETA:
    // Reference:
    // http://garden.seeedstudio.com/index.php?title=Geiger_Counter
    //
    // 300CPS = 0.0084µGy/s
    // 18,000CPM = 30.24µGy/h
    // 1CPM = 0.00168µGy/h
    conversionCoefficient = 0.00168;
    Serial.println("Tube model: J306beta");
    break;
  default:
    Serial.println("Tube model: UNKNOWN!");
  }

  // Initiate a DHCP session
  Serial.println("Getting an IP address...");
  EthernetDHCP.begin(macAddress);

  // We now have a DHCP lease, so we print out some information
  const byte* ipAddr = EthernetDHCP.ipAddress();
  Serial.print("IP address: ");
  Serial.print(ipAddr[0], DEC);
  Serial.print(".");
  Serial.print(ipAddr[1], DEC);
  Serial.print(".");
  Serial.print(ipAddr[2], DEC);
  Serial.print(".");
  Serial.print(ipAddr[3], DEC);
  Serial.println();

  // Attach an interrupt to the digital pin and start counting
  //
  // Note:
  // Most Arduino boards have two external interrupts:
  // numbers 0 (on digital pin 2) and 1 (on digital pin 3)
  attachInterrupt(1, onPulse, interruptMode);
  updateIntervalInMillis = updateIntervalInMinutes * 60000;

  unsigned long now = millis();
  nextExecuteMillis = now + updateIntervalInMillis;
}

void loop() {
  // Periodically call this method to maintain your DHCP lease
  EthernetDHCP.maintain();

  // Echo received strings to a host PC
  if (client.available()) {
    char c = client.read();
    Serial.print(c);
  }

  if (client.connected() && (elapsedTime(lastConnectionTime) > 30000)) {
    Serial.println();
    Serial.println("Disconnecting.");
    client.stop();
  }

  // Add any geiger event handling code here
  if (eventFlag) {
    eventFlag = 0;    // clear the event flag for later use

    Serial.println(count, DEC); // dump the current count
    tone(speakerPin, 1000);      // beep the piezo speaker

    digitalWrite(ledPin, HIGH); // flash the LED
    delay(20);                  
    digitalWrite(ledPin, LOW);

    noTone(speakerPin);          // turn off the speaker pulse
  }

  // check if its time to update server. elapsedTime function will take into account
  // counter rollover.
  if (elapsedTime(lastConnectionTime) < updateIntervalInMillis) {
    return;
  }

  Serial.println();
  Serial.println("Updating...");

  float countsPerMinute = (float)count / (float)updateIntervalInMinutes;
  count = 0;

  updateDataStream(countsPerMinute);
}

// On each falling edge of the Geiger counter's output,
// increment the counter and signal an event. The event 
// can be used to do things like pulse a buzzer or flash an LED
void onPulse() {
  count++;
  eventFlag = 1;  
}

// Since "+" operator doesn't support float values,
// convert a float value to a fixed point value
void appendFloatValueAsString(String& outString,float value) {
  int integerPortion = (int)value;
  int fractionalPortion = (value - integerPortion + 0.0005) * 1000;

  outString += integerPortion;
  outString += ".";

  if (fractionalPortion < 10) {
    // e.g. 9 > "00" + "9" = "009"
    outString += "00";
  }
  else if (fractionalPortion < 100) {
    // e.g. 99 > "0" + "99" = "099"
    outString += "0";
  }

  outString += fractionalPortion;
}

void updateDataStream(float countsPerMinute) {
  if (client.connected()) {
    Serial.println();
    Serial.println("Disconnecting.");
    client.stop();
  }

  // Try to connect to the server
  Serial.println();
  Serial.print("Connecting to Pachube...");
  if (client.connect()) {
    Serial.println("Connected");
    lastConnectionTime = millis();
  }
  else {
    Serial.println("failed");
    return;
  }

  // Convert from cpm to µSv/h with the pre-defined coefficient
  float microsievertPerHour = countsPerMinute * conversionCoefficient;

  csvData = "";
  csvData += "CPM,";
  appendFloatValueAsString(csvData, countsPerMinute);
  csvData += "\n";
  csvData += "µSv-h,";
  appendFloatValueAsString(csvData, microsievertPerHour);

  Serial.println(csvData);

  client.print("PUT /v2/feeds/");
  client.print(environmentId);
  client.println(" HTTP/1.1");
  client.println("User-Agent: Arduino");
  client.println("Host: api.pachube.com");
  client.print("X-PachubeApiKey: ");
  client.println(apiKey);
  client.print("Content-Length: ");
  client.println(csvData.length());
  client.println("Content-Type: text/csv");
  client.println();
  client.println(csvData);
}

// Calculate elapsed time. this takes into account rollover.
unsigned long elapsedTime(unsigned long startTime) {
  unsigned long stopTime = millis();

  if (startTime >= stopTime) {
    return startTime - stopTime;
  }
  else {
    return (ULONG_MAX - (startTime - stopTime));
  }
}

