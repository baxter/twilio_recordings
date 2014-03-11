require "minitest/autorun"
require "webmock/minitest"
require "./lib/twilio_recordings"

puts "This is the spec!"

describe TwilioRecordings do
  before do
    @account_sid = "ACeb4e7b38952d70a91bc4a4acea8dc9e0"
    @recording_sids = [
      "RE93fcf1c3912aea0db664914147789e10",
      "REcd5c5bec7ff667d5c3f1502d04ccb79e",
      "REf7b24375cdbbbb42f58828f2fdf7b5a9",
      "RE23c45b6262e256a455b1ee296af53fbb"
    ]

    @twilio_api_url = "https://api.twilio.com/2010-04-01/Accounts/ACeb4e7b38952d70a91bc4a4acea8dc9e0/Recordings/"
    @tmp_dir = File.join('.','spec','tmp')

    FileUtils.mkdir_p(@tmp_dir) # Create tmp dir if it doesn't exist

    @stubbed_filenames = @recording_sids.map { |sid| sid + ".mp3" }
    @expected_urls     = @stubbed_filenames.map { |filename| @twilio_api_url + filename }

    @stubbed_requests = @expected_urls.zip(@stubbed_filenames).map do |url, filename|
      stub_request(:get, url).to_return(:body => File.new(File.join('.','spec','fixtures','recordings',filename)), :stats => 200)
    end

    @twilio_recordings = TwilioRecordings.new(@account_sid, @recording_sids, :tmp_dir => @tmp_dir)
  end

  after do
    FileUtils.remove_dir(@tmp_dir)
  end

  describe ".sanitize" do
    it "must remove '..'" do
      TwilioRecordings.sanitize('../etc/passwd').must_equal 'etcpasswd'
    end
  end

  describe "#filenames" do
    it "must return a list of all recording filenames" do
      @recording_sids.zip(@twilio_recordings.filenames).each do |recording_sid, recording_filename|
        recording_filename.must_include recording_sid
        recording_filename.must_match /\.mp3$/
      end
    end

    it "must remove '..' from filenames" do
      recording_sids = ['../etc/passwd']
      twilio_recordings = TwilioRecordings.new(@account_sid, recording_sids, :tmp_dir => @tmp_dir)
      twilio_recordings.filenames.first.must_include "etcpasswd"
      twilio_recordings.filenames.first.wont_include ".."
    end
  end

  describe "#twilio_urls" do
    it "must return a list of recording URLs" do
      @twilio_recordings.twilio_urls.must_equal @expected_urls
    end
  end

  describe "#connection" do
    it "must return a connection object" do
      @twilio_recordings.connection.must_respond_to :get
    end
  end

  describe "#download" do
    it "must perform a GET on all of the URLs" do
      @twilio_recordings.download
      @stubbed_requests.each do |request|
        assert_requested(request)
      end
    end

    it "must save the contents of the URLs to file" do
      @twilio_recordings.download
      @stubbed_filenames.zip(@twilio_recordings.filenames).each do |original_filename, tmp_filename|
        assert FileUtils.compare_file(File.join('.', 'spec', 'fixtures', 'recordings', original_filename), tmp_filename)
      end
    end
  end

  describe "#join" do
    before do
      @output_filename = File.join(@tmp_dir, 'output_file.mp3')
      @twilio_recordings.download
    end

    it "must join the downloaded files into one file" do
      @twilio_recordings.join(@output_filename)
      # assert file size of 1 + 2 + 3 + 4 = output file
      combined_size = @stubbed_filenames.inject(0) do |sum, filename|
        sum += File.size(File.join('.', 'spec', 'fixtures', 'recordings', filename))
      end
      combined_size.must_equal File.size(@output_filename)
    end
  end

  describe "#cleanup" do
    before do
      @output_filename = File.join(@tmp_dir, 'output_file.mp3')
      @twilio_recordings.download
      @tmp_filenames = @twilio_recordings.filenames
    end

    it "must delete the temp files when cleanup is called" do
      @twilio_recordings.cleanup
      @tmp_filenames.each do |tmp_filename|
        refute File.exist?(tmp_filename)
      end
    end
  end
end
