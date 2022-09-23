
ParCzech4AT/udpipe_results/TEST_ParlaMint-ATclean/ParlaMint-AT_1996-10-02-020_XX_NRSITZ_00040.ana.xml

#####################################
## multiple <s> with the same xml:id 
#####################################

e.g. 20 hits for:
//seg[@xml:id="NRSITZ_020_00040_d2e931"]/s[@xml:id="NRSITZ_020_00040_d2e931.s1"]

same resuls for: 
//s[@xml:id="NRSITZ_020_00040_d2e931.s1"]

(i.e. there are 20 <s> with the same id under 1 <seg>

 
#############################
## empty <seg/>
#############################

19 hits for:
//seg[not(text())]


