#!/usr/bin/env ruby -wKU

require 'csv'
require 'api_key'

baseFileName = "7houbu"
outFileName = ["Fukushima", "Koriyama", "Shirakawa", "Aizuwakamatsu", "Minamiaizu", "Minamisoma", "Iwaki"]
feedId = [21886, 21887, 21888, 21889, 21890, 21891, 21892]
targetColumn = [1, 3, 4, 5, 6, 7, 8]

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
system("curl http://oku.edu.mie-u.ac.jp/~okumura/stat/data/7houbu.csv > tmp.csv")
system("diff 7houbu.csv tmp.csv > diff.csv")

if (File.open("diff.csv").read.count("\n") > 0) then
  p "found changes"
else
  p "found no changes"
  exit
end

outFileName.length.times do |i|
  reader = CSV.open('diff.csv', 'r')

  # skip the first line
  reader.shift

  lineCount = 0
  fileCount = 0

  writer = File::open(baseFileName + "_" + outFileName[i] + "-" + fileCount.to_s + ".csv", "w")

  d = ["1970", "01", "01"]
  t = ["00", "00"]

  reader.each do |row|
    row[0].delete!(">")
    row[0].strip!

    d = row[0].split(' ')[0].split('-')
    t = row[0].split(' ')[1].split(':')

    next if row[targetColumn[i]] == nil

    # ISO 8601
    formattedDate = format("%04d-%02d-%02dT%02d:%02d:00+09:00", d[0].to_i, d[1].to_i, d[2].to_i, t[0].to_i, t[1].to_i)
    writer.puts formattedDate + "," + row[targetColumn[i]]  # in µSv/h

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
system("mv tmp.csv 7houbu.csv")
system("rm 7houbu_*.csv")
system("rm diff.csv")