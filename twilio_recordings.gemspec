Gem::Specification.new do |s|
  s.name        = 'twilio_recordings'
  s.version     = '0.0.8'
  s.date        = '2013-11-27'
  s.summary     = "TwilioRecordings"
  s.description = "Utility for downloading and joining recordings from Twilio."
  s.authors     = ["Paul Boxley"]
  s.email       = 'paul@paulboxley.com'
  s.files       = ["lib/twilio_recordings.rb"]

  s.add_dependency "typhoeus", '>= 0.5.0'
  s.add_dependency "faraday"
end
