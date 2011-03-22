// A very basic example for uploding radiation information
// to the Pachube server
// 
// Note:
// This example is for SparkFun's SEN-09848 (firmware: v13)
// 
// Requirement:
// EEML for Processing
// http://eeml.org/library/
// 
// References:
// * http://www.sparkfun.com/products/9848
// * https://github.com/a1ronzo/SparkFun-Geiger-Counter/blob/master/GeigerCounter/main.c
// * http://www.sparkfun.com/datasheets/Components/General/LND-712-Geiger-Tube.pdf

import processing.serial.*;
import eeml.*;

// The character code of Carriage Return
final int CR = 13;

// Create object from Serial class
Serial serialPort;

// Create a DataOut object to upload data to the Pachube server
DataOut dataOut;

// The tags for feeds
final String tags = "sensor:type=radiation,sensor:model=lnd-712";

// 1,000CPS ≒ 0.14mGy/h
// 60,000CPM ≒ 140µGy/h
// 1CPM ≒ 0.002333µGy/h
final float coefficientOfConversion = 140.0 / 60000.0;

// Current value in CPM
int countsPerMinute = 0;

// Current value in µSv/h
float microsievertPerHour = 0;

// Current response from the Pachube server
String httpResponse = "";

int count = 0;
int index = 0;

void setup() {
  size(400, 200);

  PFont font = createFont("CourierNewPSMT", 18);
  textFont(font);

  // Print a list of the serial ports (might include Bluetooth ports)
  println(Serial.list());

  // I know that the first port in the serial list on my mac
  // is always my  FTDI adaptor, so I open Serial.list()[0].
  // On Windows machines, this generally opens COM1.
  // Open whatever port is the one you're using.
  // 
  // Example: serialPort = new Serial(this, "COM3", 9600);
  // Mac OS Xでは0番目のポートがArduinoになる場合が多いが
  // Windowsでは最後のポートがArduinoである場合が多い
  // 必要に応じてポート番号をデフォルトの0から変更する
  // 
  // 例：serialPort = new Serial(this, "COM3", 9600);
  // 
  serialPort = new Serial(this, Serial.list()[0], 9600);

  // Clear the receive buffer
  serialPort.clear();

  // Set to serialEvent() will be called for each CR
  serialPort.bufferUntil(CR);

  // Instantiate a DataOut object with a feed URL and an API key
  dataOut = new DataOut(this, feedUrl, apiKey);

  // Add tags to datastreams
  // 0: counts per minute (CPM), min:0, max:1000
  // 1: microsievert per hour (µSv/h), min:0, max:10
  dataOut.addData(0, tags, 0, 1000);
  dataOut.addData(1, tags, 0, 10);
}

void draw() {
  background(0);

  text(countsPerMinute + " CPM (about " + microsievertPerHour + " µSv/h)", 10, 20);

  if (httpResponse != "") {
    text("Response: " + httpResponse, 10, 60);
  }
}

void serialEvent(Serial port) {
  String message = port.readString();

  if (message == null) {
    return;
  }

  if (!message.startsWith("counts per second: ")) {
    return;
  }

  //            111111111
  //  0123456789012345678
  // "counts per second: "
  String countString = message.substring(19);
  if (countString == null || countString.length() < 4) {
    return;
  }

  println(message);

  try {
    int countsPerSecond = Integer.parseInt(countString.trim());
    count += countsPerSecond;
    index++;
    println("index: " + index + ", " + countsPerSecond);

    if (index == 60) {
      // Calculate and upload to the Pachube server every minute
      countsPerMinute = count;
      microsievertPerHour = countsPerMinute * coefficientOfConversion;
      dataOut.update(0, countsPerMinute);
      dataOut.update(1, microsievertPerHour);

      // Update the data streams by a PUT HTTP request,
      // then check results.
      int response = dataOut.updatePachube();
      if (response == 200) {
        httpResponse = "OK";
      }
      else if (response == 401) {
        httpResponse = "Authorization Failed";
      }
      else if (response == 404) {
        httpResponse = "Feed Not Found";
      } 
      else {
        httpResponse = "Other";
      }

      // Reset the count and the index
      count = 0;
      index = 0;
    }
  } 
  catch (Exception e) {
    println(e);
  }
}

