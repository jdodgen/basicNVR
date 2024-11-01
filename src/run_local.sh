#!/bin/bash
runuser -l www-data -c "pwd"
runuser -l www-data -c "who"
runuser -l www-data -c "/usr/bin/perl -I /home/jim/Dropbox/source/simplenvr /home/jim/Dropbox/source/simplenvr/simpleNVR.pl"
