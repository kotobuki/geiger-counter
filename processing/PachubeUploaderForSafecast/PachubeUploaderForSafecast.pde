/**
 * Pachube uploader for Safecast (http://www.safecast.org/)
 * by Shigeru Kobayashi (@kotobuki)
 * 
 * 0. If you don't have a Pachube account, sign up at 
 *    http://www.pachube.com/signup
 * 1. Register a feed at http://www.pachube.com/feeds/new
 * 2. Add 3 datastreams to the feed
 *    * Latitude
 *    * Longitude
 *    * Radiation dose rate
 * 3. Configure setting in the 'PrivateSettings' tab
 * 4. Run this sketch and choose a file to be uploaded to Pachube
 * 
 * NOTE:
 * For a 'Pachube Basic' account, 
 * the limit of uploading existing datapoints is 500 points/day
 */

// Replace with your Pachube feed ID
int pachubeFeedId = 12345;

// Replace with your Pachube API Key
String pachubeApiKey = "*******************************************";

// Replace if you are not living in Japan
String timeZone = "+09:00";

// Replace with your data stream IDs
String latitudeDataStreamId = "0";
String longitudeDataStreamId = "1";
String radiationDoseRateDataStreamId = "2";

UploaderThread uploader;

String progressMessage = "";
String loadPath;
int lineCount = 0;
float progress = 0;

void setup() {
  size(640, 480);
  textFont(createFont("CourierNewPSMT", 12));

  // Opens a file chooser
  loadPath = selectInput("Please select a log file to be uploaded to Pachube");

  if (loadPath == null) {
    noLoop();
    exit();
  }

  String[] settings = loadStrings("settings.txt");
  for (int i = 0; i < settings.length; i++) {
    String value = split(settings[i], ',')[1];
    if (value == null) {
      continue;
    }
    value = trim(value);
    println(value);

    if (settings[i].startsWith("Latitude")) {
      latitudeDataStreamId = value;
      trace("Latitude datastream ID: " + latitudeDataStreamId);
    } 
    else if (settings[i].startsWith("Longitude")) {
      longitudeDataStreamId = value;
      trace("Longitude datastream ID: " + longitudeDataStreamId);
    } 
    else if (settings[i].startsWith("Radiation dose rate")) {
      radiationDoseRateDataStreamId = value;
      trace("Radiation dose rate datastream ID: " + radiationDoseRateDataStreamId);
    } 
    else if (settings[i].startsWith("API Key")) {
      pachubeApiKey = value;
      trace("Pachube API Key: " + pachubeApiKey);
    } 
    else if (settings[i].startsWith("Feed ID")) {
      pachubeFeedId = int(value);
      trace("Pachube Feed ID: " + pachubeFeedId);
    }
  }

  trace("Started uploading " + loadPath);

  uploader = new UploaderThread();
  uploader.start();
}

void draw() {
  background(255);
  fill(0);
  text(progressMessage, 10, 50);

  float lineWidth = map(progress, 0, 1, 10, width - 20);
  strokeWeight(3);
  stroke(236, 0, 140);
  line(10, 20, width - 10, 20);
  stroke(0, 174, 239);
  line(10, 20, 10 + lineWidth, 20);
}

void trace(String newMessage) {
  lineCount++;

  if (lineCount > 25) {
    progressMessage = "";
    lineCount = 0;
  }

  progressMessage += newMessage + "\n";
}

void httpPostData(int feedId, String datastreamId, String csvData) {
  String urlString = "http://api.pachube.com/v2/feeds/";
  urlString += feedId;
  urlString += "/datastreams/" + datastreamId + "/datapoints.csv";

  try {
    URL url = new URL(urlString);
    HttpURLConnection httpConnection = (HttpURLConnection)url.openConnection();
    httpConnection.setRequestMethod("POST");
    httpConnection.setDoOutput(true);

    httpConnection.setRequestProperty("X-PachubeApiKey", pachubeApiKey);
    httpConnection.setRequestProperty("Content-Type", "text/csv");

    OutputStreamWriter osw = new OutputStreamWriter(httpConnection.getOutputStream());
    osw.write(csvData);
    osw.flush();
    osw.close();

    String message = "";
    message += "Response for Datastream (" + datastreamId + "): ";
    message += httpConnection.getResponseCode() + " (";
    message += httpConnection.getResponseMessage() + ")";

    trace(message);

    BufferedReader reader = new BufferedReader(new InputStreamReader(httpConnection.getInputStream()));
    while (true) {
      String line = reader.readLine();
      if (line == null) {
        break;
      }
    }
    reader.close();

    httpConnection.disconnect();
  } 
  catch (MalformedURLException e) {
    println("ERROR: " + e);
    return;
  } 
  catch (IOException e) {
    println("ERROR: " + e);
    return;
  }
}

class UploaderThread extends Thread {
  UploaderThread() {
  }

  void run() {
    String lines[] = loadStrings(loadPath);

    String latitudeDataStream = "";
    String longitudeDataStream = "";
    String radiationDoseRateDataStream = "";

    int lineCount = 0;

    int i = 0;
    for (i = 0; i < lines.length; i++) {
      //  0: year-month-day
      //  1: hour:minute:second
      //  2: CPM (counts-per-minute)*
      //  3: Latitude: ddmm.mmmm, dd is integer in degree, mm.mmmm is decimal in minute. We can divide mm.mmmm by 60 to get degrees.
      //  4: N/S (north/south indicator)
      //  5: Longitude: dddmm.mmmm, ddd is integer in degree, mm.mmmm is decimal in minute. We can divide mm.mmmm by 60 to get degrees.
      //  6: E/W (east/west indicator)
      //  7: GPS Quality indicator (1 = good, 0 = NG)
      //  8: Number of satellites available
      //  9: Precision in metres
      // 10: Altitude in metres
      // 11: GPS Device name
      // 12: Measurement type
      String[] column = split(lines[i], ",");
      if (column == null || column.length < 13) {
        println("Skipped (" + i + "): " + lines[i]);
        continue;
      }

      // Latitude should be ddmm.mmmm, Longitude should be dddmm.mmmm
      if (column[3].length() != 9 || column[5].length() != 10) {
        println("Skipped (" + i + "): " + lines[i]);
        continue;
      }

      String timeStamp = column[0] + "T" + column[1] + timeZone;

      // ddmm.mmmm => dd + (mm.mmmm / 60)
      latitudeDataStream += timeStamp + "," + (float(column[3].substring(0, 2)) + float(column[3].substring(2)) / 60.0) + "\n";

      // dddmm.mmmm => ddd + (mm.mmmm / 60)
      longitudeDataStream += timeStamp + "," + (float(column[5].substring(0, 3)) + float(column[5].substring(3)) / 60.0) + "\n";

      // 350CPM = 1µSv/h
      radiationDoseRateDataStream += timeStamp + "," + (float(column[2]) / 350.0) + "\n";

      lineCount++;
      if (lineCount == 100) {
        trace("Uploading: " + i + "/" + lines.length);

        httpPostData(pachubeFeedId, latitudeDataStreamId, latitudeDataStream);
        httpPostData(pachubeFeedId, longitudeDataStreamId, longitudeDataStream);
        httpPostData(pachubeFeedId, radiationDoseRateDataStreamId, radiationDoseRateDataStream);

        progress = float(i) / float(lines.length);

        latitudeDataStream = "";
        longitudeDataStream = "";
        radiationDoseRateDataStream = "";
        lineCount = 0;
      }
    }
    trace("Uploading: " + i + "/" + lines.length);

    httpPostData(pachubeFeedId, latitudeDataStreamId, latitudeDataStream);
    httpPostData(pachubeFeedId, longitudeDataStreamId, longitudeDataStream);
    httpPostData(pachubeFeedId, radiationDoseRateDataStreamId, radiationDoseRateDataStream);

    trace("Finished uploading " + loadPath);
    progress = 1.0;
  }
}

