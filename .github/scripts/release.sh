#!/bin/bash

LIBS=$(curl -s "https://api.github.com/users/qlibs/repos" | grep "\"full_name\":" | grep -v github | grep -v "/qlibs" | cut -d '/' -f2 | cut -d \" -f1 | xargs)

rm -rf qlibs
mkdir qlibs

for lib in $LIBS; do
  release=$(curl -s "https://api.github.com/repos/qlibs/$lib/releases/latest" | jq -r .tag_name)
  description=$(curl -s "https://api.github.com/repos/qlibs/$lib" | jq -r .description)

  if [ "$release" != "" ]; then
    wget -q -P qlibs https://raw.githubusercontent.com/qlibs/$lib/$release/$lib
    echo "> $description - [$lib](https://github.com/qlibs/$lib) ([$release](https://github.com/qlibs/$lib/releases/tag/$release))"
  fi
done
