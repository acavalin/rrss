#!/bin/bash

TIMEOUT=$1
AGENT=$2
BASEURL=$3
TMPDIR="/tmp/rrss_scrapes"
scrapeFile="$TMPDIR/`basename "$0"`.webScrape"
export TIMEOUT AGENT BASEURL TMPDIR scrapeFile

if [ -z "$TIMEOUT" -o -z "$AGENT" ]; then
  echo "USAGE: `basename "$0"` TIMEOUT AGENT [URL]"
  exit -1
fi

# temp directory
mkdir -p $TMPDIR

function WGET () { wget -T $TIMEOUT -U "$AGENT" -q "$@"; }

# convert a date (YYYY-MM-DD) into the pubDate format: <pubDate>Fri, 09 Feb 2007 19:49:42 +0100</pubDate>
pdfmt="+%a, %d %b %Y %H:%M:%S %z"
function getDate () { date -d "$1" "$pdfmt"; }
function curDate () { date "$pdfmt"; }

# remove/substitute all non-printable ASCII characters
function stripNonAscii   () { tr -d '\r' | tr -cd '\11\12\40-\176'; }
function replaceNonAscii () { tr -d '\r' | tr -c '\11\12\40-\176' "$1"; }

function convertToUtf8 () {
  from=$1
  [ -z "$from" ] && from="ISO-8859-1"
  iconv --from-code="$from" --to-code=UTF-8 | sed 's/encoding=".*"/encoding="utf-8"/'
} # convertToUtf8

function sanitizeHtml () { tidy      -w 30000 -q 2> /dev/null; }
function sanitizeXml  () { tidy -xml -w 30000 -q 2> /dev/null; }

function getHostUrl () { echo "$1" | sed 's/^\(http:..[^\/]\+\).*/\1/'; }

# scrape the page and test the output
#  $1 = Feed Title
#  $2 = Home page link
function printScrape () {
  rss_title="$1"
  rss_url="$2"
  
  # scrape the input
  scrapeIt > "$scrapeFile"

  # get output info
  head=`cat    "$scrapeFile" | head -n1 | sed 's/ *\([^ ]\{6\}\).*/\1/'`
  lines=`wc -l "$scrapeFile" | cut -f 1 -d " "`
  
  # print header
  cat <<XML
<?xml version="1.0" encoding="ISO-8859-1"?>
<rss version="2.0">
  <channel>
    <link>$rss_url</link>
    <title>$rss_title</title>
    <description>$rss_title</description>
XML
  
  
  # test the output
  if [ "$head" != "<item>" ]; then
    ERR=""
    if [ "$lines" = "0" ]; then
      ERR="NULL OUTPUT"
    else
      ERR="PARSING ERRROR"
    fi
      cat <<XML
    <item>
      <title>$ERR EXCEPTION!!</title>
      <link>http://www.google.com</link>
      <guid isPermaLink="false">SCRAPE_ERR-`date +"%Y-%m-%d"`</guid>
      <description><![CDATA[<table border="0" cellpadding="8"><tr>
        <td><img border="0" src="/images/bomb.png" /></td>
        <td>
          <h2 style="color: red;"><u>WARNING</u>: $ERR!!</h2>
          The script generated a $ERR!!<br>
          Maybe the site has changed.
        </td>
      </tr></table>]]></description>
    </item>
XML
  else
    cat "$scrapeFile"
  fi
  
  # print footer
  cat <<XML
  </channel>
</rss>
XML

  # delete temp file
  rm -f "$scrapeFile"
} # printScrape
