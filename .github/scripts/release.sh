#!/bin/bash

LIBS=$(curl -s "https://api.github.com/users/qlibs/repos" | grep "\"full_name\":" | grep -v github | grep -v "/qlibs" | cut -d '/' -f2 | cut -d \" -f1 | xargs)

rm -rf qlibs
mkdir qlibs

for lib in $LIBS; do
  release=$(curl -s "https://api.github.com/repos/qlibs/$lib/releases/latest" | grep "\"tag_name\":" | cut -d \" -f4)

  if [ "$release" != "" ]; then
    wget -q -P qlibs https://raw.githubusercontent.com/qlibs/$lib/$release/$lib
  fi

done
