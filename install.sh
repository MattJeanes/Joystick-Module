#!/bin/bash

repopath=$(readlink -f "$0")
repopath=$(dirname "$repopath")
gmodpath=$(dirname "$repopath")
gmodpath=$(dirname "$gmodpath")

[ ! -d "$gmodpath/lua" ] && mkdir -p "$gmodpath/lua"
[ ! -d "$gmodpath/lua/bin" ] && mkdir -p "$gmodpath/lua/bin"

cp -rfp $repopath/addons/. $gmodpath/addons
cp -rfp $repopath/lua/bin/. $gmodpath/lua/bin

echo "Joystick module has been installed !"
echo "Please remove the clonned repo manually !"
