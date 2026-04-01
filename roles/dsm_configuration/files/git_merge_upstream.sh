#!/usr/bin/env bash

UPSTREAM=$1
UPSTREAM_TEST=`git remote -v| grep upstream | grep fetch |awk '{print $2}'`

if [ $UPSTREAM_TEST  != $UPSTREAM ]; then
	  echo "REMOTE NOT SET: $UPSTREAM"
	    git remote add upstream $UPSTREAM
    else
	      echo "REMOTE IS ALREADY SET!"
fi

git remote -v
git fetch upstream
git checkout master
git merge upstream/master
git push origin master
