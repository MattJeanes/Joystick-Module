#!/bin/bash

repopath=$(readlink -f "$0")
repopath=$(dirname "$repopath")
gmodpath=$(dirname "$repopath")
gmodpath=$(dirname "$gmodpath")
boolrvar=""

[ ! -d "$gmodpath/lua" ] && mkdir -p "$gmodpath/lua"
[ ! -d "$gmodpath/lua/bin" ] && mkdir -p "$gmodpath/lua/bin"

cp -rfp $repopath/addons/. $gmodpath/addons
cp -rfp $repopath/lua/bin/. $gmodpath/lua/bin

echo "Joystick module has been installed !"

read -p "Remove the cloned repository [y/N] ? " boolrvar

if test "$boolrvar" == "y"
then
  rm -rf "$repopath"
else
  if test "$boolrvar" == "Y"
  then
    rm -rf "$repopath"
  else
    echo "Please remove the clonned repo manually !"
  fi
fi

exit 0
