#!/usr/bin/env ruby -wKU

require 'csv'

baseFileName = "fukushima1MP"
outFileName = ["MainBuilding", "MainGate", "WestGate"]

outFileName.length.times do |i|
  reader = CSV.open(baseFileName + '.csv', 'r')

  # skip header lines
  reader.shift
  reader.shift

  lineCount = 0
  fileCount = 0

  writer = File::open(baseFileName + "_" + outFileName[i] + "-" + fileCount.to_s + ".csv", "w")

  reader.each do |row|
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
      lineCount = 0
      fileCount += 1
      writer = File::open(baseFileName + "_" + outFileName[i] + "-" + fileCount.to_s + ".csv", "w")      
    end
  end

  writer.close
end