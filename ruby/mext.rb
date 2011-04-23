#!/usr/bin/env ruby -wKU

require 'csv'
require 'nkf'
require 'jcode'

require 'api_key'

$KCODE = "UTF8"

# http://oku.edu.mie-u.ac.jp/~okumura/stat/data/
baseFileName = "mext"

# tokyo, gifu, nagoya, shizuoka, mie, kyoto, mito, utsunomiya, morioka, akita, yamagata, aomori, sendai, sapporo, uruma
targetRowNumber = [16, 24, 26, 25, 27, 29, 11, 12, 6, 8, 9, 5, 7, 4, 50]
feedId = [22002, 22004, 22005, 22014, 22015, 22017, 22018, 22019, 22446, 22447, 22448, 22450, 22449, 22453, 22452]

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

def create_csv_file_for_pachube(inFileName, outFileName, targetRow)
  reader = CSV.open(inFileName, 'r')
  writer = File::open(outFileName, "w")

  lineCount = 0

  dateColumns, timeColumns, valueColumns = []

  reader.each do |row|
    if lineCount == 2 then
      dateColumns = Marshal.load(Marshal.dump(row))
    elsif lineCount == 3 then
      timeColumns = Marshal.load(Marshal.dump(row))
    elsif lineCount == targetRow then
      valueColumns = Marshal.load(Marshal.dump(row))
    end
    lineCount += 1
  end

  year = "2011"
  date, time, value = ""

  for i in 2..(dateColumns.length - 2)
    date = NKF.nkf("-Sw", dateColumns[i]) unless dateColumns[i] == nil
    time = NKF.nkf("-Sw", timeColumns[i]) unless timeColumns[i] == nil
    next if valueColumns[i] == nil

    month, day = date.delete("日").split('月')
    hour = time.split('-')[0]
    value = valueColumns[i]

    # ISO 8601
    formattedDate = format("%04d-%02d-%02dT%02d:%02d:00+09:00", year.to_i, month.to_i, day.to_i, hour.to_i, 0)

    writer.puts formattedDate + "," + value
  end

  writer.close
end

# compare local file with the remote file
system("curl http://oku.edu.mie-u.ac.jp/~okumura/stat/data/mext.csv > tmp.csv")
system("diff mext.csv tmp.csv > diff3.csv")

if (File.open("diff3.csv").read.count("\n") > 0) then
  p "found changes"
  feedId.length.times do |i|
    create_csv_file_for_pachube("mext.csv", "tmp_old.csv", targetRowNumber[i])
    create_csv_file_for_pachube("tmp.csv", "tmp_new.csv", targetRowNumber[i])
    system("diff tmp_old.csv tmp_new.csv > tmp_diff.csv")
    upload_to_pachube(feedId[i], "tmp_diff")    
  end
else
  p "found no changes"
  exit
end

# replace the local file
system("mv tmp.csv mext.csv")
system("rm tmp*.csv")
system("rm diff3.csv")