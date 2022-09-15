#!/bin/bash

D=`dirname $0`
cd $D

pid=$$

CONFIG_FILE="config.sh"
DOWN_PARAMS=()
EXISTING_FILELIST=
EXIT_CONDITION=

usage() {
  echo -e "Usage: $0 -c CONFIG_FILE (-p PRUNE_TEMPLATE | -l FILELIST) -E EXIT_CONDITION" 1>&2
  exit 1
}

while getopts  ':c:p:l:E:'  opt; do # -l "identificator:,file-pattern:,export-audio" -a -o
  case "$opt" in
    'c')
      CONFIG_FILE=$OPTARG
      ;;
    'p')
      [ -n "$EXISTING_FILELIST" ] && usage || DOWN_PARAMS+=(--prune $OPTARG )
      ;;
    'l')
      [ ${#DOWN_PARAMS[@]} -ne 0 ] && usage || EXISTING_FILELIST=$OPTARG
     #[ ${#DOWN_PARAMS[@]} -ne 0 ] && echo "nenula"
      ;;
    'E')
      EXIT_CONDITION=$OPTARG
      ;;
    *)
      usage
  esac
done


export SHARED=.
export TEITOK=./TEITOK
export TEITOK_CORPUS=$TEITOK/projects/CORPUS
export METADATA_NAME=ParCzech-live


set -o allexport
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi
set +o allexport

function log {
  str=`date +"%Y-%m-%d %T"`"\t$@"
  echo -e "$str"
  echo -e "$str" >> ${SHARED}/parczech.log
}

function log_process {
  echo "$pid steno_download" > ${SHARED}/current_process
}

function skip_process {
  if [ -f "$3" ]; then
    log "testing if file exist ($1)"
    for tested_file in `cat $3`
    do
      if [ ! -s  "$2/$tested_file" ]; then
        log "file does not exists or is empty: $2/$tested_file"
        return 0;
      fi
    done
    log "SKIPPING $1 ($2)"
    return  1;
  fi
  return 0;
}

function skip_process_single_file {
  if [ ! -s  "$2" ]; then
    log "file does not exists or is empty: $2"
    return 0;
  fi
  log "SKIPPING $1 ($2)"
  return  1;
}

function patch_invalid_characters {
  if [ ! -s  "$1" ]; then
    log "file does not exists or is empty: $1"
    return 0;
  fi
  # \x{200B} = [ZERO WIDTH SPACE]
  # \x{202F} = [NARROW NO-BREAK SPACE]
  # \x{00A0} = [NO-BREAK SPACE]
  # \x{00AD} = [SOFT HYPHEN]
  perl -CSD -pi -e '$_ =~ tr/\x{200B}\x{00AD}//d;$_ =~ tr/\x{202F}\x{00A0}/  /;' $1
}

log "STARTED: $pid ========================$EXIT_CONDITION"
log "CONFIG FILE: $CONFIG_FILE"


if [ -n "$EXISTING_FILELIST" ]; then
  if [ -f "$EXISTING_FILELIST" ]; then
    log "USING EXISTING FILELIST: $EXISTING_FILELIST"
    export ID=`echo "$EXISTING_FILELIST"| sed 's@^.*\/@@;s@\..*tei\.fl$@@'` # allow interfix eg  20201218T120411.patch01.tei.fl (you can use sublist for patching some files)
  else
    echo  "file $EXISTING_FILELIST error" 1>&2
    usage
  fi
else
  export ID=`date +"%Y%m%dT%H%M%S"`
  log "FRESH RUN: $ID"
fi

log "PROCESS ID: $ID"
log "downloader params: ${DOWN_PARAMS[@]}"

if [ -f 'current_process' ]; then
  proc=`cat 'current_process'`
  echo "another process is running: $proc"
  log "another process is running: $proc"
  log "FINISHED $ID: $pid"
  exit 0;
fi

###############################
### Download stenoprotocols ###
#   input:
#   output:
#     new:
#       downloader-yaml/$ID
#         - contains exported yaml files (only for quick manual checkout)
#       downloader-tei/$ID
#         ./YYYY-SSS                     ## each session has its own directory
#           - teifiles
#         ./person.xml                   ## copied from previeous run
#         ./ParCzech-$ID.xml             ## teiCorpus
#     update:
#       downloader-tei/sha1sum.list      ## pairs shasum=/path/.../downloader-tei/$ID/YYYY-SSS/teifile.xml
#
###############################

log_process "steno_download"

export CL_WORKDIR=$DATA_DIR/downloader
export CL_OUTDIR_YAML=$DATA_DIR/downloader-yaml
export CL_OUTDIR_TEI=$DATA_DIR/downloader-tei
export CL_OUTDIR_CACHE=$DATA_DIR/downloader-cache
export CL_OUTDIR_HTML=$DATA_DIR/downloader-html
export CL_SCRIPT=stenoprotokoly_2013ps-now.pl
export FILELISTS_DIR=$DATA_DIR/filelists
mkdir -p $CL_WORKDIR
mkdir -p $CL_OUTDIR_YAML
mkdir -p $CL_OUTDIR_TEI
mkdir -p $CL_OUTDIR_CACHE
mkdir -p $CL_OUTDIR_HTML
mkdir -p $FILELISTS_DIR

export DOWNLOADER_TEI="$CL_OUTDIR_TEI/$ID"
export PERSON_LIST_PATH="$DOWNLOADER_TEI/person.xml"
export INTERFIX=ana

export TEICORPUS_FILENAME="ParCzech-$ID.xml"
export ANATEICORPUS_FILENAME="ParCzech-$ID.$INTERFIX.xml"
export TEI_FILELIST="$FILELISTS_DIR/$ID.tei.fl"
if [ -n "$EXISTING_FILELIST" ]; then
  TEI_FILELIST=$EXISTING_FILELIST
fi




###############################################
###     UDPipe tei (using web service)      ###
###  Tokenize, lemmatize, PoS, parse tei    ###
#  input:
#    downloader-tei-meta/$ID
#  output:
#    udpipe-tei/$ID
###############################################

export UDPIPE_TEI=$DATA_DIR/udpipe-tei/${ID}

if skip_process "udpipe2" "$UDPIPE_TEI" "$EXISTING_FILELIST" ; then # BEGIN UDPIPE2 CONDITION

mkdir -p $UDPIPE_TEI
log "annotating udpipe2 $UDPIPE_TEI"

perl -I lib udpipe2/udpipe2.pl --colon2underscore \
                               --model=czech-pdt-ud-2.6-200830 \
                               --filelist $TEI_FILELIST \
                               --input-dir $DOWNLOADER_TEI_META \
                               --output-dir $UDPIPE_TEI

fi; # END UDPIPE CONDITION



################################
####     NameTag tei         ###
##  input:
##    udpipe-tei/$ID
##  output:
##    nametag-tei/$ID
################################

#export NAMETAG_TEI=$DATA_DIR/nametag-tei/${ID}

#if skip_process "nametag2" "$NAMETAG_TEI" "$EXISTING_FILELIST" ; then # BEGIN NAMETAG CONDITION

#mkdir -p $NAMETAG_TEI
#log "annotating nametag2  $NAMETAG_TEI"

#perl -I lib nametag2/nametag2.pl --conll2003 \
#                                 --varied-tei-elements \
#                                 --model=czech-cnec2.0-200831 \
#                                 --filelist $TEI_FILELIST \
#                                 --input-dir $UDPIPE_TEI \
#                                 --output-dir $NAMETAG_TEI

#fi; # END NAMETAG CONDITION

#if [ "$EXIT_CONDITION" == "nametag" ] ; then
#  echo "EXITTING: $EXIT_CONDITION"
#  exit
#fi


