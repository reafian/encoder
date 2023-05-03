#! /bin/bash

if [[ $(uname -s) == "Darwin" ]]
then
  movies="/Volumes/Public/Shared Videos/Movies"
  tv="/Volumes/Public/Shared Videos/TV Shows"
  complete="$HOME/Documents/complete.txt"
  log="$HOME/Documents/transcode.log"
  HandBrakeCLI=/usr/local/bin/HandBrakeCLI
else
  movies="/mnt/Shared Videos/Movies"
  tv="/mnt/Shared Videos/TV Shows"
  complete="$HOME/Documents/complete.txt"
  log="$HOME/Documents/transcode.log"
  HandBrakeCLI=/usr/local/bin/HandBrakeCLI
fi

function generateMovieList {
  find "$movies" -name "*.mkv" | while read list
  do
    title=$(echo $list | rev | cut -d/ -f1 | rev)
    path=$(echo $list | rev | cut -d/ -f2- | rev)
    titleCheck=$(checkTitleComplete $title)
    if [[ $titleCheck != 0 ]]
    then
      titleStatus=$(checkTitle "$title" "$path")
      if [[ $titleStatus -eq 1 ]]
      then
        transcodePrep "$title" "$path"
      fi
    fi
  done
}

function transcodePrep {
  title="$1"
  path="$2"
  newTitle=$(echo $title | sed -e"s/.mkv/ - H264.mp4/")
  diskCheck=$(checkFreeSpace)
  if [[ $diskCheck -le 95 ]]
  then
    echo "$(date +"%Y-%m-%d %H:%M:%S") Starting transode of $title" >> $log
    if [[ ! -e "$path"/"$newTitle" ]]
    then
      echo $newTitle
      transcode "$title" "$path"
    fi
  else
    echo "Not enough disk space left - exiting"
    echo "$(date +"%Y-%m-%d %H:%M:%S") Insufficient disk space" >> $log
    exit
  fi
}

function transcode {
  title="$1"
  path="$2"
  newTitle=$(echo $title | sed -e"s/.mkv/ - H264.mp4/")
echo    HandBrakeCLI -i "$path"/"$title" -o "$path"/"$newTitle" --preset-import-file "Modified H264"
    if [[ $? == 0 ]]
    then
      echo "$title" >> $complete
      echo "$(date +"%Y-%m-%d %H:%M:%S") transcode of $title completed" >> $log
    else
      echo "$(date +"%Y-%m-%d %H:%M:%S") transcode of $title failed" >> $log
    fi
}

function checkTitleComplete {
  grep -q "$1" $complete 2>/dev/null
  if [[ $? == 0 ]]
  then
    return 0
  fi
}

function checkFreeSpace {
  percentage=$(df -kh /mnt | grep mnt | awk '{print $5}' | tr -d '%')
  echo $percentage
}

function checkTitle {
  title="$1"
  shortTitle="$(echo $title | rev | cut -d. -f2- | rev)"
  path="$2"
  folder=$(echo "$path" | rev | cut -d/ -f1 | rev)
  if [[ "$folder" == "$shortTitle" ]]
  then
    echo 1 
  fi
}

generateMovieList
