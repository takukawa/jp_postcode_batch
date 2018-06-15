require 'settingslogic'
require 'open-uri'
require 'zip'

class Settings < Settingslogic
  source "./application.yaml"
  namespace 'zip'
end

def decompress(file, outpath)
  entries = []
  Dir.mkdir(outpath) unless Dir.exist?(outpath)
  input = Zip::InputStream.open(file, 0)
  while (entry = input.get_next_entry)
    savepath  = File.join(outpath, entry.name)
    writefile = File.open(savepath, 'wb')
    writefile.puts(input.read.encode('UTF-8', Settings.baseEncording))
    entries << savepath
  end
  entries
end

# get zipfile of jp-postcode from JapanPost
begin
  response = open(Settings.url, :redirect => false)
  open(Settings.workingDir + Settings.file, 'wb'){|output|output.write(response.read)}
rescue => e
  p e
end

# decompress(and change encode) the zipfile
begin
  decompress(Settings.workingDir + Settings.file, Settings.workingDir)
rescue => e
  p e
end
