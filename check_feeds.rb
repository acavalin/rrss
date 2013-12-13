#!/usr/bin/env ruby
# encoding: utf-8

require_relative File.join('lib', 'rss_dler')

puts "USAGE: #{File.basename __FILE__} [dump_dir [format]]"

STDOUT.sync = true
rssdler = RSSDler.new(
  :log_level => :WARN, # DEBUG INFO WARN ERROR FATAL
  :log_dev   => STDOUT
)

checked = rssdler.check_feeds

# dump feed to file
dumpdir = ARGV[0]
format  = %w{xml json}.include?(ARGV[1]) ? ARGV[1].to_sym : :xml
if checked.size > 0 && dumpdir
  checked.each do |fcfg|
    puts "dumping #{fcfg[:name]}"
    fname = File.join dumpdir, "#{fcfg[:name]}.#{format}"
    File.open(fname, 'w'){|f| f.puts rssdler.dump(fcfg[:name], format) }
  end
end
