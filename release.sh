#!/bin/bash

LIBS=`curl -s "https://api.github.com/users/qlibs/repos" | grep "\"full_name\":" | grep -v github | grep -v "/qlibs" | cut -d '/' -f2 | cut -d \" -f1 | xargs`

rm -f README.md
rm -rf qlibs
mkdir qlibs

for lib in $LIBS; do
  wget -q -P qlibs https://raw.githubusercontent.com/qlibs/$lib/main/$lib
done

echo "## QLlibs++ - Modern C++ libraries" > README.md
echo >> README.md
echo "---" >> README.md
echo >> README.md
echo "### Libraries" >> README.md

for lib in $LIBS; do
  echo "- [$lib](#$lib)" >> README.md
done

echo >> README.md
echo "---" >> README.md
echo >> README.md

for lib in $LIBS; do
  sed -n '/^#if 0/,/^#endif/p' qlibs/$lib | head -n -2 | tail -n +3 >> README.md
  echo "---" >> README.md
done
