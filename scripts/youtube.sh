#!/bin/bash

source ../lib/functions.sh

sanitizeXml | perl -pe 's|((.*&lt;td){3}) .+width="146".+?/td&gt;|\1&gt;&nbsp;&lt;/td&gt;|'
