#!/bin/sh
#
# Capture firmware records from specified server to seeds.rb.
# 
usage="$0 heroku_server_configuration_name"
if [ $# = 0 ]
then
  echo Usage: $usage
  exit
fi

#export source="`heroku config:get DATABASE_URL -a $1`"
rake capture:remote_firmware source="`heroku config:get DATABASE_URL -a $1`"


