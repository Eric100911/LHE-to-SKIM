.PHONY: submit dryrun executables x509up testEnv testPythia testHepMC cleanTest

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
# Test files
TEST_DIR = test
TEST_LHE = $(wildcard $(TEST_DIR)/*.lhe)
TEST_HEPMC = $(patsubst $(TEST_DIR)/%.lhe,$(TEST_DIR)/%.hepmc,$(TEST_LHE))
TEST_HEPMC_OUT = $(TEST_DIR)/concatenated.hepmc

submit: cmssw_configs.tar
# 	Check X509 user proxy first. Invoke creation if not present or expired.
	if [ ! -f $(X509UP_FILE) ] || [ ! $$(voms-proxy-info -file $(X509UP_FILE) -exists) ]; then \
		echo "X509 user proxy not found or expired. Creating a new one..."; \
		$(MAKE) x509up; \
	else \
		echo "X509 user proxy found and valid."; \
	fi
	mkdir -p logs && condor_submit LHE-to-SKIM.sub
	cp LHE_source.txt logs/

x509up:
	voms-proxy-init --voms cms --valid 168:00 --out $(X509UP_FILE)

executables: hepmcConcat Pythia8.exe

testEnv:
	cmssw-el7 --command-to-run \
		"source $(CMSSW_EL7_ENV_SCRIPT)"

testPythia: Pythia8.exe $(TEST_HEPMC)

testHepMC: hepmcConcat $(TEST_HEPMC_OUT)

cleanTest:
	rm -f $(TEST_HEPMC) $(TEST_HEPMC_OUT) $(TEST_DIR)/Pythia8_lhe.cmnd

cmssw_configs.tar: $(CONFIG_FILES) $(EXECUTABLES) $(CMSSW_EL7_ENV_SCRIPT)
	tar -cvf cmssw_configs.tar $^

$(TEST_HEPMC_OUT): hepmcConcat $(TEST_HEPMC)
	cmssw-el7 --command-to-run \
		"source $(CMSSW_EL7_ENV_SCRIPT) && ./hepmcConcat $(TEST_HEPMC_OUT) $(TEST_HEPMC) "

$(TEST_DIR)/%.hepmc: $(TEST_DIR)/%.lhe Pythia8.exe $(TEST_DIR)/Pythia8_lhe.cmnd
	cmssw-el7 --command-to-run \
		"source $(CMSSW_EL7_ENV_SCRIPT) && ./Pythia8.exe --lhef $(TEST_DIR)/$*.lhe --cmnd $(TEST_DIR)/Pythia8_lhe.cmnd --output $@ "

$(TEST_DIR)/Pythia8_lhe.cmnd: Pythia8_lhe.cmnd
	cp $< $@

hepmcConcat: hepmcConcat.cpp
	cmssw-el7 --command-to-run \
		"source $(CMSSW_EL7_ENV_SCRIPT) && $(CXX) $(CXXFLAGS) $(HEPMC2_INCLUDES) -o $@ hepmcConcat.cpp $(HEPMC2_LIBS)"

Pythia8.exe: Pythia82.cc
	cmssw-el7 --command-to-run \
		"source $(CMSSW_EL7_ENV_SCRIPT) && $(CXX) $(CXXFLAGS) $(HEPMC2_INCLUDES) $(PYTHIA8_INCLUDES) -o $@ Pythia82.cc $(HEPMC2_LIBS) $(PYTHIA8_LIBS)"
