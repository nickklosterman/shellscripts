#!/bin/sh
#
# by Sairon Istyar, 2012
# distributed under the GPLv3 license
# http://www.opensource.org/licenses/gpl-3.0.html
#


#TODO:
# get the magnet links of the files and autoload them into rtorrent
# or run them through the magnet->.torrent file generator and stick them in the watch folder
# option to output , errr download the torrent files


### CONFIGURATION ###
# program to use for torrent download
# magnet link to torrent will be appended
# you can add -- at the end to indicate end of options
# (if your program supports it, most do)
program='/usr/bin/transmission-remote -a'
TPB="https://thepiratebay.sx"

# show N first matches by default
limit=15

#default to search and display results for all categories
category=0

# colors
numbcolor='\x1b[1;35m'
namecolor='\x1b[1;33m'
sizecolor='\x1b[1;36m'
seedcolor='\x1b[1;31m'
peercolor='\x1b[1;32m'
errocolor='\x1b[1;31m'
mesgcolor='\x1b[1;37m'
nonecolor='\x1b[0m'

# default ordering method
# 1 - name ascending; 2 - name descending;
# 3 - recent first; 4 - oldest first;
# 5 - size descending; 6 - size ascending;
# 7 - seeds descending; 8 - seeds ascending;
# 9 - leechers descending; 10 - leechers ascending;
orderby=7
### END CONFIGURATION ###

outputMagnetFile=TPB.magnets

constants() {
echo="
class ORDERS(Constants):
    class NAME:
        ASC = 1
        DES = 2
    class UPLOADED:
        ASC = 3
        DES = 4
    class SIZE:
        ASC = 5
        DES = 6
    class SEEDERS:
        ASC = 7
        DES = 8
    class LEECHERS:
        ASC = 9
        DES = 10
    class UPLOADER:
        ASC = 11
        DES = 12
    class TYPE:
        ASC = 13
        DES = 14

class CATEGORIES(Constants):
    ALL = 0
    class AUDIO:
        ALL = 100
        MUSIC = 101
        AUDIO_BOOKS = 102
        SOUND_CLIPS = 103
        FLAC = 104
        OTHER = 199
    class VIDEO:
        ALL = 200
        MOVIES = 201
        MOVIES_DVDR = 202
        MUSIC_VIDEOS = 203
        MOVIE_CLIPS = 204
        TV_SHOWS = 205
        HANDHELD = 206
        HD_MOVIES = 207
        HD_TV_SHOWS = 208
        THREE_DIMENSIONS = 209
        OTHER = 299
    class APPLICATIONS:
        ALL = 300
        WINDOWS = 301
        MAC = 302
        UNIX = 303
        HANDHELD = 304
        IOS = 305
        ANDROID = 306
        OTHER = 399
    class GAMES:
        ALL = 400
        PC = 401
        MAC = 402
        PSX = 403
        XBOX360 = 404
        WII = 405
        HANDHELD = 406
        IOS = 407
        ANDROID = 408
        OTHER = 499
    class OTHER:
	ALL = 600
        EBOOKS = 601
        COMICS = 602
        PICTURES = 603
        COVERS = 604
        PHYSIBLES = 605
        OTHER = 699


"
}
listCategories() {
echo -e "ALL = 0(default)
    class AUDIO:
        ALL = 100
        MUSIC = 101
        AUDIO_BOOKS = 102
        SOUND_CLIPS = 103
        FLAC = 104
        OTHER = 199
    class VIDEO: \t\tclass GAMES:
        ALL = 200 \t\t\tALL = 400
        MOVIES = 201\t\t\tPC = 401
        MOVIES_DVDR = 202\t\tMAC = 402
        MUSIC_VIDEOS = 203\t\tPSX = 403
        MOVIE_CLIPS = 204\t\tXBOX360 = 404
        TV_SHOWS = 205\t\t\tWII = 405
        HANDHELD = 206\t\t\tHANDHELD = 406
        HD_MOVIES = 207\t\t\tIOS = 407
        HD_TV_SHOWS = 208\t\tANDROID = 408
        THREE_DIMENSIONS = 209\t\tOTHER = 409
        OTHER = 299
    class APPLICATIONS:\t\tclass OTHER:
        ALL = 300\t\t\tALL = 600
        WINDOWS = 301\t\t\tEBOOKS  = 601
        MAC = 302\t\t\tCOMICS  = 602
        UNIX = 303\t\t\tPICTURES  = 603
        HANDHELD = 304\t\t\tCOVERS  = 604
        IOS = 305\t\t\tPHYSIBLES  = 605
        ANDROID = 306\t\t\tOTHER  = 699
        OTHER = 399
"
}

thisfile="$0"

printhelp() {
	echo -e "Usage:"
	echo -e "\t$thisfile [options] search query"
	echo -e "\t$thisfile -c600 -n10 Linux"
	echo
	echo
	echo -e "Available options:"
	echo -e "\t-h\t\tShow help"
	echo -e "\t-n [num]\tShow only first N results (default 15; max 100 [top] or 30 [search])"
	echo -e "\t-C\t\tDo not use colors"
	echo -e "\t-c [num]\tSearch by category"
	echo -e "\t-L \t\tList categories"
	echo -e "\t-P [prog]\tSet torrent client command (\`-P torrent-client\` OR \`-P \"torrent-client --options\"\`)"
	echo
	echo -e "Current client settings: $program [magnet link]"
}

# change torrent client
chex() {
	sed "s!^program=.*!program=\'$program\'!" -i "$thisfile"
	if [ $? -eq 0 ] ; then
		echo "Client changed successfully."
		exit 0
	else
		echo -e "${errocolor}(EE) ${mesgcolor}==> Something went wrong!${nonecolor}"
		exit 1
	fi
}

# script cmdline option handling
##while getopts :hn:c:CP:: opt ; do
while getopts "hf:n:c:CLP:" opt ; do
	case "$opt" in
		h) printhelp; exit 0;;
		n) limit="$OPTARG";;
		C) unset numbcolor namecolor sizecolor seedcolor peercolor nonecolor errocolor mesgcolor;;
		c) category="$OPTARG";;
		L) listCategories;exit;;
		P) program="$OPTARG"; chex;;
	        f) outputMagnetFile="$OPTARG";;
		*) echo -e "Unknown option(s)."; printhelp; exit 1;;		
	esac
done
#echo "category:$category \n limit:$limit \n program:$program"
shift `expr $OPTIND - 1`

#I think I won't check if there is a filename conflict. I think this will keep things simple. As it stands this will APPEND to a previous queries file.
if [ $outputMagnetFile == "TPB.magnets" ]
then
    unencodedQuery=$*
    outputMagnetFile="${unencodedQuery}.magnets"
    echo ${outputMagnetFile}
fi

# correctly encode query
q=`echo "$*" | tr -d '\n' | od -t x1 -A n | tr ' ' '%'`

# if not searching, show top torrents
if [ -z "$q" ] ; then
	url="top/all"
else
	url='search/'"$q"'/0/'"$orderby"'/'"$category"
	echo "${url}"
#	url='search/'"$q"'/0/'"$orderby"'/600'
fi
# get results
# Here be dragons!
r=`curl -k -A Mozilla -b "lw=s" -m 15 -s "$TPB/$url" \
	| grep -Eo '^<td><a href=\"/torrent/[^>]*>.*|^<td><nobr><a href=\"[^"]*|<td align=\"right\">[^<]*' \
	| sed  's!^<td><a href=\"/torrent/[^>]*>!!; \
		s!</a>$!!; \
		s!^<td><nobr><a href=\"!!; \
		s!^<td [^>]*>!!; \
		s!&nbsp;!\ !g; \
		s/|/!/g' \
	| sed  'N;N;N;N;s!\n!|!g'`

# number of results
n=`echo "$r" | wc -l`

IFS=$'\n'

# print results
echo "$r" \
	| head -n "$limit" \
	| awk -v N=1 \
		-v NU="$numbcolor" \
		-v NA="$namecolor" \
		-v SI="$sizecolor" \
		-v SE="$seedcolor" \
		-v PE="$peercolor" \
		-v NO="$nonecolor" \
		-F '|' \
		'{print NU N ") " NA $1 " " SI $3 " " SE $4 " " PE $5 NO; N++}'

# read ID(s), expand ranges, ignore everything else
read -p ">> Torrents to download (eg. 1 3 5-7): " selection
IFS=$'\n\ '
for num in $selection ; do
	if [ "$num" = "`echo $num | grep -o '[[:digit:]][[:digit:]]*'`" ] ; then
		down="$down $num"
	elif [ "$num" = "`echo $num | grep -o '[[:digit:]][[:digit:]]*-[[:digit:]][[:digit:]]*'`" ] ; then
		seqstart="${num%-*}"
		seqend="${num#*-}"
		if [ $seqstart -le $seqend ] ; then
			down="$down `seq $seqstart $seqend`"
		fi
	fi
done

# normalize download list, sort it and remove dupes
down="$(echo $down | tr '\ ' '\n' | sort -n | uniq)"
IFS=$'\n'
#$down holds the index of the torrent to be downloaded

# check whether we're downloading something, else exit
if [ -z "$down" ] ; then
	exit 0
fi

# download all torrents in list
echo -n "Downloading torrent(s): "
for torrent in $down ; do
	# check if ID is valid and in range of results, download torrent
	if [ $torrent -ge 1 ] ; then
		if [ $torrent -le $limit ] ; then
			echo -n "$torrent "
			#uncomment the following line to send the magnets to the desired program
			#command="$program `echo "$r" | awk -F '|' 'NR=='$torrent'{print $2; exit}'`"
			echo "$r" | awk -F '|' 'NR=='$torrent'{print $2; exit}' >> "${outputMagnetFile}"
			status=$(eval "$command" 2>&1)
			if [ $? -ne 0 ] ; then
				echo -n '(failed!) '
				report="$report\n(#$torrent) $status"
			fi
		fi
	fi
done
echo
if [ -n "$report" ] ; then
	echo -n "Exited with errors:"
	echo -e "$report"
fi
unset IFS
