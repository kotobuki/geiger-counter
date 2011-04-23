#!/usr/bin/env ruby -wKU

# http://oku.edu.mie-u.ac.jp/~okumura/stat/data/20-50km.csv

# Reference:
# http://api.pachube.com/v2/#update-datastream-put-v2-feeds-feed-id-datastreams-datastream-id

require 'csv'
require 'api_key'

baseFileName = "20-50km"

# The feed IDs for MP-1, 2, 3, 4, 5, 6, 7 and 8
feedId = [23409, 23410, 23411, 23412, 23413, 23414, 23415, 23416, 23417]

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
system("curl http://oku.edu.mie-u.ac.jp/~okumura/stat/data/20-50km.csv > tmp.csv")
system("diff 20-50km.csv tmp.csv > diff.csv")

if (File.open("diff.csv").read.count("\n") > 0) then
  p "found changes"
else
  p "found no changes"
  exit
end

feedId.length.times do |i|
  reader = CSV.open('diff.csv', 'r')

  # skip the first two lines
  reader.shift

  lineCount = 0
  fileCount = 0

  writer = File::open(baseFileName + "_" + feedId[i].to_s + "-" + fileCount.to_s + ".csv", "w")

  reader.each do |row|
    next if row[0] == nil
    next if row[0].index(">") != 0

    row[0].delete!(">")
    row[0].strip!
    d = row[0].split(' ')[0].split('-')
    t = row[0].split(' ')[1].split(':')

    next if row[i + 1] == nil || row[i + 1] == '-'

    # ISO 8601
    formattedDate = format("%04d-%02d-%02dT%02d:%02d:00+09:00", d[0].to_i, d[1].to_i, d[2].to_i, t[0].to_i, t[1].to_i)
    writer.puts formattedDate + "," + row[i + 1]  # in µSv/h

    lineCount += 1

    if (lineCount == 50) then
      writer.close
      upload_to_pachube(feedId[i], baseFileName + "_" + feedId[i].to_s + "-" + fileCount.to_s + ".csv")

      lineCount = 0
      fileCount += 1
      writer = File::open(baseFileName + "_" + feedId[i].to_s + "-" + fileCount.to_s + ".csv", "w")      
    end
  end

  writer.close
  upload_to_pachube(feedId[i], baseFileName + "_" + feedId[i].to_s + "-" + fileCount.to_s + ".csv")
end

# replace the local file
system("mv tmp.csv 20-50km.csv")
system("rm diff*.csv")
system("rm 20-50km_*.csv")