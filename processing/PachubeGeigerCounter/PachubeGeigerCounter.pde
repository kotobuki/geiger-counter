// Requirement:
// EEML for Processing
// http://eeml.org/library/
// 
// References:
// * http://www.sparkfun.com/products/9848
// * https://github.com/a1ronzo/SparkFun-Geiger-Counter/blob/master/GeigerCounter/main.c

import processing.serial.*;
import eeml.*;

// キャリッジリターンのキャラクターコード
final int CR = 13;

// シリアルポート
Serial serialPort;

// Pachubeに対してデータを出力する際に使用するオブジェクト
DataOut dataOut;

// The feed URL
final String feedUrl = "http://api.pachube.com/v2/feeds/20337.xml";

// The API key (Permissons: put, Expires: 03/31/11 11:59PM)
final String apiKey = "zJ1qvUtakkVH6aEIZft805NP2C5RrRhYTP98tC8S6i8";

// The data stream ID for your geiger counter
final int dataStreamId = 0;

int count = 0;

int response = 0;

void setup() {
  size(400, 200);

  // テキスト表示に使用するフォントを生成してロード
  PFont font = createFont("CourierNewPSMT", 18);
  textFont(font);

  // シリアルポートのリストを表示する
  println(Serial.list());

  // Mac OS Xでは0番目のポートがArduinoになる場合が多いが
  // Windowsでは最後のポートがArduinoである場合が多い
  // 必要に応じてポート番号をデフォルトの0から変更する
  serialPort = new Serial(this, Serial.list()[0], 9600);

  // シリアルポートからすでに受信しているデータがあればクリア
  serialPort.clear();

  // CRを受け取った時にserialEventが呼ばれるようにセット
  serialPort.bufferUntil(CR);

  // DataOutオブジェクトをセットアップ
  // 更新するEEMLのURLとAPI Keyが必要
  dataOut = new DataOut(this, feedUrl, apiKey);

  // データストリームにタグを追加
  dataOut.addData(dataStreamId, "geiger counter");
}

void draw() {
  background(0);
  text("Count: " + count + " count/min", 10, 20);
  text("Response: " + response, 10, 40);
}

// Serial.bufferUntil()でセットした文字を受け取ると呼ばれる
void serialEvent(Serial port) {
  // シリアルポートから受信済みのメッセージを読み出す
  String message = port.readString();

  // メッセージが空であれば以下の処理を行わずにリターン
  if (message == null) {
    return;
  }

  // 期待される文字列で始まっていなければ以下の処理を行わずにリターン
  if (!message.startsWith("counts per second: ")) {
    return;
  }

  String countString = message.substring(20, message.length());
  if (countString == null || countString.length() < 4) {
    return;
  }

  try {
    count = Integer.parseInt(countString.trim());

    // データストリームを更新
    dataOut.update(dataStreamId, count);

    // updatePachube()で認証されたPUT HTTPリクエストにより更新
    // 成功したら200、認証に失敗したら401、フィードが存在しない場合は404
    response = dataOut.updatePachube();
  } 
  catch (Exception e) {
    println(e);
  }
}

