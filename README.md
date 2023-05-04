**Plex encoder on Raspberry Pi**

Handbrake encoding on a Raspberry Pi.

Yes, it's completely bonkers but, yes, it kind of does work. It's slow. Very slow. Go to bed and don't worry about things.

Firstly, get HandBrake working on the pi. The absolutely best guide is here: https://github.com/rafaelmaeuer/handbrake-pi

There are only a couple of small changes. I used Raspbian not Debian. Practically, there's no difference. I'm running Rasbian 11 (bullseye) and the instructions for Debian 10 work just fine. For the git clone line I used:

git clone -b 1.6.1 https://github.com/HandBrake/HandBrake.git && cd HandBrake

Because 1.6.1 is running on my Mac. For the build just follow the guide although "make clean" didn't work for me and I used gmake instead but that's pretty trivial.

All my media is on a PR4100 and the mounted structure on my Mac is:

/Volumes/Public/Shared Music
/Volumes/Public/Shared Pictures
/Volumes/Public/Shared Videos

I've mounted these on the pi using:

//192.168.1.3/Public /mnt cifs guest,iocharset=utf8,file_mode=0777,dir_mode=0777,noperm 0 0

(It's not automounting just yet and I'm trying to figure out if I care or not)

Anyway, the point of this script was to transode all the .mkv files I have to H264 mp4 files. I'd already created everything as H265 (to save myself space) but not everythiing plays nicely with H265. I was after a way to transcode everything without tying up my Mac. I figured that, as I wasn't in any real hurry, I could use a spare pi and have that do the work for me. I rekon it's going to take around 2 days to do a single .mkv file so it'll take a while.

## Obvious things to do
1 - Use mediainfo to find non-English languages and use different handbrake profile
2 - Get TV directory / non-standard directories working
3 - File specific transcoding
4 - Maybe ignore -pt1 / -pt2 files?