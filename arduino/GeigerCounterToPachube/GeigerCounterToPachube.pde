// Requirements:
// EthernetDHCP
// http://gkaindl.com/software/arduino-ethernet
// 
// Reference:
// * http://www.sparkfun.com/products/9848

#include <SPI.h>
#include <Ethernet.h>
#include <EthernetDHCP.h>
#include <NewSoftSerial.h>

// TESTING PURPOSE ONLY
#define TEST

// Pachubeの環境ID
const int environmentId = 20337;

// 自分のAPIキー
const char *apiKey = "zJ1qvUtakkVH6aEIZft805NP2C5RrRhYTP98tC8S6i8";

// REPLACE WITH A PROPER MAC ADDRESS
byte macAddress[] = { 
//  0x01, 0x23, 0x45, 0x67, 0x90, 0xAB };
  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };

// The IP address of api.pachube.com
byte serverIpAddress[] = { 
  173, 203, 98, 29 };

// The client
Client client(serverIpAddress, 80);

NewSoftSerial softSerial(2, 3);

String inString = "";

String csvData = "";

#ifdef TEST
// フィードの間隔(この場合は10,000ms)
const unsigned int samplingInterval = 9999;

// 次にフィードを更新する時刻
unsigned long nextExecuteMillis = 0;
#endif

void setup() {
  // シリアルモニタで動作確認するためのシリアル通信を動作開始
  Serial.begin(9600);

  // The serial port to communicate with your Gaiger counter
  softSerial.begin(9600);

  // DHCPでIPアドレスを取得
  Serial.println("Getting an IP address...");
  EthernetDHCP.begin(macAddress);

  // 確認用に取得したIPアドレスをシリアルにプリント
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

  // 接続を試みる
  Serial.println("Connecting to Pachube...");
  if (client.connect()) {
    // 接続に成功したらシリアルにレポート
    Serial.println("Connected");
  }
  else {
    // 接続に失敗したらシリアルにレポートして以降の動作を停止
    Serial.println("Connection failed");
    while(true);
  }
}

void loop() {
  // DHCPによるIPアドレスのリースを維持
  EthernetDHCP.maintain();

  // サーバから受け取ったデータをPCにもエコー
  if (client.available()) {
    char c = client.read();
    Serial.print(c);
  }

  while (softSerial.available()) {
    char inChar = softSerial.read();
    Serial.print(inChar);

    if (isDigit(inChar)) {
      // convert the incoming byte to a char 
      // and add it to the string:
      inString += (char)inChar; 
    }

    if (inChar == 13) {
      processReceivedMessage(inString);
      inString = "";
    }
  }

#ifdef TEST
  // フィードを更新すべき時刻になっているかどうか判断
  unsigned long currentMillis = millis();
  if (currentMillis > nextExecuteMillis) {
    // 更新すべき時刻であれば次回更新する時刻をセット
    nextExecuteMillis = currentMillis + samplingInterval;

    // データストリームを更新
    Serial.println();
    Serial.println("Updating...");

    inString = random(0, 10);
    processReceivedMessage(inString);
  }
#endif
}

void updateDataStream(String& outData) {
  int contentLength = outData.length();

  client.print("PUT /v2/feeds/");
  client.print(environmentId);
  client.println(" HTTP/1.1");
  client.println("User-Agent: Arduino");
  client.println("Host: api.pachube.com");
  client.print("X-PachubeApiKey: ");
  client.println(apiKey);
  client.print("Content-Length: ");
  client.println(contentLength);
  client.println("Content-Type: text/csv");
  client.println();
  client.println(outData);
}

void processReceivedMessage(String& message) {
  if (message.length() < 0) {
    return;
  }

  int countsPerMinute = message.toInt();
  float microsievertPerHour = (float)countsPerMinute * 0.002333;

  // Since "+" operator doesn't support float values,
  // convert a float value to a fixed point value
  int integerPortion = (int)microsievertPerHour;
  int fractionalPortion = (microsievertPerHour - integerPortion + 0.0005) * 1000;

  csvData = "";
  csvData += "0,";
  csvData += countsPerMinute;
  csvData += "\n";
  csvData += "1,";
  csvData += integerPortion;
  csvData += ".";

  if (fractionalPortion < 10) {
    // e.g. 9 > "00" + "9" = "009"
    csvData += "00";
  } 
  else if (fractionalPortion < 100) {
    // e.g. 99 > "0" + "99" = "099"
    csvData += "0";
  }

  csvData += fractionalPortion;

  updateDataStream(csvData);
}

