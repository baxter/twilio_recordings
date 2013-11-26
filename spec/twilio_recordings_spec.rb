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
    @tmp_dir = "./spec/tmp"

    @expected_filenames = @recording_sids.map { |sid| sid + ".mp3" }
    @expected_paths     = @expected_filenames.map { |filename| File.join(@tmp_dir, filename) }
    @expected_urls      = @expected_filenames.map { |filename| @twilio_api_url + filename }

    @twilio_recordings = TwilioRecordings.new(@account_sid, @recording_sids, tmp_dir: @tmp_dir)
  end

  describe "#filenames" do
    it "must return a list of all recording filenames" do
      @twilio_recordings.filenames.must_equal @expected_paths
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
    before do
      @stubs = @expected_urls.zip(@expected_filenames).map do |url, filename|
        stub_request(:get, url).
          to_return(body: File.new("./spec/fixtures/recordings/#{filename}"), stats: 200)
      end
    end

    it "must perform a GET on all of the URLs" do
      @twilio_recordings.download
      @stubs.each do |stub|
        assert_requested(stub)
      end
    end

    it "must save the contents of the URLs to file" do
      @twilio_recordings.download
      @expected_filenames.zip(@expected_paths).each do |filename, path|
        assert FileUtils.compare_file("./spec/fixtures/recordings/#{filename}", path)
      end
    end
  end
end