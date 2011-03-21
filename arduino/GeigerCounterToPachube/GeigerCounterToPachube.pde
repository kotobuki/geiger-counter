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

// Pachubeの環境ID
const int environmentId = 1234;

// 自分のAPIキー
const char *apiKey = "YOUR_API_KEY";

// MACアドレス（Ethernetシールド底面のシールに記載）
byte macAddress[] = { 
  0x01, 0x23, 0x45, 0x67, 0x90, 0xAB };

// PachubeのIPアドレス
byte serverIpAddress[] = { 
  173, 203, 98, 29 };

// クライアント
Client client(serverIpAddress, 80);

NewSoftSerial softSerial(2, 3);

String inString = "";

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
      processReceivedMessage();
    }
  }
}

// データストリームの更新処理
void updateDataStream(int datastreamId, const char *pachubeData) {
  int contentLength = strlen(pachubeData);

  // サーバにアクセスして指定したデータストリームを更新
  client.print("PUT /api/feeds/");
  client.print(environmentId);
  client.print("/datastreams/");
  client.print(datastreamId);
  client.println(".csv HTTP/1.1");
  client.println("User-Agent: Arduino");
  client.println("Host: www.pachube.com");
  client.print("X-PachubeApiKey: ");
  client.println(apiKey);
  client.print("Content-Length: ");
  client.println(contentLength);
  client.println("Content-Type: text/csv");
  client.println();
  client.println(pachubeData);
}

void processReceivedMessage() {
  // サーバに対して送信するデータを収める配列
  static char pachubeData[10];

  if (inString.length() < 0) {
    return;
  }

  int countsPerMinute = inString.toInt();
  // データを配列pachubeDataにプリント
  sprintf(pachubeData, "%d", countsPerMinute);
  updateDataStream(0, pachubeData);

  float microsievertPerHour = (float)countsPerMinute * 0.002333;
  // データを配列pachubeDataにプリント
  if (microsievertPerHour > 10) {
    sprintf(pachubeData, "%d", round(microsievertPerHour));    
  } 
  else {
    sprintf(pachubeData, "%f", microsievertPerHour);
  }

  updateDataStream(1, pachubeData);

  inString = "";
}

