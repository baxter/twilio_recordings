require 'faraday'
require 'typhoeus/adapters/faraday'

class TwilioRecordings
  attr_writer :connection
  attr_reader :tmp_dir 	# For testing

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
  #   tmp_dir: The directory that the recordings will be temporarily downloaded to. (optional, default is Dir.tmpdir() )
  def initialize(account_sid, recording_sids, options={})
    @account_sid = account_sid
    @recording_sids = recording_sids.map{ |sid| self.class.sanitize(sid) }
    @tmp_dir = options[:tmp_dir] || Dir.tmpdir

    @tmp_files = {}
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
    init_tmp_files
    @recording_sids.map { |sid| @tmp_files[sid].path }
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

  ##
  # Download the recordings to @tmp_dir
  #
  # Returns self
  #
  # Example:
  #   >> t.download
  #   => #<TwilioRecordings:0x00... >
  def download
    recording_downloads = {}
    # download the recordings
    in_parallel do
      twilio_urls.zip(@recording_sids).each do |url, sid|
        recording_downloads[sid] = connection.get(url)
      end
    end

    init_tmp_files

    # write the recordings to file
    recording_downloads.each do |sid, response|
      @tmp_files[sid].write(response.body)
      @tmp_files[sid].close
    end

    self
  end


  ##
  # Runs a block with parallel connection if there's several recordings
  #
  # Returns whatever the block returns
  #
  def in_parallel(&block)
    if @recording_sids.count > 1
      connection.in_parallel(&block)
    else
      block.call
    end
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
    unless output
      output_file = Tempfile.new(['joined_recording','.mp3'], @tmp_dir)
      output_file.binmode
      output_file.close
      output = output_file.path
    end
    `cat #{filenames.join(" ")} > #{output}`
    cleanup
    output
  end

  ##
  # Clean up the temporarily downloaded recordings.
  #
  # Example:
  #   >> t.cleanup
  #   => true
  def cleanup
    remove_tmp_files
  end

  ##
  # Sanitize the filename.
  #
  # Returns the sanitized filename.
  #
  # Example:
  #   TwilioRecordings.sanitize('../etc/passwd') => 'etcpasswd'
  def self.sanitize(filename)
    filename.gsub(/[^a-zA-Z0-9]/, '')
  end

  private

  def init_tmp_files
    return unless @tmp_files == {}
    @recording_sids.each do |sid|
      @tmp_files[sid] = Tempfile.new([sid,'.mp3'], @tmp_dir)
      @tmp_files[sid].binmode
    end
  end

  def remove_tmp_files
    return if @tmp_files == {}
    @tmp_files.values.each do |file|
      file.unlink
    end
    @tmp_files = {}
  end
end
