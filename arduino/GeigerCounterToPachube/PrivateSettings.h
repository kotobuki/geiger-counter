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

enum TubeModel {
  LND_712,  // LND
  SMB_20,   // GSTube
  J408GAMMA // North Optic
};

const TubeModel tubeModel = LND_712;
