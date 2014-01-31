#!/usr/bin/env ruby
# encoding: utf-8

# --- HOWTOs -------------------------------------------------------------------
=begin
Referrer Control:
  https://addons.mozilla.org/firefox/addon/referrer-control/
  https://github.com/muzuiget/referrer_control/wiki
=end

require_relative 'version'
require_relative 'utils'
require_relative 'rss_dler'

require 'sqlite3'       # http://sqlite-ruby.rubyforge.org/sqlite3/faq.html
require 'json'          # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/json/rdoc/JSON.html
require 'sinatra/base'  # http://www.sinatrarb.com/documentation.html
                        # http://www.sinatrarb.com/configuration.html
                        # http://www.sinatrarb.com/extensions.html

# require 'debugger'
# require 'sinatra/reloader'  # http://www.sinatrarb.com/contrib/reloader

class RSSMngr < Sinatra::Base
  use Rack::Deflater # enable gzip compression
  
  include Utils
  
  # ============================================================================
  # config
  # ============================================================================
  # default settings
  set :port            => 3333,
      :run             => false,
      :root            => File.expand_path(File.join(File.dirname(__FILE__), '..')),
      :static          => true,
      :show_exceptions => true,
      :dump_errors     => true
  # custom settings (define these before calling run!)
  # set :environment, :production
  # set :rssdler,     nil


  # ============================================================================
  # extensions
  # ============================================================================
  register Sinatra::Reloader if $LOADED_FEATURES.detect{|i| i =~ /gem.*sinatra\/reloader/ }
  
  # helpers RSSMngrHelpers # we can use a module too
  helpers do
    def spinner(type = 'normal', options = {})
      html = %Q|<img src="/images/spinner-#{type}.gif" title="loading..." />|
      html = %Q|<p class="acenter">#{html}</p>| if options[:center]
      html
    end # spinner ----------------------------------------------------------------
    
    def h(text)
      Rack::Utils.escape_html(text)
    end # h ----------------------------------------------------------------------
    
    def titleize(str)
      str.to_s.tr('_', ' ').split(' ').map{|i| i.capitalize}.join(' ')
    end # titleize ---------------------------------------------------------------
    
    def get_fcfg(name)
      settings.rssdler.feeds.detect{|f| f[:name] == name.to_s}
    end # get_fcfg ---------------------------------------------------------------
  end
  
  class << self
    alias_method :'orig_run!', :'run!'

    # checking if rssdler is defined
    def run!(options = {})
      if self.methods.include?(:rssdler)
        # load configuration
        cfg_file = File.join self.settings.rssdler.config[:pwd], 'config.yml'
        YAML::load_file(cfg_file)[:rss_mngr].each{|k, v| self.set k.to_sym, v }
        
        orig_run!(options)
      else
        puts "missing rssdler! set one using:"
        puts "  RSSMngr.set :rssdler, RSSDler.new(:load_gui_details => true)"
      end
    end
  end
  
  
  # ============================================================================
  # = routes
  # ============================================================================
  get '/' do
    erb :index
  end # ------------------------------------------------------------------------
  
  get '/feeds' do
    @feeds = build_feed_tree(settings.rssdler.config[:feeds])
    
    erb :feeds
  end # ------------------------------------------------------------------------
  
  get '/items' do
    @favicons_css = params[:feeds].map{|name|
      if feed = get_fcfg(name)
        %Q|div[data-feed="#{name}"] span.fav { background-image: url('data:#{feed[:favicon]}'); }|
      end
    }.compact
    @favicons_css = %Q|<style type="text/css">#{@favicons_css.join "\n"}</style>|
    
    fields = params[:linear] ? %w{ * } : %w{ id read kept modified title pub_date }
    @items = fetch_items(params[:feeds], fields, params[:filter].to_i, params[:search].to_s)
    
    if params[:linear]
      @items.map{|item|
        @item    = item
        classes  = %w{ linear_item }
        classes << 'kept'   if item['kept'] == 1
        classes << 'unread' if item['read'] == 0
        %Q|<div class="#{classes.join ' '}">#{erb(:item)}</div>|
      }.unshift(@favicons_css).join
    else
      erb :items
    end
  end # ------------------------------------------------------------------------
  
  get '/item' do
    if feed = get_fcfg(params[:feed].to_s)
      @favicons_css = %Q|#item div[data-feed="#{feed[:name]}"] span.fav { background-image: url('data:#{feed[:favicon]}'); }|
      @favicons_css = %Q|<style type="text/css">#{@favicons_css}</style>|
    end
    # name, comment, content, guid, id, kept, link, modified, pub_date, read, title
    @item = fetch_item(params[:feed].to_s, params[:id].to_s)
    
    @favicons_css + erb(:item)
  end # ------------------------------------------------------------------------
  
  get '/purge_feed' do
    content_type :json
    feed = get_fcfg(params[:feed].to_s)
    ris = purge_feed_items(params[:feed].to_s)
    { :ris => (ris ? 'ok' : 'err'), :unread => feed[:unread] }.to_json
  end # ------------------------------------------------------------------------
  
  get '/toggle_keep' do
    content_type :json
    ris = toggle_keep(params[:feed].to_s, params[:id].to_s, params[:keep] == 'true')
    { :ris => (ris ? 'ok' : 'err') }.to_json
  end # ------------------------------------------------------------------------
  
  get '/toggle_read' do
    content_type :json
    ris = toggle_read(params[:feed].to_s, params[:id].to_s, params[:read] == 'true')
    { :ris => (ris ? 'ok' : 'err') }.to_json
  end # ------------------------------------------------------------------------
  
  get '/mark_all_read' do
    ris = mark_all_read(params[:feeds])
    { :ris => (ris ? 'ok' : 'err') }.to_json
  end # ------------------------------------------------------------------------
  
  post '/comment' do
    ris = set_comment(params[:feed], params[:id], params[:cmt])
    { :ris => (ris ? 'ok' : 'err') }.to_json
  end # ------------------------------------------------------------------------
  
  post '/update_item' do
    ris = update_text(params[:feed], params[:id], params[:text])
    { :ris => (ris ? 'ok' : 'err') }.to_json
  end # ------------------------------------------------------------------------
  
  get '/dump/:feed.?:format?' do
    params[:feed].tr!(' ', '_')
    return 'not found' unless fcfg = get_fcfg(params[:feed])
    
    settings.rssdler.dump params[:feed], params[:format]
  end # ------------------------------------------------------------------------
  
  get '/logs' do
    @lines = settings.rssdler.log_buffer.split("\n").map{|l|
      %Q|<div class="type_#{l[0]}">#{h l}</div>|
    }.reverse
    
    erb :logs
  end # ------------------------------------------------------------------------
  
  get '/logs/purge' do
    settings.rssdler.purge_log_buffer
  end # ------------------------------------------------------------------------
  
  
  private # ____________________________________________________________________
  
  
  # metodo ricorsivo per popolare l'array dei feeds
  def build_feed_tree(section, depth = 0)
    list = []
    
    if section.is_a?(Array)
      list += section.map{|s| build_feed_tree s, depth}.flatten # array of feeds
    elsif section.is_a?(Hash)
      if section.has_key?(:name)
        section[:depth] = depth
        list << section
      else
        k = section.keys.first
        list << {:depth => depth, :folder => k, :closed => k.is_a?(Symbol)}
        list += build_feed_tree(section.values[0], depth + 1).flatten # scan subdir
      end
    end
    
    list
  end # build_feed_tree --------------------------------------------------------

  def fetch_items(names, columns = %w{*}, filter_idx = 0, search_term = '')
    names = [names] if names.is_a?(String)
    query_args  = []
    query_where = []
    
    filters = [
      'read = 0 OR kept = 1', # 0 - unread + kept
      'read = 0',             # 1 - unread
      'kept = 1',             # 2 - kept
      '1 = 1',                # 3 - all
    ]
    if (filter_idx < (filters.size - 1))
      query_where << filters[filter_idx]
    end
    
    search_term = search_term.to_s.strip.downcase
    if search_term.size >= 3
      query_where << "( LOWER(content) LIKE ? OR LOWER(title) LIKE ? )"
      search_term = "%#{search_term}%"
      query_args  += [search_term, search_term]
    end
    
    where_clause = "WHERE #{query_where.join ' AND '}" if query_where.size > 0
    
    list = []
    
    names.each do |name|
      begin
        db = SQLite3::Database.new File.join(settings.rssdler.config[:dbdir], "#{name}.db")
        db.results_as_hash = true
        
        list += db.execute(
          "SELECT #{columns.join ','} FROM items #{where_clause} ORDER BY pub_date DESC",
          *query_args
        ).map{|i|
          i['name'] = name
          i.delete_if{|k,v| k.is_a? Fixnum}
          i
        }
        db.close
      rescue Exception => e
        begin; db.close; rescue; end
        list << err_item(name, e)
      end
    end
    
    list.sort{|a,b| b['pub_date'] <=> a['pub_date']}
  end # fetch_items ------------------------------------------------------------
  
  # recupera un item e lo imposta come letto
  def fetch_item(name, id)
    begin
      db = SQLite3::Database.new File.join(settings.rssdler.config[:dbdir], "#{name}.db")
      db.results_as_hash = true
      
      item = db.get_first_row("SELECT * FROM items WHERE id = ?", id.to_i)
      item ||= err_item(name, 'NOT FOUND')
      item.delete_if{|k,v| k.is_a? Fixnum}
      item['name'] = name
      
      # update read status for this item
      if item['read'].to_i == 0
        item['read'] = 1
        db.execute 'UPDATE items SET read = 1 WHERE id = ?', id.to_i
        # updare unread count
        if feed = settings.rssdler.feeds.detect{|f| f[:name] == name}
          feed[:unread] = db.get_first_value("SELECT COUNT(*) AS unread FROM items WHERE read = 0").to_i
        end
      end
      
      db.close
    rescue Exception => e
      begin; db.close; rescue; end
      item = err_item(name, e)
    end
    
    item
  end # fetch_item -------------------------------------------------------------
  
  def purge_feed_items(name)
    begin
      db = SQLite3::Database.new File.join(settings.rssdler.config[:dbdir], "#{name}.db")
      
      db.execute("DELETE FROM items WHERE kept = 0")
      
      # updare unread count
      if feed = settings.rssdler.feeds.detect{|f| f[:name] == name}
        feed[:unread] = db.get_first_value("SELECT COUNT(*) AS unread FROM items WHERE read = 0").to_i
      end
      
      db.close
      true
    rescue
      begin; db.close; rescue; end
      false
    end
  end # purge_feed_items -------------------------------------------------------
  
  def toggle_keep(name, id, keep)
    begin
      db = SQLite3::Database.new File.join(settings.rssdler.config[:dbdir], "#{name}.db")
      db.execute 'UPDATE items SET kept = ? WHERE id = ?', (keep ? 1 : 0), id.to_i
      db.close
      true
    rescue
      begin; db.close; rescue; end
      false
    end
  end # toggle_keep ------------------------------------------------------------
  
  def toggle_read(name, id, read)
    begin
      db = SQLite3::Database.new File.join(settings.rssdler.config[:dbdir], "#{name}.db")
      db.execute 'UPDATE items SET read = ? WHERE id = ?', (read ? 1 : 0), id.to_i
      # updare unread count
      if feed = settings.rssdler.feeds.detect{|f| f[:name] == name}
        feed[:unread] += read ? -1 : 1
      end
      db.close
      true
    rescue
      begin; db.close; rescue; end
      false
    end
  end # toggle_read ------------------------------------------------------------
  
  def mark_all_read(names)
    names = [names] if names.is_a?(String)
    
    names.all?{|name|
      begin
        db = SQLite3::Database.new File.join(settings.rssdler.config[:dbdir], "#{name}.db")
        db.execute 'UPDATE items SET read = 1'
        # updare unread count
        if feed = settings.rssdler.feeds.detect{|f| f[:name] == name}
          feed[:unread] = 0
        end
        db.close
        true
      rescue
        begin; db.close; rescue; end
        false
      end
    }
  end # mark_all_read ----------------------------------------------------------
  
  def set_comment(name, id, cmt)
    begin
      db = SQLite3::Database.new File.join(settings.rssdler.config[:dbdir], "#{name}.db")
      db.execute 'UPDATE items SET comment = ? WHERE id = ?', cmt.to_s[0..1023], id.to_i
      db.close
      true
    rescue
      begin; db.close; rescue; end
      false
    end
  end # set_comment ------------------------------------------------------------
  
  def update_text(name, id, text)
    begin
      db = SQLite3::Database.new File.join(settings.rssdler.config[:dbdir], "#{name}.db")
      db.execute 'UPDATE items SET modified = 1, content = ? WHERE id = ?', SQLite3::Blob.new(text), id.to_i
      db.close
      true
    rescue
      begin; db.close; rescue; end
      false
    end
  end # update_text ------------------------------------------------------------
end # RSSMngr

# RSSMngr.set :rssdler, RSSDler.new({
#   :gui_details => true,
#   :debug       => true,
# })
# RSSMngr.run!
