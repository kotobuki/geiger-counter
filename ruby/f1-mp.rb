#!/usr/bin/env ruby -wKU

# http://www.tepco.co.jp/en/nu/fukushima-np/f1/index-e.html

require 'csv'
require 'api_key'

baseFileName = "f1-mp"
outFileName = ["MP-1", "MP-2", "MP-3", "MP-4", "MP-5", "MP-6", "MP-7", "MP-8"]

# The feed IDs for MP-1, 2, 3, 4, 5, 6, 7 and 8
feedId = [22524, 22525, 22526, 22527, 22530, 22531, 22532, 22533]

def upload_to_pachube(feedId, csvFileName)
  begin
    commandString = "curl --request POST --data-binary @"
    commandString += csvFileName
    commandString += " --header \"X-PachubeApiKey: " + @apiKey + "\" "
    commandString += "http://api.pachube.com/v2/feeds/" + feedId.to_s + "/datastreams/0/datapoints.csv"
    print commandString + "\n"
    system(commandString)
    system("rm " + csvFileName)
  rescue
    puts "error uploading"
  end
end

# compare local file with the remote file
system("curl http://oku.edu.mie-u.ac.jp/~okumura/stat/data/f1-mp.csv > tmp.csv")
system("diff f1-mp.csv tmp.csv > diff.csv")

if (File.open("diff.csv").read.count("\n") > 0) then
  p "found changes"
else
  p "found no changes"
  exit
end

outFileName.length.times do |i|
  reader = CSV.open(baseFileName + '.csv', 'r')

  # skip the first two lines
  reader.shift
  # reader.shift

  lineCount = 0
  fileCount = 0

  writer = File::open(baseFileName + "_" + outFileName[i] + "-" + fileCount.to_s + ".csv", "w")

  reader.each do |row|
    row[0].delete!(">")
    row[0].strip!
    d = row[0].split('/')
    t = row[1].split(':')

    next if row[i + 2] == nil || row[i + 2] == '-'

    # ISO 8601
    formattedDate = format("%04d-%02d-%02dT%02d:%02d:00+09:00", d[0].to_i, d[1].to_i, d[2].to_i, t[0].to_i, t[1].to_i)
    writer.puts formattedDate + "," + row[i + 2]  # in µSv/h

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
system("mv tmp.csv f1-mp.csv")
system("rm diff*.csv")