#!/bin/bash

sed 's/\[img\]\(.*\)\[\/img\]/<br \/><img src="\1" \/><br \/>/ig' | \
  sed 's/\\u....//g' | \
  sed 's/www\.\(jpseek.com\)/\1/g'
