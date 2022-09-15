SHELL:=/bin/bash

## a simple test of udpipe : just 1 file 
sampleCZ = "./sample-data-CZ/downloader-tei-meta"
sampleAT = "sample-data-AT"

cz:
	ls ${sampleCZ} | grep -P '.xml$$'  > TEST_TEI_FILELIST_CZ.txt;
	mkdir -p udpipe_results/cz; rm -f udpipe_results/*
	perl -I lib src/udpipe2/udpipe2.pl --colon2underscore \
                               --model=czech-pdt-ud-2.6-200830 \
                               --filelist TEST_TEI_FILELIST_CZ.txt \
                               --input-dir ${sampleCZ} \
                               --output-dir udpipe_results/cz

at:
	ls ${sampleAT}  | grep -P '\.xml$$'  > TEST_TEI_FILELIST_AT.txt
	mkdir -p udpipe_results/parlat; rm -f udpipe_results/parlat/*
	perl -I lib src/udpipe2/udpipe2.pl \
						 --colon2underscore \
                               --model=german-hdt-ud-2.10-220711 \
                               --filelist TEST_TEI_FILELIST_AT.txt \
                               --input-dir ${sampleAT} \
                               --output-dir udpipe_results/parlat

