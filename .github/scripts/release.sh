#!/bin/bash

LIBS=`curl -s "https://api.github.com/users/qlibs/repos" | grep "\"full_name\":" | grep -v github | grep -v "/qlibs" | cut -d '/' -f2 | cut -d \" -f1 | xargs`

rm -rf qlibs
mkdir qlibs

for lib in $LIBS; do
  wget -q -P qlibs https://raw.githubusercontent.com/qlibs/$lib/main/$lib
done
