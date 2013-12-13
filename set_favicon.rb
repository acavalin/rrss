#!/usr/bin/env ruby

if ARGV.size < 2
  puts "USAGE: #{File.basename __FILE__} feed_name favicon_uri"
  puts "  favicon_uri can be an URL or a local PATH"
  puts "  the favicon dimensions should be 16x16 pixels"
  exit
end

require_relative File.join('lib', 'rss_dler')

name = ARGV[0].downcase.tr(' ', '_')
uri  = ARGV[1]

STDOUT.sync = true
rssdler = RSSDler.new(
  :log_level => :WARN, # DEBUG INFO WARN ERROR FATAL
  :log_dev   => STDOUT
).set_favicon name, uri
