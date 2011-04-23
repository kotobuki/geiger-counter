#!/usr/bin/env ruby -wKU

require 'csv'
require 'nkf'
require 'jcode'

require 'api_key'

$KCODE = "UTF8"

baseFileName = "fukushima2"
feedId = 21726

def upload_to_pachube(feedId, csvFileBaseName)
  reader = File::open(csvFileBaseName + '.csv', 'r')

  # skip the first line
  reader.gets

  lineCount = 0
  fileCount = 0

  writer = File::open(csvFileBaseName + "-" + fileCount.to_s + ".csv", "w")

  while line = reader.gets do
    line.delete!(">")
    line.strip!

    writer.puts line

    lineCount += 1
    if (lineCount == 100) then
      writer.close

      lineCount = 0
      fileCount += 1
      writer = File::open(csvFileBaseName + "-" + fileCount.to_s + ".csv", "w")      
    end
  end

  writer.close

  (fileCount + 1).times do |i|
    begin
      commandString = "curl --request POST --data-binary @"
      commandString += csvFileBaseName + "-" + i.to_s + ".csv"
      commandString += " --header \"X-PachubeApiKey: " + @apiKey + "\" "
      commandString += "http://api.pachube.com/v2/feeds/" + feedId.to_s + "/datastreams/0/datapoints.csv"
      print commandString + "\n"
      system(commandString)
    rescue
      puts "error uploading"
    end
  end

end

def create_csv_file_for_pachube(inFileName, outFileName)
  reader = CSV.open(inFileName, 'r')
  writer = File::open(outFileName, "w")

  # skip the header lines
  reader.shift
  reader.shift

  lineCount = 0
  fileCount = 0

  year, month, day = "2011", "" , ""

  reader.each do |row|
    row[1] = NKF.nkf("-Sw", row[1]) unless row[1] == nil
    row[3] = NKF.nkf("-Sw", row[3]) unless row[3] == nil

    # update if row[0] is not nil
    if (row[0] != nil) then
      row[0] = NKF.nkf("-Sw", row[0])
      row[0].delete!("日")
      month, day = row[0].split('月')
    end

    row[1].delete!("分")
    row[1].sub!("時", ":")

    if (row[1].index("午後") == 0) then 
      offset = 12
    else
      offset = 0
    end
    row[1].delete!("午前後")

    hour, minute = row[1].split(":")
    hour = (hour.to_i + offset).to_s

    # ISO 8601
    formattedDate = format("%04d-%02d-%02dT%02d:%02d:00+09:00", year.to_i, month.to_i, day.to_i, hour.to_i, minute.to_i)

    row[3].delete!("μSv/h")
    row[3].strip!

    writer.puts formattedDate + "," + row[3]
  end

  writer.close
end

# compare local file with the remote file
system("curl http://oku.edu.mie-u.ac.jp/~okumura/stat/data/fukushima2.csv > tmp2.csv")
system("diff fukushima2.csv tmp2.csv > diff2.csv")

if (File.open("diff2.csv").read.count("\n") > 0) then
  p "found changes"
  create_csv_file_for_pachube("fukushima2.csv", "tmp2_old.csv")
  create_csv_file_for_pachube("tmp2.csv", "tmp2_new.csv")
  system("diff tmp2_old.csv tmp2_new.csv > tmp2_diff.csv")
  upload_to_pachube(feedId, "tmp2_diff")
else
  p "found no changes"
  exit
end

# replace the local file
system("mv tmp2.csv fukushima2.csv")
system("rm tmp2*.csv")