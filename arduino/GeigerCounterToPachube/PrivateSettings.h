// NOTE
// Before uploading to your Arduino board,
// please replace with your own settings

// The environment ID for your datastreams
const int environmentId = 12345;

// Your API key (a public secure key is recommended)
const char *apiKey = "*******************************************";

// REPLACE WITH A PROPER MAC ADDRESS
byte macAddress[] = { 
  0x01, 0x23, 0x45, 0x67, 0x89, 0xAB };

// Update interval in minutes
const int updateIntervalInMinutes = 5;

// The conversion coefficient from cpm to µSv/h for LND 712
// 
// Reference:
// http://www.lndinc.com/products/348/
// 
// 1,000CPS ≒ 0.14mGy/h
// 60,000CPM ≒ 140µGy/h
// 1CPM ≒ 0.002333µGy/h
const float conversionCoefficient = 0.002333;
