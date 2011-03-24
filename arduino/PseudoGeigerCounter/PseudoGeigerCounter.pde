// Pseudo Geiger Counter
// 
// Reference:
// * http://www.sparkfun.com/products/9848
// * https://github.com/a1ronzo/SparkFun-Geiger-Counter/blob/master/GeigerCounter/main.c

const int ledPin = 13;

void setup() {
  pinMode(ledPin, OUTPUT);
  Serial.begin(9600);
}

void loop() {
  digitalWrite(ledPin, HIGH);
  Serial.print("counts per second: ");
  Serial.print(random(10), DEC);
  Serial.print("  \r");
  digitalWrite(ledPin, LOW);

  delay(1000);
}

