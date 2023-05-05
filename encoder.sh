#! /bin/bash

# The purpose of this is to sit on an RPi and churn through .mkv files and convert them
# all to H264 files.
# It *should* work fine with the Plex Movie structure of "Title (year)/Title (year).mkv"
# or "Title (year)/Title (year) - suffix.mkv". It will not work with anything outside of 
# the main content (I don't want it to) but it won't work with anything not of the above
# structure. It will not transcode -pt1 and pt2 files (not sure it should)

# Mount directories for Mac and RPi
if [[ $(uname -s) == "Darwin" ]]
then
  moviesDir="/Volumes/Public/Shared Videos/Movies"
  tvDir="/Volumes/Public/Shared Videos/TV Shows"
else
  moviesDir="/mnt/Shared Videos/Movies"
  tvDir="/mnt/Shared Videos/TV Shows"
fi

# Common locations
complete="$HOME/Documents/complete.txt"
log="$HOME/Documents/transcode.log"
HandBrakeCLI=/usr/local/bin/HandBrakeCLI

# Create empty arrays for later use
declare -a assetList
declare -a transcodeList

# Basic usage function
function usage {
  echo "Usage: $(basename $0)"
  echo -e "\t[-m default movie directoy]" 
#  echo -e "\t[-t default tv directory]"
  echo -e "\t[-d <other directory>]"
  echo -e "\t[-c <complete log file>]"
  echo -e "\t[-l <transcode log file>]"
#  echo -e "\t[-f <defined file to transcode>]"
#  echo -e "\t[-o force overwrite]"
#  echo ""
#  echo -e "The file to be transcoded should just be given the directory name i.e.: \n\t\"Total Recall (1990).mkv\""
#  echo ""
#  echo "It is assumed that the source file is a .mkv"
}

# usual metopts stuff
# m (movies), t (tv) and o (overwite) don't need arguments so no following :
while getopts ":mtd:c:l:f:o" options
do
  case $options in
    m)
      movie="$moviesDir" >&2
      ;;
    t)
       tv="$tvDir" >&2
       ;;
    d)
      userDir=$OPTARG >&2
      ;;
    c)
      echo -e "Using a complete file location of: $OPTARG\n" >&2
      complete=$OPTARG
      ;;
    l)
      echo -e "Using a log file location of: $OPTARG\n" >&2
      log=$OPTARG
      ;;
    f)
      echo -e "Using a file of: $OPTARG\n" >&2
      file=$OPTARG
      ;;
    o)
      echo "Overwriting existing H264 file (if present)" >&2
      overwrite=1
      ;;
    *)
      echo "invalid command: no parameter included with argument $OPTARG"
      ;;
  esac
done

if [[ $OPTIND -eq 1 ]]
then
  usage
fi

# Find .mkv assets and put them into the assetList array
function getAssets {
  directory="$1"
  echo "$(date +"%Y-%m-%d %H:%M%:%S") Scanning $directory" >> $log
  while IFS= read -r list
  do
    assetList+=("$list")
  done < <(find "$directory" -name "*.mkv" -and ! -name "*pt?.mkv")
  echo "$(date +"%Y-%m-%d %H:%M%:%S") Finished scan - asset list created" >> $log
}

# Generate asset components from full file path
function getAssetComponents {
  givenAsset=$1
  path=$(echo $givenAsset | rev | cut -d/ -f2- | rev)
  sourceFile=$(echo $givenAsset | rev | cut -d/ -f1 | rev)
  destinationFile=$(echo $sourceFile | sed -e"s/.mkv/ - H264.mp4/")
  assetFolder=$(echo $path | rev | cut -d/ -f1 | rev)
  shortFile="$(echo $givenAsset | rev | cut -d/ -f1 | cut -d\) -f2- | rev))"
  echo "$path","$sourceFile","$destinationFile","$assetFolder","$shortFile"
}

# If we don't have an existing H264 file we're good to transcode so add the files
# to the transcode array
function checkAssets {
  echo "$(date +"%Y-%m-%d %H:%M%:%S") Looking for previously completed assets" >> $log
  for asset in "${assetList[@]}"
  do
    details=$(getAssetComponents "$asset")
    path=$(echo "$details" | cut -d, -f1)
    sourceFile=$(echo "$details" | cut -d, -f2)
    destinationFile=$(echo "$details" | cut -d, -f3)
    assetFolder=$(echo "$details" | cut -d, -f4)
    shortFile=$(echo "$details" | cut -d, -f5)
    if [[ "$assetFolder" == "$shortFile" ]] && [[ ! -f "$path"/"$destinationFile" ]]
    then
      transcodeList+=("$asset")
    fi
  done
  echo "$(date +"%Y-%m-%d %H:%M%:%S") Finished scan - transcode list created" >> $log
}

# There's no point transcoding if we don't have enough space
function checkFreeSpace {
  path="$1"
  echo "$path"
  percentage=$(df -kh "$path" | grep '//' | awk '{print $5}' | tr -d '%')
  echo $percentage
}

# Now we have a transcode list we can start working through it
function transodeAssets {
  echo "$(date +"%Y-%m-%d %H:%M%:%S") Processing transcode list" >> $log
  directory=$1
  for asset in "${transcodeList[@]}"
  do
    details=$(getAssetComponents "$asset")
    path=$(echo "$details" | cut -d, -f1)
    sourceFile=$(echo "$details" | cut -d, -f2)
    destinationFile=$(echo "$details" | cut -d, -f3)
    freeSpace=$(checkFreeSpace "$directory")
    # Don't know why but the checkFreeSpace works fine on its own but returns the directory when called like this
    # So we have to remove the directory. Use rev to cope with spaces
    freeSpacePercent=$(echo $freeSpace | rev | awk '{print $1}' | rev)

    # If we have the free space and if the file doesn't exist in the complete file then we can transcode it
    if [[ $freeSpacePercent -le 95 ]] 
    then
      echo "$(date +"%Y-%m-%d %H:%M:%S") Starting transcode of $sourceFile" >> $log
      HandBrakeCLI -i "$path"/"$sourceFile" -o "$path"/"$destinationFile" --preset-import-file "Modified H264"
      if [[ $? == 0 ]]
      then
        echo "$sourceFile" >> $complete
        echo "$(date +"%Y-%m-%d %H:%M:%S") Transcode of $sourceFile successful" >> $log
      else
        echo "$(date +"%Y-%m-%d %H:%M:%S") Transcode of $sourceFile failed" >> $log
      fi
    else
      echo "Not enough disk space left - exiting"
      echo "$(date +"%Y-%m-%d %H:%M:%S") Insufficient disk space" >> $log
      exit
    fi
  done
  echo "$(date +"%Y-%m-%d %H:%M%:%S") Transcode list complete" >> $log
}

# Iterate through the potential directories and process the assets
for directory in "$movie" "$tv" "$userDir"
do
  if [[ ! -z $directory ]]
  then
    getAssets "$directory"
    checkAssets
    transodeAssets "$directory"
  fi
done
