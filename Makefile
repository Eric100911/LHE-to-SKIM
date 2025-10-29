.PHONY: submit dryrun x509up

CONFIG_FILES = $(shell cat config_file_list.txt)

submit: x509up cmssw_configs.tar
	mkdir -p logs && condor_submit LHE-to-SKIM.sub
	cp LHE_source.txt logs/

cmssw_configs.tar: $(CONFIG_FILES)
	tar -cvf cmssw_configs.tar $(CONFIG_FILES)

x509up:
	voms-proxy-init --voms cms --valid 192:00 --out /afs/cern.ch/user/c/chiw/condor/x509up
