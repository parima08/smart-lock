##!/bin/bash -x
# Run from src/server server source root.
usage="-s server_url -u authuser_email -p password -i device_id -f firmware_image_file_path_to_upload -d description -v firmware_version_string -e (for external board) \n\
Requires that cwd be src/server.\n\
You must supply a device_id associated with your email, confirmed. (default 1, per default test data)"
# TBD post-alpha: -h hardware_version_string

server=http://glenn.widener.us/goji
email=glenn.widener@room5.com
password=aba456
# Set in data.rake, first/only device in fresh test dataset:
device_id=1
#file=file.zip
#description=test
#version=thisisaversionstring

if [ -f config/initializers/goji_constants.rb ] 
  then
    STRLIM_GENERAL=`fgrep STRLIM_GENERAL config/initializers/goji_constants.rb|sed -e "s/[^0-9]*\([0-9]*\)./\1/"`
  else
    echo config/initializers/goji_constants.rb not found. Make sure you are running the script from src/server
    exit
fi

external=false
while [ $# -gt 0 ]
do
  if [ "$1" == "-s" ]
  then
    server="$2"
    shift;shift
  elif [ "$1" == "-u" ]
  then
    email="$2"
    shift;shift
  elif [ "$1" == "-p" ]
  then
    password="$2"
    shift;shift
  elif [ "$1" == "-i" ]
  then
    device_id="$2"
    shift;shift
  elif [ "$1" == "-f" ]
  then
    file="$2"
    shift;shift
  elif [ "$1" == "-d" ]
  then
    description="$2"
    shift;shift
  elif [ "$1" == "-v" ]
  then
    temp_v="$2"
    len=${#temp_v}
    if [ "$len" -ge "$STRLIM_GENERAL" ]
    then
      echo The version string may not exceed $STRLIM_GENERAL characters
      exit
    else
      version=$temp_v
    fi
    shift;shift
  elif [ "$1" == "-e" ]
  then
    external=true
    shift
  else
    echo -e Usage: $0 $usage
    exit
  fi
done
external="-F for_external=$external"

if [ "$server" = "" -o "$email" = "" -o "$password" = "" -o "$device_id" = "" -o "$file" = "" -o "$description" = "" -o "$version" = "" ]
then
  echo -e Usage: $0 $usage
  exit
fi

# GET authoken now requires device_type, creates unconfirmed no-ua_token device if no device_id supplied, won't authenticate.
# So must supply the pre-confirmed device from data.rake, or similar confirmed device for the user.
getauth="$server/authtoken?email=$email&password=$password&device_id=$device_id&device_type=iOS"
reply=`curl $getauth`
if echo "$reply"|fgrep authtoken >/dev/null
then
  token=`echo "$reply"|sed -e 's/.*authtoken\":\"\([^\\\"]*\).*/\1/'`
elif echo "$reply"|fgrep device_id  >/dev/null
then
  echo "Your device=$device_id isn't confirmed, please confirm it or choose a device_id that is confirmed for your account"
  exit
fi
if [ -z "$token" ]
then
  echo sorry, invalid user credentials: $reply
  exit
fi

curl -F "authtoken=$token" -F "description=$description" -F "version=$version" -F "file=@$file" $external $server/firmwares
