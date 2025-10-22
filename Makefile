.PHONY: submit dryrun

CONFIG_FILES = $(shell cat config_file_list.txt)

submit: x509up cmssw_configs.tar
	condor_submit LHE-to-SKIM.sub

cmssw_configs.tar: $(CONFIG_FILES)
	tar -cvf cmssw_configs.tar $(CONFIG_FILES)

x509up:
	voms-proxy-init --voms cms --valid 192:00 --out x509up
