#!/bin/bash

source ../lib/functions.sh

WGET -O - "$BASEURL" | sanitizeXml
