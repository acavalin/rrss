#!/usr/bin/env ruby
# encoding: utf-8

# --- HOWTOs -------------------------------------------------------------------
=begin
# zip/unzip a string
cstr = Zlib::Deflate.deflate str, 9
Zlib::Inflate.inflate cstr

# sqlite insert binary blob
db.execute( "insert into foo (?)", SQLite3::Blob.new("\0\1\2\3\4\5"))

# UTF-8 conversion
#   http://stackoverflow.com/questions/10200544/ruby-1-9-force-encoding-but-check

# Data URI scheme (for the favicon):
#   https://en.wikipedia.org/wiki/Data_URI_scheme

class String
  # overrides shellwords function to make it work with Dash too
  def shellescape
    "'#{self.to_s.gsub "'", "'\\\\''"}'"
  end # sh_escape --------------------------------------------------------------
end # String
=end

require_relative 'version'
require_relative 'utils'

require 'yaml'        # http://yaml.org/spec/1.1/
require 'json'        # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/json/rdoc/JSON.html
require 'open-uri'    # http://ruby-doc.org/stdlib-1.9.3/libdoc/open-uri/rdoc/OpenURI.html
require 'timeout'     # http://ruby-doc.org/stdlib-1.9.3/libdoc/timeout/rdoc/Timeout.html
require 'rss'         # http://ruby-doc.com/stdlib-1.9.3/libdoc/rss/rdoc/RSS.html
                      # http://www.cozmixng.org/~rwiki/?cmd=view;name=RSS+Parser%3A%3ATutorial.en
                      # http://en.wikipedia.org/wiki/RSS
require 'digest'      # http://ruby-doc.org/stdlib-1.9.3/libdoc/digest/rdoc/Digest.html
require 'fileutils'   # http://ruby-doc.org/stdlib-1.9.3/libdoc/fileutils/rdoc/FileUtils.html
require 'sqlite3'     # http://sqlite-ruby.rubyforge.org/sqlite3/faq.html
                      # http://www.sqlite.org/lang.html
                      # http://www.sqlite.org/pragma.html#syntax
                      # http://www.sqlite.org/datatype3.html
require 'open3'       # http://ruby-doc.org/stdlib-1.9.3/libdoc/open3/rdoc/Open3.html
require 'zlib'        # http://ruby-doc.com/stdlib-1.9.2/libdoc/zlib/rdoc/Zlib.html
require 'base64'      # http://ruby-doc.org/stdlib-1.9.3/libdoc/base64/rdoc/Base64.html
require 'stringio'    # http://ruby-doc.org/stdlib-1.9.3/libdoc/stringio/rdoc/StringIO.html
require 'logger'      # http://ruby-doc.org/stdlib-1.9.3/libdoc/logger/rdoc/Logger.html
require 'shellwords'  # http://ruby-doc.org/stdlib-1.9.3/libdoc/shellwords/rdoc/Shellwords.html

# require 'debugger'

class RSSDler
  include Utils
  
  # startup auto definedd constants (see config.yml)
  #   PERIOD        # default interval for feed check
  #   TIMEOUT       # open-uri timeout in seconds
  #   PARSE_TIMEOUT # rss parsing timeout in seconds
  #   MAX_ITEM_DAYS # number of required days to mark an item as old
  #   MAX_OLD_ITEMS # maximum number of old items to keep
  #   HASH_KEYS     # item properties to hash for generating his unique id
  
  AVAILABLE_HASH_KEYS = [ :id, :link, :title, :descr, :date ]
  
  ICON_MIMES = { 'ico' => 'x-icon', 'png' => 'png', 'gif' => 'gif' }
  
  AGENTS = {
    :rss_dler => [
      # engine/ver (system running this app) platform/ver (platform details) enhancements ...
      # eg: RSSDler/1.0 (Linux x86_64; en_US.UTF-8) ruby/1.9.2-p290 (open-uri, rss) RSSMngr/1.0 Sinatra/1.4.3
      [
        "RSSDler/#{RSS_DLER_VERSION}",
        "(#{Config::CONFIG['target_os'].capitalize} #{Config::CONFIG['target_cpu']}; en_US.UTF-8)",
        "#{RUBY_ENGINE}/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}",
        "(open-uri, rss)",
        "RSSMngr/#{RSS_MNGR_VERSION} Sinatra/#{Sinatra::VERSION}",
      ].join(' '),
    ],
    :rss_owl => [
      'RSSOwl/1.1.2 2005-06-12 (Windows; U; it)',
      'RSSOwl/1.1.3 2005-07-17 (Windows; U; en)',
      'RSSOwl/1.1.3 Preview Release 2005-07-14 (Windows; U; it)',
      'RSSOwl/1.2 2005-11-06 (Windows; U; it)',
    ],
    :liferea => [
      'Liferea/0.9.4 (Linux; en_US; http://liferea.sf.net/)',
      'Liferea/0.9.7b (Linux; it_IT.UTF-8; http://liferea.sf.net/)',
      'Liferea/1.0-RC4 (Linux; it_IT.UTF-8; http://liferea.sf.net/)',
      'Liferea/1.0.10 (Linux; it_IT.UTF-8; http://liferea.sf.net/)',
      'Liferea/1.0.12 (Linux; it_IT.UTF-8; http://liferea.sf.net/)',
    ],
    :firefox => [
      'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:23.0) Gecko/20130406 Firefox/23.0',
      'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:23.0) Gecko/20131011 Firefox/23.0',
      'Mozilla/5.0 (X11; Linux x86_64; rv:22.0) Gecko/20100101 Firefox/22.0',
      'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:21.0) Gecko/20130331 Firefox/21.0',
    ],
    :chrome => [
      'Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.2 Safari/537.36',
      'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1468.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 6.2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1467.0 Safari/537.36',
    ],
    :iexplorer => [
      'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)',
      'Mozilla/5.0 (Windows; U; MSIE 9.0; Windows NT 9.0; en-US)',
    ],
  }
  
  attr_reader :config
  attr_reader :feeds
  
  # options:
  #  - cfgfile  : full path to the YML config file
  #  - debug    : true/false - set the loglevel
  #  - log_lines: max logbuffer lines
  #  - log_level: DEBUG|INFO|WARN|ERROR|FATAL
  #  - log_dev  : nil=String buffer | STDOUT=to print on screen
  def initialize(options = {})
    @config = {}
    @config[:pwd      ] = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    @config[:cfgfile  ] = options[:cfgfile] || File.join(@config[:pwd], 'feeds.yml')
    @config[:dbdir    ] = File.join(@config[:pwd], 'db')
    @config[:feedsdb  ] = File.join(@config[:dbdir], 'feeds.db')
    @config[:newdbdir ] = File.join(@config[:dbdir], 'empty')
    @config[:log_lines] = (options[:log_lines] || 1000).to_i # number of log lines to keep
    
    begin # load feeds.yml
      @config[:feeds] = YAML::load_file(@config[:cfgfile])
    rescue
      STDERR.puts "ERROR loading #{@config[:cfgfile]}: #{$!}"
      exit -1
    end
    
    begin # setup class constants
      YAML::load_file(File.join(@config[:pwd], 'config.yml'))[:rss_dler].
        each{|k, v| self.class.const_set k.upcase, v}
    rescue
      STDERR.puts "ERROR loading config.yml: #{$!}"
      exit -1
    end
    
    @log_buffer = StringIO.new
    @log = Logger.new(options[:log_dev] || @log_buffer)
    @log.progname = self.class.to_s
    @log.level = Logger.const_get(options[:log_level] || :WARN) # DEBUG INFO WARN ERROR FATAL
    
    begin # sanitize/linearize feed tree
      @feeds = build_feed_list(@config[:feeds])
      @feeds.each do |f|
        f[:period ] ||= PERIOD                    # set default :period
        f[:name   ] = f[:name].to_s.tr(' ', '_')  # sanitize :name
        f[:summary] = true if f[:summary].nil?    # show summary by default
        f[:enabled] = true if f[:enabled].nil?    # enabled by default
        if f[:url] =~ /^#{URI::regexp}$/
          f[:link] ||= "http://#{URI.parse(f[:url]).host}"  # setup :link if not present
        else
          f.delete :url # don't consider invalid url
        end
      end
    rescue
      STDERR.puts "ERROR parsing #{@config[:cfgfile]}: #{$!}"
      exit -1
    end
    
    # setup main database file
    unless File.exists?(@config[:feedsdb])
      FileUtils.cp(File.join(@config[:newdbdir], 'feeds.db.empty'), @config[:feedsdb])
    end
    
    # initialize feed list and read data into @feeds
    begin
      db = SQLite3::Database.new(@config[:feedsdb])
      db.results_as_hash = true
      
      # read previous dates
      list = db.execute('SELECT name, last_update FROM feeds').
        inject({}){|h, row| h[ row['name'] ] = row['last_update']; h }
      
      db.transaction do |tr|
        empty_db_file = File.join(@config[:newdbdir], "feed.db.empty")
        
        @feeds.each do |f|
          @log.info "initializing #{f[:name]}..."
          
          # setup database files
          dbfile = File.join(@config[:dbdir], "#{f[:name]}.db")
          FileUtils.cp(empty_db_file, dbfile) unless File.exists?(dbfile)
          
          # initialize feed list
          tr.execute "INSERT OR IGNORE INTO feeds (name, last_update) VALUES(?, '2000-01-01 00:00:00')", f[:name]
          
          # download favicon
          if tr.get_first_value("SELECT favicon = '' FROM feeds WHERE name = ?", f[:name]).to_i == 1
            img = download_favicon f
            tr.execute "UPDATE feeds SET favicon = ? WHERE name = ?", SQLite3::Blob.new(img), f[:name]
          end
          
          if options[:load_gui_details]
            # load favicons
            f[:favicon] = tr.get_first_value("SELECT favicon FROM feeds WHERE name = ?", f[:name]).to_s
            
            # load unread items count
            begin
              db_feed = SQLite3::Database.new File.join(@config[:dbdir], "#{f[:name]}.db")
              f[:unread] = db_feed.get_first_value("SELECT COUNT(*) AS unread FROM items WHERE read = 0").to_i
              db_feed.close
            rescue
              @log.warn %Q|#{self.class}: unable to count unread items for "#{f[:name]}" (#{$!})|
              f[:unread] = 0
            end
          end # load_gui_details
          
          # read dates into @feeds
          f[:last_update] = Time.parse( list[ f[:name] ] || '2000-01-01 00:00:00' )
        end
      end # transaction
      
      db.execute "VACUUM"
      
      db.close
    rescue
      @log.error "#{self.class}: unable to open feeds DB (#{$!})"
      exit -1
    end
  end # initialize -------------------------------------------------------------
  
  def random_agent(engine = nil)
    k = AGENTS.keys.include?(engine) ? engine : AGENTS.keys.sample
    a = AGENTS[k].sample
    engine ? a : [ k, a ]
  end # random_agent -----------------------------------------------------------
  
  # return the config of the cheched feeds
  def check_feeds(names = %w{})
    list = (
      names.size == 0 ?
        @feeds :
        @feeds.select{|f| names.include? f[:name] }
    ).select{|f| f[:enabled]}
    
    checked = []
    
    if list.size > 0
      # @log.info "=== start checking #{'='*40}"
      list.each do |f|
        if Time.now >= f[:last_update] + f[:period] * 60
          process_feed f
          checked << f
        end
        ObjectSpace.garbage_collect
      end
      # @log.info "=== finished checking #{'='*40}"
      @log.info '='*60
      rotate_log_buffer
    end
    
    checked
  end # check_feeds ------------------------------------------------------------
  
  def set_favicon(name, uri)
    if fcfg = @feeds.detect{|f| f[:name] == name}
      begin
        img = download_favicon fcfg.merge(:link => uri), :use_full_url => true
        db  = SQLite3::Database.new(@config[:feedsdb])
        db.execute "UPDATE feeds SET favicon = ? WHERE name = ?", SQLite3::Blob.new(img), fcfg[:name]
      rescue
        @log.error "#{self.class}: error setting up favicon (#{$!})"
      end
    end
  end # set_favicon ------------------------------------------------------------
  
  # return the in-memory log buffer
  def log_buffer      ; @log_buffer.string     ; end # log_buffer --------------
  def purge_log_buffer; @log_buffer.string = ''; end # purge_log_buffer --------
  
  # dump feed items
  def dump(name, format = :xml)
    fcfg  = @feeds.detect{|f| f[:name] == name}
    items = []
    
    begin
      db = SQLite3::Database.new File.join(@config[:dbdir], "#{name}.db")
      db.results_as_hash = true
      
      raise "feed [#{name}] not configured" unless fcfg
    
      items = db.execute("SELECT * FROM items ORDER BY pub_date DESC").
        sort{|a,b| b['pub_date'] <=> a['pub_date']}. # make sure the order is really DESC
        map{|i|
          (0..15).each{|k| i.delete k}  # delete unused integer keys
          i.each{|k,v| i[k] = v.to_s.force_encoding('UTF-8')}
        }
      
      db.close
    rescue Exception => e
      begin; db.close; rescue; end
      items = err_item(name, e)
    end
    
    case format
      when :json
        fcfg = fcfg.clone
        [:favicon, :depth, :unread].each{|k| fcfg.delete k}
        fcfg[:items] = items.map{|i| %w{id hash_id name}.each{|k| i.delete k}; i}
        fcfg.to_json
      else # default xml
        rss = RSS::Maker.make("atom") do |maker|
          maker.channel.author  = random_agent(:rss_dler)
          maker.channel.updated = fcfg[:last_update]
          maker.channel.about   = fcfg[:link]
          maker.channel.title   = fcfg[:name]
          maker.channel.dc_type = "period:#{fcfg[:period].to_i},enabled:#{fcfg[:enabled]}"
          items.each do |i|
            maker.items.new_item do |item|
              item.link        = i['link'    ]
              item.title       = i['title'   ]
              item.updated     = i['pub_date']
              item.id          = i['guid'    ]
              item.description = i['content' ]
              item.comments    = i['comment' ]
              item.dc_type     = %w{read kept modified}.select{|k| i[k] == 1}.join(',')
            end
          end
        end
        rss.to_s
    end # case
  end # dump -------------------------------------------------------------------
  
  
  private # ____________________________________________________________________
  
  
  def rotate_log_buffer
    if @log_buffer.string.count("\n") > @config[:log_lines]
      lines = @log_buffer.string.split("\n")
      @log_buffer.string = lines[-@config[:log_lines], @config[:log_lines]].join("\n")
    end
  end
  
  # recursively populate the feeds array
  def build_feed_list(section)
    list = []
    
    if section.is_a?(Array)
      list += section.map{|s| build_feed_list s}.flatten # array of feeds
    elsif section.is_a?(Hash)
      list += section.has_key?(:name) ?
        [section] :
        build_feed_list(section.values[0]).flatten       # scan subdir
    end
    
    list
  end # build_feed_list --------------------------------------------------------
  
  def download_favicon(fcfg, options = {})
    @log.info "#{fcfg[:name]}: downloading favicon"
    
    open_uri_opts = {
      :read_timeout => 5,
      'User-Agent'  => random_agent(:firefox),
      'Referer'     => "http://#{fcfg[:link]}"
    }
    
    img = nil
    
    # FIXED: enforce timeout with a thread to bypass Resolv::DNS timeout
    thr = Thread.new do
      if options[:use_full_url]
        mime = ICON_MIMES[ fcfg[:link].gsub(/.*(...)$/, '\1') ]
        begin; Timeout.timeout(5){ img = [mime, open(fcfg[:link], open_uri_opts).read] unless img }; rescue; img = nil; end
      else
        begin; uri = URI.parse(fcfg[:link]); rescue; end
        %w{ ico png gif }.each do |t|
          # FIXED: enforce timeout because open-uri doesn't respect it here
          begin; Timeout.timeout(5){ img = [ICON_MIMES[t], open("#{uri.scheme}://#{uri.host}/favicon.#{t}", open_uri_opts).read] unless img }; rescue; img = nil; end
        end
      end
    end # thread
    unless thr.join(20)
      thr.kill
      img = nil
    end
    
    if img.is_a?(Array) && img[1].to_s.bytesize > 100
      @log.info "#{fcfg[:name]}: found #{img[0]} favicon"
      "image/#{img[0]};base64,#{Base64.encode64(img[1]).delete("\n")}"
    else
      @log.info "#{fcfg[:name]}: favicon not found, using default"
      "image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABGdBTUEAAK/INwWK6QAAABl0RVh0U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAAJFSURBVBgZBcHda5V1AADg5/d733Oc7tjOaNs5GC6KdrEwmpPRxG7spoKghOim7oK8y0MIEQRL+geGEIQ3UXQvSJ8IafZxUbjQhRDZoU60iYsSc9t5v87b84TsVe3mrBWpHoCICIAIACixYTUfOJM2Z62YO97TOULSIKaEQAyESAzEgISAgLpi48de87MLUqmezhGyhO4SCW7f4O81YiSJiCQIkbqmNcXMIjMXeilIGsQxDp8AnKDY5teL3PyU6h4CdY3Av7cYu58R0QghZWeT9fP0v2V7i8Y4j77As2c5sAwIFAXDgjInJxURAzub/PwxMZBGphZYeIWJWZ44xdo5bl4kK8kzioohUUREd4kXP+Kpd3nkee72+epNBleAxdfoLJBlDEuKkpxoBAkBjXGm53n8ZZ45S/shrr7P75eBo6eo9zAsKCqGRBEB/1zj89e5eo7tLRr7ePJtWg9wZZV7t2i2OPQcw5JiRE4UESN1ZPc2g0tceos/LtPYx9HTaPDNe8Dhl9gtyStyUiMIJDXLp2m0GHzN2gdMzdPq0F3k+pcc/4+x/UwepKzIiSDWTB/iwBLT8xw8xt07rJ8HHj7GbkX/B+DBxyhrciIQ2N2i2AG2fiPL+OsXoNVlWPDnDaC5l6qiJJWjLlHxxRs0JhhcIyvp/8SHJylKdiu++4Tr31NW7B8nkrwzp627d9nkHM0Wsea+GSY6tDvESEyY6TIxyZ4GSUp/nTubqyF7WrvZtaKrZ4QSQ+TIMUSJHCVypGhaHW448z+h1tLAgvKk7gAAAABJRU5ErkJggg=="
    end
  end # download_favicon -------------------------------------------------------

  # read feed items and store them on DB
  #   returns true on success
  def process_feed(fcfg)
    @log.info "#{fcfg[:name]}: starting process"
    
    content = ''
    agent   = ''
    timeout = fcfg[:timeout].to_i > 0 ? fcfg[:timeout].to_i : TIMEOUT
    
    script = File.join(@config[:pwd], 'scrapes', fcfg[:name])
    if File.executable?(script) #&& fcfg[:url].to_s.strip.size == 0
      # --- executing scraping script
      @log.info "#{fcfg[:name]}: scraping website"
      agent = random_agent(:firefox)
      Dir.chdir(File.dirname(script)) do
        begin
          Timeout.timeout(timeout) {
            content = `./#{fcfg[:name].shellescape} #{timeout} #{agent.shellescape} #{fcfg[:url].to_s.shellescape}`
          }#timeout
          
          raise "exit code = #{$?.to_i}" if $?.to_i != 0
        rescue
          @log.error "#{fcfg[:name]}: scrape error (#{$!})"
          return false
        end
      end
    else
      # --- check uri correctness
      begin
        url = URI.parse fcfg[:url]
      rescue
        @log.error "#{fcfg[:name]}: invalid URL (#{$!})"
        return false
      end
      
      # --- download contents
      agent = random_agent(:rss_dler)
      @log.info "#{fcfg[:name]}: downloading as \"rss_dler\""
      begin
        # FIXED: enforce timeout with a thread to bypass Resolv::DNS timeout
        thr = Thread.new do
          content = open(url.to_s, {
            :read_timeout => timeout,
            'Referer'    => "http://#{url.host}",
            'User-Agent' => agent
          }).read
        end # thread
        
        unless thr.join(timeout)
          thr.kill
          raise "timeout #{timeout}s"
        end
      rescue
        msg = $!.to_s.match(/redirection forbidden.*http:.*https:/) ?
          'try changing :url: from HTTP to HTTPS' : $!.to_s
        @log.error "#{fcfg[:name]}: network error (#{msg})"
        return false
      end
      
      # --- gunzip if feed is compressed
      if content.to_s[0..1].force_encoding('UTF-8') == "\x1F\x8B" # GZIP magic bytes
        @log.info "#{fcfg[:name]}: gzipped feed => unzipping"
        begin
          result  = Zlib::GzipReader.new(StringIO.new(content.to_s)).read
          content = result.to_s
        rescue
          @log.error "#{fcfg[:name]}: unable to gunzip feed (#{$!})"
          return false
        end
      end
      
      # patch feed
      begin
        content = content.gsub(/pubdate>/i, 'pubDate>') # patch pubdate
      rescue
        @log.error "#{fcfg[:name]}: unable to patch feed (#{$!})"
        return false
      end
    end
    
    # --- run the eventual conversion script
    script = File.join(@config[:pwd], 'scripts', fcfg[:name])
    if File.executable?(script)
      @log.info "#{fcfg[:name]}: converting content"
      begin
        Dir.chdir(File.dirname(script)) do
          cmd = "./#{fcfg[:name].shellescape} #{timeout} #{agent.shellescape} #{fcfg[:url].to_s.shellescape}"
          Open3.popen2(cmd) do |stdin, stdout, wait_thr|
            stdin.puts content
            stdin.close
            content = stdout.read
          end # open2
        end
      rescue
        @log.error "#{fcfg[:name]}: conversion error (#{$!})"
        return false
      end
    end
    
    # --- applying regexp list
    if fcfg[:regexp].is_a?(Array)
      @log.info "#{fcfg[:name]}: refining content"
      begin
        fcfg[:regexp].each do |pair|
          raise 'invalid regexp pair' unless pair.is_a?(Array) && pair.size == 2
          rex, str = pair
          content = content.to_s.gsub Regexp.new(rex.to_s), str.to_s
        end
      rescue
        @log.warn "#{fcfg[:name]}: regexp error (#{$!})"
      end
    end
    
    if content.to_s !~ /^.*<\?xml.*version/i
      # File.open('output.xml','w'){|f| f.write content}
      @log.error "#{fcfg[:name]}: feed does not contain xml"
      return false
    end
    
    # convert and sanitize to UTF8
    initial_encoding = content.encoding.name
    if initial_encoding.upcase != 'UTF-8'
      content.force_encoding('UTF-8')
      
      unless content.valid_encoding?
        content.
          force_encoding(initial_encoding).
          encode!('UTF-8', :replace => '', :invalid => :replace, :undef => :replace)
      end
      
      @log.debug "#{fcfg[:name]}: encoding #{initial_encoding} => #{content.encoding.name}"
    end
    
    # --- parse feed
    parse_timeout = fcfg[:parse_timeout] || PARSE_TIMEOUT
    begin
      feed = nil
      begin
        raise 'skipping validation' if fcfg[:validation] == false
        @log.info "#{fcfg[:name]}: reading w/ validation"
        Timeout.timeout(PARSE_TIMEOUT){ feed = RSS::Parser.parse(content) }
      rescue
        level = fcfg[:validation] == false ? :info : :warn
        @log.send level, "#{fcfg[:name]}: reading w/o validation"
        Timeout.timeout(PARSE_TIMEOUT){ feed = RSS::Parser.parse(content, false) }
      end
      
      raise 'empty feed' unless feed
    rescue
      @log.error "#{fcfg[:name]}: unsupported feed type!? (#{$!})"
      return false
    end
    
    @log.info "#{fcfg[:name]}: #{feed.class} #{feed.feed_version} / #{feed.items.size} items"
    
    # --- extract data
    begin
      t_now = Time.now
      items = feed.items.sort{|a,b| (b.date || t_now) <=> (a.date || t_now)}
      items = items[0...fcfg[:limit].to_i] if fcfg[:limit].to_i > 0
      
      if feed.is_a?(RSS::Rss) || feed.is_a?(RSS::RDF)
        items.map!{|f|
          item_id = (f.respond_to?(:guid) && f.guid) ? f.guid.content : f.link
          ris = { :id    => item_id        .to_s.strip.encode('UTF-8'),
                  :link  => f.link         .to_s.strip.encode('UTF-8'),
                  :title => f.title        .to_s.strip.encode('UTF-8'),
                  :descr => f.description  .to_s.strip.encode('UTF-8'),
                  :date  => f.date || t_now.to_date.to_time, }
          if f.respond_to?(:content_encoded) &&
             f.content_encoded.to_s.strip.size > 0 &&
             fcfg[:summary]
            ris[:descr] += "<hr/>#{f.content_encoded}".encode('UTF-8')
          end
          ris
        }
      elsif feed.is_a?(RSS::Atom::Feed)
        items.map!{|f|
          item_body = []
          item_body << f.summary.content if f.summary && f.summary.content.to_s.strip.size > 0
          item_body << f.content.content if f.content && f.content.content.to_s.strip.size > 0
          item_body = item_body.join('<hr/>')
          ris = { :id    => f.id.content   .to_s.strip.encode('UTF-8'),
                  :link  => f.link.href    .to_s.strip.encode('UTF-8'),
                  :title => f.title.content.to_s.strip.encode('UTF-8'),
                  :descr => item_body      .to_s.strip.encode('UTF-8'),
                  :date  => f.updated.content, }
          ris
        }
      else
        @log.error "#{fcfg[:name]}: unmanaged feed type"
        return false
      end
    rescue
      @log.error "#{fcfg[:name]}: error parsing items (#{$!})"
      return false
    end
    
    # --- check DB file
    dbfile = File.join(@config[:dbdir], "#{fcfg[:name]}.db")
    unless File.exists?(dbfile)
      @log.error "#{fcfg[:name]}: database not found, restart to create one"
      return false
    end
    
    # --- open database
    begin
      db = SQLite3::Database.new(dbfile)
      db.results_as_hash = true
    rescue
      @log.error "#{fcfg[:name]}: unable to open feed DB (#{$!})"
      return false
    end
    
    # --- save items to db
    begin
      num_already_stored = 0
      hash_keys = (fcfg[:hash_keys] || HASH_KEYS).map(&:to_sym) & AVAILABLE_HASH_KEYS.map(&:to_sym)
      
      db.transaction do |tr|
        items.each do |i|
          begin
            fingerprint = hash_keys.map{|k| k != :date ? i[k] : i[k].strftime('%F %H:%M') }.join('|')
            
            tr.execute "INSERT INTO items (hash_id, link, title, guid, content, pub_date) VALUES (?,?,?,?,?,?)",
              # Digest::SHA512.hexdigest("RSSDLER_SALT|#{i[:id]}|#{i[:link]}|#{i[:title]}|#{i[:date].strftime('%F %H:%M')}"),
              Digest::SHA512.hexdigest("RSSDLER_SALT|#{fingerprint}"),
              i[:link],
              i[:title], # SQLite3::Blob.new(i[:title])
              i[:id],
              SQLite3::Blob.new(i[:descr]), # Zlib::Deflate.deflate(i[:descr], 9)
              i[:date].strftime('%F %T')
          rescue
            @log.debug %Q|#{fcfg[:name]}: already stored "#{i[:title].to_s[0...25]}..."|
            num_already_stored += 1
          end
        end # each item

        fcfg[:unread] = tr.get_first_value("SELECT COUNT(*) AS unread FROM items WHERE read = 0").to_i
        #fcfg[:unread] = fcfg[:unread].to_i + (items.size - num_already_stored)  # update unread count
      end # transaction
      
      @log.info "#{fcfg[:name]}: stored #{items.size - num_already_stored} new items"
    rescue
      begin; db.close; rescue; end
      @log.error "#{fcfg[:name]}: database error (#{$!})"
      return false
    end
    
    # --- purge old elements (time < XXgg)
    begin
      span_time = "#{MAX_ITEM_DAYS} days"
      sql_conds = "pub_date < DATE('now', '-#{span_time}') AND kept = 0 AND read = 1"
      num = db.get_first_value("SELECT COUNT(*) FROM items WHERE #{sql_conds}")
      if num.to_i > MAX_OLD_ITEMS
        num_to_purge = num.to_i - MAX_OLD_ITEMS
        
        @log.info "#{fcfg[:name]}: purging #{num_to_purge} old elements"
        sub_query = "SELECT id FROM items WHERE #{sql_conds} ORDER BY pub_date ASC LIMIT #{num_to_purge}" # LIMIT 1000000 OFFSET #{MAX_OLD_ITEMS}
        db.execute "DELETE FROM items WHERE id IN ( #{sub_query} )"
        db.execute "VACUUM"
        
        fcfg[:unread] = db.get_first_value("SELECT COUNT(*) AS unread FROM items WHERE read = 0").to_i
        #fcfg[:unread] -= num_to_purge
      end
    rescue
      @log.warn "#{fcfg[:name]}: unable to purge old items (#{$!})"
    end
    
    db.close
    
    # save last_update date
    fcfg[:last_update] = Time.now
    begin
      db = SQLite3::Database.new(@config[:feedsdb])
      db.execute 'UPDATE feeds SET last_update = ? WHERE name = ?',
        fcfg[:last_update].strftime('%F %T'),
        fcfg[:name]
      db.close
    rescue
      begin; db.close; rescue; end
      @log.warn "#{fcfg[:name]}: unable to update \"last_update\" date (#{$!})"
    end
    
    @log.instance_variable_get(:@logdev).dev.flush
    
    return true
  end # process_feed -----------------------------------------------------------
end # RSSDler

# STDOUT.sync = true
# RSSDler.new(
#   :log_level => :DEBUG, # DEBUG INFO WARN ERROR FATAL
#   :log_dev   => STDOUT
# ).check_feeds
