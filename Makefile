SHELL:=/bin/bash

## a simple test of udpipe : just 1 file 
#sampleCZ = "./sample-data-CZ/downloader-tei-meta"
#sampleAT = "sample-data-AT"

#cz:
#	ls ${sampleCZ} | grep -P '.xml$$'  > TEST_TEI_FILELIST_CZ.txt;
#	mkdir -p udpipe_results/cz; rm -f udpipe_results/*
#	perl -I lib src/udpipe2/udpipe2.pl --colon2underscore \
#                               --model=czech-pdt-ud-2.6-200830 \
#                               --filelist TEST_TEI_FILELIST_CZ.txt \
#                               --input-dir ${sampleCZ} \
#                               --output-dir udpipe_results/cz

#at:
#	ls ${sampleAT}  | grep -P '\.xml$$'  > TEST_TEI_FILELIST_AT.txt
#	mkdir -p udpipe_results/parlat; rm -f udpipe_results/parlat/*
#	perl -I lib src/udpipe2/udpipe2.pl \
#						 --colon2underscore \
#						--try2fix-spaces \
#                               --model=german-hdt-ud-2.10-220711 \
#                               --filelist TEST_TEI_FILELIST_AT.txt \
#                               --input-dir ${sampleAT} \
#                               --output-dir udpipe_results/parlat


udt: udpipetest udcleantest udtest errorstatsanatest
	
udpipetest:
	ls TEST_ParlaMint-AT | grep -P 'xml$$' | grep -v ana.xml | head -n 100 > TEST_TEI_FILELIST4udpipe.txt;
	mkdir -p udpipe_results/TEST_ParlaMint-AT; rm -f udpipe_results/TEST_ParlaMint-AT/*
	nohup perl -I src/udpipe2/udpipe2.pl \
						 --colon2underscore \
						 --try2fix-spaces \
                               --model=german-hdt-ud-2.10-220711 \
                               --filelist TEST_TEI_FILELIST4udpipe.txt \
                               --input-dir TEST_ParlaMint-AT \
                               --output-dir udpipe_results/TEST_ParlaMint-AT > nohup_udpipetest_$$(date +%F).log
	# rename results to ana.xml 
	ls -d udpipe_results/TEST_ParlaMint-AT/ParlaMint-AT_*.xml | grep -vP '\.ana\.xml$$' |  $P --jobs 7 \
	'mv -v {} udpipe_results/TEST_ParlaMint-AT/{/.}.ana.xml ;'                               
                        
## run a clean-up : remove lemma from punct and take care that TEI@xml:id == filename 
udcleantest:
	mkdir -p udpipe_results/TEST_ParlaMint-ATclean
	rm -f udpipe_results/TEST_ParlaMint-ATclean/*ana.xml
	ls -d udpipe_results/TEST_ParlaMint-AT/*ana.xml |  head -n $L | $P --jobs 7 \
	'$s -xsl:bin/stenoTEI2ParlaMint.xsl {} > udpipe_results/TEST_ParlaMint-ATclean/{/.}.xml ; java -jar /opt/utils/jing/jing.jar  ./Schema/ParlaMint-TEI.ana.rng udpipe_results/TEST_ParlaMint-ATclean/{/.}.xml' 2>&1 | tee errors_parlamint_anaTEST_$$(date +%F).txt 
	ln -fs errors_parlamint_anaTEST_$$(date +%F).txt errors_parlamint_anaTEST.txt
                               
## perform some tests on udpipe-results:
## number of utterances? number of notes?
udtest:
	@echo "Perform some tests on udpipe-results"
	@for f in $$(ls udpipe_results/TEST_ParlaMint-ATclean | grep -P 'ana.xml$$' | head -n 20); do \
		echo -e "\n == $$f <u> =="; \
		echo -e "udpipe: number of u:" $$(xml_grep --count '//u' udpipe_results/TEST_ParlaMint-AT/$$f); \
		echo -e "orig:   number of u:" $$(xml_grep --count '//u' TEST_ParlaMint-AT/$${f/.ana.xml/.xml}); \
		echo -e "\n == $$f <note> =="; \
		echo -e "udpipe: number of note:" $$(xml_grep --count '//note' udpipe_results/TEST_ParlaMint-AT/$$f); \
		echo -e "orig:   number of note:" $$(xml_grep --count '//note' TEST_ParlaMint-AT/$${f/.ana.xml/.xml}); \
		echo -e "\n == $$f <time> =="; \
		echo -e "udpipe: number of time:" $$(xml_grep --count '//time' udpipe_results/TEST_ParlaMint-AT/$$f); \
		echo -e "orig:   number of time:" $$(xml_grep --count '//time' TEST_ParlaMint-AT/$${f/.ana.xml/.xml}); \
		echo -e "\n == $$f <vocal> =="; \
		echo -e "udpipe: number of vocal:" $$(xml_grep --count '//vocal' udpipe_results/TEST_ParlaMint-AT/$$f); \
		echo -e "orig:   number of vocal:" $$(xml_grep --count '//vocal' TEST_ParlaMint-AT/$${f/.ana.xml/.xml}); \
	done  
	
## make error statistics for .ana.xml
## errors_parlamint_anaTEST.txt
errorstatsanatest:
	{ \
	set -e \
	if [ -s "errors_anaTEST_$(DAT)_statistics.txt" ] then \
	rename -v 's/^/_/' errors_anaTEST_$(DAT)_statistics.txt \
	fi; \
	if [ -s "errors_parlamint_anaTEST.txt" ]; then \
	cat  errors_parlamint_anaTEST.txt | perl -pe 's/^.+( error: )/$$1/' | sort | uniq -c | sort -r -n > errors_anaTEST_$(DAT)_TYPES.csv;  \
	bin/log2vi.pl     errors_parlamint_anaTEST.txt                > errors_anaTEST_$(DAT)_VI_OXYGEN.csv ; \
	bin/log2vi.pl -f  errors_parlamint_anaTEST.txt | grep oxygen  > errors_anaTEST_$(DAT)_files.csv ; \
	bin/inspect_logs.sh  errors_parlamint_anaTEST.txt > errors_anaTEST_$(DAT)_statistics.txt; \
	bin/log2vi.pl -l  errors_parlamint_anaTEST.txt | perl -pe 's{^.+/STENO_TEI./}{STENO_HTML/}; s/\.xml/.html/;' > errors_anaTEST_$(DAT)_html_files.csv ; \
	cut -f 1 -d :  errors_parlamint_anaTEST.txt | sort | uniq -c | sort -rn > errors_anaTEST_$(DAT)_NUMber_errors_per_file.csv ; \
	grep "vi " errors_anaTEST_$(DAT)_VI_OXYGEN.csv | perl -pe 's{/home/user/parlat_data/parlatSLOVENIA/parlat/}{./}' > anaTESTerrvi.txt; \
	echo -e "\n\n For copying erroneous HTML to TEST_HTML\n\n\n make errhtml2test\n\n\n"; \
	else \
	echo -e "\n\nExpected errorfile is missing or EMPTY:  errors_parlamint_anaTEST.txt\n"; \
	fi \
	}
	
