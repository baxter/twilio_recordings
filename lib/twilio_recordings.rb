require 'faraday'
require 'typhoeus/adapters/faraday'

class TwilioRecordings
  attr_writer :connection

  ##
  # Instantiate a new TwilioRecordings object.
  # 
  # Example:
  #   >> t = TwilioRecordings.new(account_sid, recording_sids, tmp_dir: './my_tmp_dir')
  #   => #<TwilioRecordings:0x00... > 
  #
  # Arguments:
  #   account_sid: The Twilio account SID, e.g. "AC12345678901234567890123456789012"
  #   recording_sids: An array of recording SIDs, e.g. ["RE12345678901234567890123456789012"]
  #   tmp_dir: The directory that the recordings will be temporarily downloaded to. (optional, default is '/tmp')
  def initialize(account_sid, recording_sids, tmp_dir: File.join('','tmp'))
    @account_sid = account_sid
    @recording_sids = recording_sids
    @tmp_dir = tmp_dir
    @recording_downloads = {}
  end

  ##
  # Return a list of URL strings based on the account SID and recording SIDs.
  #
  # Example:
  #   >> t.twilio_urls
  #   => ["https://api.twilio.com/2010-04-01/Accounts/AC12345678901234567890123456789012/Recordings/RE12345678901234567890123456789012.mp3"]
  def twilio_urls
    @recording_sids.map { |r| "https://api.twilio.com/2010-04-01/Accounts/#{@account_sid}/Recordings/#{r}.mp3" }
  end

  ##
  # Return a list of URL strings based on the account SID and recording SIDs.
  #
  # Example:
  #   >> t.twilio_urls
  #   => ["./my_tmp_dir/RE12345678901234567890123456789012.mp3"]
  def filenames
    @recording_sids.map { |r| File.join(@tmp_dir, "#{r}.mp3") }
  end

  ##
  # Return the Faraday connection used to download the recordings.
  # 
  # Will create a new connection if one has not already been set with connection=.
  #
  # Example:
  #   >> t.connection
  #   => #<Faraday::Connection:0x00... >
  def connection
    @connection ||= Faraday.new do |faraday|
      faraday.adapter :typhoeus
    end
  end

  def download_and_join
    download
    join
  end

  ##
  # Download the recordings to @tmp_dir
  #
  # Returns self
  #
  # Example:
  #   >> t.download
  #   => #<TwilioRecordings:0x00... >
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

    self
  end

  ##
  # Join the recordings together into a single file. Returns the output filename.
  #
  # Example: 
  #   >> t.join('~/my_file.mp3')
  #   => "~/my_file.mp3"
  #
  # Arguments:
  #   output: A string to the filename that the output should be written to. (optional, default is '/tmp/joined_{recording_ids}')
  def join(output=nil)
    output ||= File.join(@tmp_dir, "joined_#{@recording_sids.join('_')}.mp3")
    `cat #{filenames.join(" ")} > #{output}`
    output
  end
end