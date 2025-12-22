.PHONY: submit dryrun executables x509up testEnv

# List of configuration files and executables to be included in the tarball.
CONFIG_FILES = $(shell cat config_file_list.txt)
EXECUTABLES = hepmcConcat Pythia8.exe
X509UP_FILE = /afs/cern.ch/user/c/chiw/condor/x509up
# HepMC2-related variables
HEPMC2_DIR = /afs/cern.ch/user/c/chiw/public/cms-utils/HepMC-2.06.11/install
HEPMC2_INCLUDES = -I$(HEPMC2_DIR)/include
HEPMC2_LIBS = -L$(HEPMC2_DIR)/lib -lHepMC
# Pythia8-related variables
PYTHIA8_DIR = /afs/cern.ch/user/c/chiw/public/cms-utils/pythia8245
PYTHIA8_INCLUDES = -I$(PYTHIA8_DIR)/include
PYTHIA8_LIBS = -L$(PYTHIA8_DIR)/lib -lpythia8  -ldl -lz -lboost_iostreams
# Other environment variables
CMSSW_EL7_ENV_SCRIPT = cmssw-el7_env.sh
# Compiler settings
CXX = g++
CXXFLAGS = --std=c++11 -Wall -O2 -g

submit: cmssw_configs.tar
# 	Check X509 user proxy first. Invoke creation if not present or expired.
	@ if [ ! -f $(X509UP_FILE) ] || [ ! $$(voms-proxy-info -file $(X509UP_FILE) -exists) ]; then \
		echo "X509 user proxy not found or expired. Creating a new one..."; \
		$(MAKE) x509up; \
	else \
		echo "X509 user proxy found and valid."; \
	fi
	mkdir -p logs && condor_submit LHE-to-SKIM.sub
	cp LHE_source.txt logs/

executables: hepmcConcat Pythia8.exe

cmssw_configs.tar: $(CONFIG_FILES) $(EXECUTABLES) $(CMSSW_EL7_ENV_SCRIPT)
	tar -cvf cmssw_configs.tar $^

hepmcConcat:
	@ cmssw-el7 --command-to-run \
		"source $(CMSSW_EL7_ENV_SCRIPT) && $(CXX) $(CXXFLAGS) $(HEPMC2_INCLUDES) -o $@ hepmcConcat.cpp $(HEPMC2_LIBS)"

Pythia8.exe:
	@ cmssw-el7 --command-to-run \
		"source $(CMSSW_EL7_ENV_SCRIPT) && $(CXX) $(CXXFLAGS) $(HEPMC2_INCLUDES) $(PYTHIA8_INCLUDES) -o $@ Pythia82.cc $(HEPMC2_LIBS) $(PYTHIA8_LIBS)"

testEnv:
	@ cmssw-el7 --command-to-run "source $(CMSSW_EL7_ENV_SCRIPT)"

x509up:
	voms-proxy-init --voms cms --valid 192:00 --out $(X509UP_FILE)	