#! /bin/bash

if [[ $(uname -s) == "Darwin" ]]
then
  moviesDir="/Volumes/Public/Shared Videos/Movies"
  tvDir="/Volumes/Public/Shared Videos/TV Shows"
  complete="$HOME/Documents/complete.txt"
  log="$HOME/Documents/transcode.log"
  HandBrakeCLI=/usr/local/bin/HandBrakeCLI
else
  moviesDir="/mnt/Shared Videos/Movies"
  tvDir="/mnt/Shared Videos/TV Shows"
  complete="$HOME/Documents/complete.txt"
  log="$HOME/Documents/transcode.log"
  HandBrakeCLI=/usr/local/bin/HandBrakeCLI
fi

declare -a assetList
declare -a transcodeList

function usage {
  echo "Usage: $(basename $0) [-m default movie directoy] [-t default tv directory]"
  echo -e "\t[-d <other directory>] [-c <complete log file>] [-l <transcode log file>]"
  echo -e "\t[-f <defined file to transcode>] [-o force overwrite]"
  echo ""
  echo -e "The file to be transcoded should just be given the directory name i.e.: \n\t\"Total Recall (1990).mkv\""
  echo ""
  echo "It is assumed that the source file is a .mkv"
}

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

function generateAssetList {
  while IFS= read -r list
  do
    assetList+=("$list")
  done < <(find "$1" -name "*.mkv")
}

function getAssets {
  directory="$1"
  echo "$(date +"%Y-%m-%d %H:%M%:%S") Scanning $directory"
  generateAssetList "$directory"
}

function getAssetComponents {
  givenAsset=$1
  path=$(echo $givenAsset | rev | cut -d/ -f2- | rev)
  sourceFile=$(echo $givenAsset | rev | cut -d/ -f1 | rev)
  destinationFile=$(echo $sourceFile | sed -e"s/.mkv/ - H264.mp4/")
  assetFolder=$(echo $path | rev | cut -d/ -f1 | rev)
  shortFile="$(echo $givenAsset | rev | cut -d/ -f1 | cut -d\) -f2- | rev))"
  echo "$path","$sourceFile","$destinationFile","$assetFolder","$shortFile"
}

function checkAssets {
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
}

function checkFreeSpace {
  path="$1"
  echo "$path"
  percentage=$(df -kh "$path" | grep '//' | awk '{print $5}' | tr -d '%')
  echo $percentage
}

function transodeAssets {
  directory=$1
  for asset in "${transcodeList[@]}"
  do
    details=$(getAssetComponents "$asset")
    path=$(echo "$details" | cut -d, -f1)
    sourceFile=$(echo "$details" | cut -d, -f2)
    destinationFile=$(echo "$details" | cut -d, -f3)
    freeSpace=$(checkFreeSpace "$directory")
    freeSpacePercent=$(echo $freeSpace | rev | awk '{print $1}' | rev)

    if [[ ($freeSpacePercent -le 95) && ($(grep -q "$sourceFile" $complete 2>/dev/null) -ne 0) ]]
    then
      echo "$(date +"%Y-%m-%d %H:%M:%S") Starting transcode of $sourceFile" >> $log
      echo HandBrakeCLI -i "$path"/"$sourceFile" -o "$path"/"$destinationFile" --preset-import-file "Modified H264"
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
}

for directory in "$movie" "$tv" "$userDir"
do
  if [[ ! -z $directory ]]
  then
    echo "$directory"
    getAssets "$directory"
    checkAssets
    transodeAssets "$directory"
  fi
done