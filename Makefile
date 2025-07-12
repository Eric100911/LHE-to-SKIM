.PHONY: submit dryrun


submit: x509up cmssw_configs.tar
	condor_submit LHE-to-SKIM.sub

cmssw_configs.tar: $$(shell cat config_files.txt)
	tar -cvf cmssw_configs.tar $$(cat config_files.txt)

x509up:
	voms-proxy-init --voms cms --valid 192:00 --out x509up
