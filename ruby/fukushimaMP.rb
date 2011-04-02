#!/usr/bin/env ruby -wKU

require 'csv'
require 'api_key'

baseFileName = "diff"
outFileName = ["MainBuilding", "MainGate", "WestGate"]
feedId = [21610, 21619, 21620]

def upload_to_pachube(feedId, csvFileName)
  begin
    commandString = "curl --request POST --data-binary @"
    commandString += csvFileName
    commandString += " --header \"X-PachubeApiKey: " + @apiKey + "\" "
    commandString += "http://api.pachube.com/v2/feeds/" + feedId.to_s + "/datastreams/0/datapoints.csv"
    print commandString + "\n"
    system(commandString)
  rescue
    puts "error uploading"
  end
end

# compare local file with the remote file
system("curl http://oku.edu.mie-u.ac.jp/~okumura/stat/data/fukushima1MP.csv > tmp.csv")
system("diff fukushima1MP.csv tmp.csv > diff.csv")

if (File.open("diff.csv").read.count("\n") > 0) then
  p "found changes"
else
  p "found no changes"
  exit
end

outFileName.length.times do |i|
  reader = CSV.open(baseFileName + '.csv', 'r')

  # skip the first line
  reader.shift

  lineCount = 0
  fileCount = 0

  writer = File::open(baseFileName + "_" + outFileName[i] + "-" + fileCount.to_s + ".csv", "w")

  reader.each do |row|
    row[0].delete!(">")
    row[0].strip!
    date, time = row[0].split(' ')
    d = date.split('/')
    t = time.split(':')

    # ISO 8601
    formattedDate = format("%04d-%02d-%02dT%02d:%02d:00+09:00", d[0].to_i, d[1].to_i, d[2].to_i, t[0].to_i, t[1].to_i)
    if (i == 0) then
      writer.puts formattedDate + "," + (row[i + 1].to_f * 1000).to_s # convert from mSv/h to µSv/h
    else
      writer.puts formattedDate + "," + row[i + 1]  # in µSv/h
    end

    lineCount += 1
    if (lineCount == 100) then
      writer.close
      upload_to_pachube(feedId[i], baseFileName + "_" + outFileName[i] + "-" + fileCount.to_s + ".csv")

      lineCount = 0
      fileCount += 1
      writer = File::open(baseFileName + "_" + outFileName[i] + "-" + fileCount.to_s + ".csv", "w")      
    end
  end

  writer.close
  upload_to_pachube(feedId[i], baseFileName + "_" + outFileName[i] + "-" + fileCount.to_s + ".csv")
end

# replace the local file
system("mv tmp.csv fukushima1MP.csv")
system("rm diff*.csv")