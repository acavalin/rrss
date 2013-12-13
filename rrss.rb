#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require_relative File.join('lib', 'rss_mngr')

config = YAML::load_file('config.yml')[:rss_mngr]  # load configuration

STDOUT.sync = true
rssdler = RSSDler.new(
  :load_gui_details => true,
  # :log_lines        => 1000,
  # :log_level        => :INFO, # DEBUG INFO WARN ERROR FATAL
  # :log_dev          => STDOUT,
)

# start feeds download thread (interval check)
stop_dling = false  # flag to stop the thread
thr = Thread.new do
  loop do
    rssdler.check_feeds

    (config['check_interval'] * 30).times do
      sleep 2
      Thread.exit if stop_dling
    end # sleep
  end # loop
end # thread

# sinatra app/gui
RSSMngr.set :rssdler,     rssdler
RSSMngr.set :environment, :production
RSSMngr.run!

# stop feeds download thread
print "waiting downloads to finish (max #{config['exit_grace_time']}')... "
stop_dling = true
thr.join config['exit_grace_time'] * 60
thr.kill if thr.alive?
puts 'done'
