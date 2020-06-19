#!/bin/bash

reponame=$(readlink -f "$0")
repopath=$(dirname "$reponame")
gmodpath=$(dirname "$repopath")
gmodpath=$(dirname "$gmodpath")

[ ! -d "$gmodpath/lua" ] && mkdir -p "$gmodpath/lua"
[ ! -d "$gmodpath/lua/bin" ] && mkdir -p "$gmodpath/lua/bin"

cp -rfpv $repopath/addons/. $gmodpath/addons
cp -rfpv $repopath/lua/bin/. $gmodpath/lua/bin
