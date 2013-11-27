require 'faraday'
require 'typhoeus/adapters/faraday'

class TwilioRecordings
  attr_accessor :connection

  def initialize(account_sid, recording_sids, tmp_dir: File.join('','tmp'))
    @account_sid = account_sid
    @recording_sids = recording_sids
    @tmp_dir = tmp_dir
    @recording_downloads = {}
  end

  def twilio_urls
    @recording_sids.map { |r| "https://api.twilio.com/2010-04-01/Accounts/#{@account_sid}/Recordings/#{r}.mp3" }
  end

  def filenames
    @recording_sids.map { |r| File.join(@tmp_dir, "#{r}.mp3") }
  end

  def connection
    @connection ||= Faraday.new do |faraday|
      faraday.adapter :typhoeus
    end
  end

  def download_and_join
    download
    join
  end

  def download
    # download the recordings
    connection.in_parallel do
      twilio_urls.zip(filenames).each do |url, filename|
        @recording_downloads[filename] = connection.get(url)
      end
    end

    # write the recordings to file
    @recording_downloads.each do |filename, response|
      File.open(filename, 'wb') { |f| f.write(response.body) }
    end
  end

  def join(output=nil)
    output ||= File.join(@tmp_dir, "joined_#{@recording_sids.join('_')}.mp3")
    `cat #{filenames.join(" ")} > #{output}`
  end
end