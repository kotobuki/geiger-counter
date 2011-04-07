#!/usr/bin/env ruby -wKU

require 'csv'
require 'nkf'
require 'jcode'

require 'api_key'

$KCODE = "UTF8"

# http://oku.edu.mie-u.ac.jp/~okumura/stat/data/
baseFileName = "mext"
# feedId = 22002
feedId = 22019

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
# system("curl http://oku.edu.mie-u.ac.jp/~okumura/stat/data/fukushima2.csv > tmp2.csv")
# system("diff fukushima2.csv tmp2.csv > diff2.csv")
# 
# if (File.open("diff2.csv").read.count("\n") > 0) then
#   p "found changes"
#   exit
# else
#   p "found no changes"
#   exit
# end

reader = CSV.open(baseFileName + '.csv', 'r')

# skip the first two lines
# reader.shift  # 
# reader.shift  # 

lineCount = 0

dateRows, timeRows, valueRows = []

reader.each do |row|
  if lineCount == 2 then
    dateRows = Marshal.load(Marshal.dump(row))
  elsif lineCount == 3 then
    timeRows = Marshal.load(Marshal.dump(row))
  elsif lineCount == 12 then
    valueRows = Marshal.load(Marshal.dump(row))
  end
  lineCount += 1
end

year = "2011"
date, time, value = ""

lineCount = 0
fileCount = 0
writer = File::open(baseFileName + "-" + fileCount.to_s + ".csv", "w")

for i in 2..(dateRows.length - 2)
  date = NKF.nkf("-Sw", dateRows[i]) unless dateRows[i] == nil
  time = NKF.nkf("-Sw", timeRows[i]) unless timeRows[i] == nil
  next if valueRows[i] == nil

  month, day = date.delete("日").split('月')
  hour = time.split('-')[0]
  value = valueRows[i]

  # ISO 8601
  formattedDate = format("%04d-%02d-%02dT%02d:%02d:00+09:00", year.to_i, month.to_i, day.to_i, hour.to_i, 0)

  writer.puts formattedDate + "," + value

  lineCount += 1

  if (lineCount == 100) then
    writer.close
    upload_to_pachube(feedId, baseFileName + "-" + fileCount.to_s + ".csv")

    lineCount = 0
    fileCount += 1
    writer = File::open(baseFileName + "-" + fileCount.to_s + ".csv", "w")      
  end
end

writer.close
upload_to_pachube(feedId, baseFileName + "-" + fileCount.to_s + ".csv")