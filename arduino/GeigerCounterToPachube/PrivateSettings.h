// NOTE
// Before uploading to your Arduino board,
// please replace with your own settings

// The environment ID for your datastreams
const int environmentId = ********;

// Your API key (a public secure key is recommended)
const char *apiKey = "*******************************************";

// REPLACE WITH A PROPER MAC ADDRESS
byte macAddress[] = { 
  0x**, 0x**, 0x**, 0x**, 0x**, 0x** };

// Update interval in minutes
const int updateIntervalInMinutes = 5;

enum TubeModel {
  LND_712,  // LND
  SMB_20,   // GSTube
  J408GAMMA, // North Optic
  J306BETA  // North Optic
};

// Tube model
const TubeModel tubeModel = ********;

// Interrupt mode:
// * For most geiger counter modules: FALLING
// * Geiger Counter Twig by Seeed Studio: RISING
const int interruptMode = ********;

