# RRSS - Ruby RSS feed reader ##################################################
RRSS is a Rss/Rdf/Atom feed reader written in [Ruby](http://www.ruby-lang.org) and using [Sinatra](http://www.sinatrarb.com) and [SQLite](http://www.sqlite.org).

It reads simple configuration files in [YML](http://yaml.org/spec/1.1) format, downloads and stores items in various SQLite databases and sports a nice web GUI to read and manage them (modify, comment, mark, etc...).

RRSS is also able to:

  - download gzipped files
  - use scripts for scraping a web page (placed in ./scrapes)
  - use scripts for manipulating the downloaded file (placed in ./scripts)
  - use regular expressions for manipulating the downloaded file (:regexp: option)
  - export stored items in JSON or ATOM format (with mark status too)
  - run in batch mode without starting the GUI
  - GUI: set custom feed favicon
  - GUI: use a custom skin (CSS)


# 0. Installation ##############################################################

  1. check the ruby version you have with `ruby -v` and make sure it is **>= 1.9** 
  2. obtain a copy of the project from github, you can either:
    
    - download the ZIP: `wget https://github.com/acavalin/rrss/archive/master.zip && cd rrss-master`
    - clone the repository: `git clone https://github.com/acavalin/rrss.git && cd rrss`
    
  3. install the **bundler** gem: `gem install bundler`
  4. now you can install all required gems with `bundle install`
  5. edit **config.yml** as you prefer
  5. create a **feeds.yml** config file (see *feeds.yml.example*)
  6. run the application with `./rrss.rb`
  7. point your browser to http://localhost:3333
  8. ????
  9. profit! ;^)

# 1. Configuration #############################################################

## 1.1 config.yml ##

### 1.1.1 rss_dler options ###
Configuration for the feed downloader and parser:
<table border="1">
  <tr><th>Key</th><th>Descr</th></tr>
  <tr><td>hash_keys    </td><td>Item properties to be hashed for generating its unique id.<br/>
                                Available keys are: :id, :link, :title, :descr, :date       </td></tr>
  <tr><td>max_item_days</td><td>Number of required days for an item to be marked as old     </td></tr>
  <tr><td>max_old_items</td><td>Maximum number of old items to keep                         </td></tr>
  <tr><td>parse_timeout</td><td>Rss parsing timeout (in seconds)                            </td></tr>
  <tr><td>period       </td><td>Feed check default interval time (in seconds)               </td></tr>
  <tr><td>timeout      </td><td>Download/scrape timeout (in seconds)                        </td></tr>
</table>

### 1.1.2 rss_mngr options ###
Configuration for the feed manager (the web GUI):
<table border="1">
  <tr><th>Key</th><th>Descr</th></tr>
  <tr><td>check_interval </td><td>periodic feed check interval time (in minutes)</td></tr>
  <tr><td>exit_grace_time</td><td>feed download grace time on exit (in minutes) </td></tr>
  <tr><td>layout         </td><td>layout css file name                          </td></tr>
  <tr><td>port           </td><td>webserver (GUI) listening port                </td></tr>
</table>

## 1.2 feeds.yml ##
The file represents the feeds tree as an array of key-value options,
here is an example (see also *feeds.yml.example*):

      ---
      # this item is on the root folder
      - :name:    example1
        :link:    http://www.foo.com
        :period:  10
        :enabled: true
        :regexp:  [['HELLO', 'Hello'], ['hi', 'HI']]
      
      - :name:    example2
        :url:     http://bar.org/rss.xml
        :period:  60
        :enabled: true
      
      # an open folder (w/o ':' at the beginning)
      - folder:
        # a collapsed subfolder (w/ ':' at the beginning)
        - :subfolder:
          # these two items are children of "subfolder"
          - :name:    example3A
            :url:     http://www.foo2.com/rss.php
            :period:  720
            :enabled: true
          
          - :name:    example3B
            :url:     http://www.bar2.com/atom.xml
            :period:  720
            :enabled: true
        # these two items are children of "folder"
        - :name:    example4A
          :url:     http://www.fb.org/en/feeds/news.rss
          :period:  1440
          :enabled: true
      
        - :name:    example4B
          :url:     http://www.xyz.net/news.xml
          :period:  1440
          :enabled: true

Every feed has a set of options you can use to customize it:

<table border="1">
  <tr><th>Key</th><th>Descr</th></tr>
  <tr><td>:name:         </td><td>feed feedname ([a-z_])                                            </td></tr>
  <tr><td>:enabled:      </td><td>enable the periodic download for this feed (default false)        </td></tr>
  <tr><td>:hash_keys:    </td><td>array of item properties to be hashed for generating the unique id</td></tr>
  <tr><td>:limit:        </td><td>only consider this quantity of most recent downloaded items       </td></tr>
  <tr><td>:link:         </td><td>clickable link on the feeds tree                                  </td></tr>
  <tr><td>:parse_timeout:</td><td>overrider default parse timeout (in seconds)                      </td></tr>
  <tr><td>:period:       </td><td>periodic download interval (in minutes)                           </td></tr>
  <tr><td>:regexp:       </td><td>array of pairs [regexp, replace_string] to manipulate items       </td></tr>
  <tr><td>:summary:      </td><td>save and show the summary of the item (default true)              </td></tr>
  <tr><td>:timeout:      </td><td>overrider default downaload timeout (in seconds)                  </td></tr>
  <tr><td>:url:          </td><td>url of the xml file to download                                   </td></tr>
  <tr><td>:validation:   </td><td>apply feed validation during parsing (default true)               </td></tr>
</table>

As you can see in the previous example, a folder comes in two flavors:

  - << name **:**       >> renders an expanded folder on the feeds tree
  - << **:** name **:** >> renders a collapsed folder on the feeds tree

### 1.2.1 OPML import/conversion ###############################################
Here is a useful command line combo to perform an easy OPML (indented XML) to YML
conversion:

      cat feedlist.opml | \
        sed 's/<outline title="\(.*\)" text=".*">/- :\L\1:/' | \
        sed 's/\( \+\)<outline text="\([^"]*\)".*htmlUrl="\([^"]*\)" xmlUrl="\([^"]*\)".*\/>/\1- :name:    \L\2\E\n\1  :url:     \4\n\1  :link:    \3\n\1  :enabled: true\n/' | \
        grep -v "<.outline>" > feeds.yml

## 1.3 Feed processing ##
When adding a new feed, keep in mind the retrival/manipulation steps the
application will perform on the downloaded file:

  1. if **./scrapes/feedname** exists and is executable then run it and capture its
     output
  2. otherwise download the file specified in **:url:**
  3. if **./scripts/feedname** exists and is executable then use it to convert the
     previous output (it must read the input from stdin and print output to stdout)
  4. sequentially apply every eventual regexp specified in **:regexp:**
  5. convert contents to UTF-8, parse and store them to **./db/feedname.db**
  6. autopurge old items (only read and unkept ones)

# 2. Feed GUI/Webserver ########################################################

## 2.1 Keyboard shortcuts ######################################################

<table border="1">
  <tr><th>Key </th><th>Function                           </th></tr>
  <tr><td>h   </td><td>show help                          </td></tr>
  <tr><td>n   </td><td>select next unread item            </td></tr>
  <tr><td>down</td><td>select next item                   </td></tr>
  <tr><td>m/up</td><td>select previous item               </td></tr>
  <tr><td>home</td><td>select first item                  </td></tr>
  <tr><td>end </td><td>select last item                   </td></tr>
  <tr><td>u   </td><td>toggle unread on selected item     </td></tr>
  <tr><td>k   </td><td>toggle kept on selected item       </td></tr>
  <tr><td>esc </td><td>close/reset view                   </td></tr>
  <tr><td>v   </td><td>change view filter                 </td></tr>
  <tr><td>l   </td><td>show linear view in list mode      </td></tr>
  <tr><td>L   </td><td>show linear view in thumbs mode    </td></tr>
  <tr><td>r   </td><td>refresh feeds tree                 </td></tr>
  <tr><td>R   </td><td>mark all feed items as read        </td></tr>
  <tr><td>s   </td><td>search items in current feed/folder</td></tr>
</table>

## 2.2 Feed items export #######################################################
You can download all desired feed items by using the following urls:

  - http://ip_address:port/dump/feed_name.xml    *(atom feed)*
  - http://ip_address:port/dump/feed_name.json   *(json object)*
  
**Note**: Feed/item preferences are included in the XML/Atom file within *dc_type*
tags.

## 2.3 Change feed favicon #####################################################
To set a custom favicon for a specific feed use the script *set_favicon.rb*:

    set_favicon.rb feed_name favicon_uri

where **feed_name** is the name specified in **:name:** and the **favicon_uri**
can be either an URL or a local file PATH.

# 3. Feed downloader ###########################################################

## 3.1 Batch mode/dump #########################################################
You can run the download process of your feeds in batch mode using the script
**check_feeds.rb**:

    check_feeds.rb [dump_dir [format]]

if you supply a dump directory then the processed feed will be dumped on that
place.
The format can be either *xml* or *json*.

# 4. Referrer/External resources ###############################################
Webservers tend to block a *localhost* referrer for feeds that rely on external
resources like images :'(

If you use Firefox, you can bypass this problem by installing the
[Referrer Control](https://addons.mozilla.org/firefox/addon/referrer-control/)
extension; you can find the full documentation on its
[wiki page](https://github.com/muzuiget/referrer_control/wiki)
 
You just need to add a custom rule:

    *localhost*, <any>, <remove>

and remember to set the default rule to **Skip** if you wish to preserve the
browser default behaviour.

# A. Reference documentation ###################################################
Here is a list of the specs, libraries and tools used to develop RRSS:

  * RSS
    - http://ruby-doc.com/stdlib-1.9.2/libdoc/rss/rdoc/RSS.html
    - http://www.cozmixng.org/~rwiki/?cmd=view;name=RSS+Parser%3A%3ATutorial.en
    - http://en.wikipedia.org/wiki/RSS
  * Ruby libs
    - http://ruby-doc.org/stdlib-1.9.3/libdoc/timeout/rdoc/Timeout.html
    - http://ruby-doc.org/stdlib-1.9.3/libdoc/open-uri/rdoc/OpenURI.html
    - http://ruby-doc.org/stdlib-1.9.3/libdoc/digest/rdoc/Digest.html
    - http://ruby-doc.org/stdlib-1.9.3/libdoc/fileutils/rdoc/FileUtils.html
    - http://ruby-doc.org/stdlib-1.9.3/libdoc/open3/rdoc/Open3.html
    - http://ruby-doc.com/stdlib-1.9.2/libdoc/zlib/rdoc/Zlib.html
    - http://ruby-doc.org/stdlib-1.9.3/libdoc/base64/rdoc/Base64.html
    - http://ruby-doc.org/stdlib-1.9.3/libdoc/stringio/rdoc/StringIO.html
    - http://ruby-doc.org/stdlib-1.9.3/libdoc/logger/rdoc/Logger.html
    - http://www.ruby-doc.org/stdlib-1.9.3/libdoc/json/rdoc/JSON.html
  * Sinatra
    - http://www.sinatrarb.com/configuration.html
    - http://www.sinatrarb.com/extensions.html
    - http://www.sinatrarb.com/contrib/reloader
  * SQLite
    - http://sqlite-ruby.rubyforge.org/sqlite3/faq.html
    - http://www.sqlite.org/lang.html
    - http://www.sqlite.org/pragma.html#syntax
    - http://www.sqlite.org/datatype3.html
  * YAML
    - http://yaml.org/spec/1.1/
  * Firefox referrer control
    - https://github.com/muzuiget/referrer_control/wiki
