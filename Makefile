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
PYTHIA8_HEPMC2_ENV_SCRIPT = cmssw-el7_env.sh
PYTHIA8_HEPMC2_SINGULARITY = cmssw-el7
CMSSW_SINGULARITY = cmssw-el8
SCRIPTS = $(PYTHIA8_HEPMC2_ENV_SCRIPT) split_and_shower.sh workflow_cmssw.sh
# Compiler settings
CXX = g++
CXXFLAGS = --std=c++11 -Wall -O2 -g
# Test files
TEST_DIR = test
# - LHE files from matrix element generation; split for showering
TEST_LHE_SOURCE = test/test_sps_JpsiJpsi_86Evts.lhe
TEST_LHE_PREFIX = test_sps_JpsiJpsi_split_
# - Generate the list of LHE files
# - Shower all events individually
# NUM_SPLITS = $(shell grep -c "<event>" $(TEST_LHE_SOURCE))
NUM_SPLITS = 9
NUM_SPLIT_DIGITS = 7
LHE_SPLIT_EXECUTABLE = /afs/cern.ch/user/c/chiw/condor/LHE-split/build/el9_amd64_gcc12/event_splitter
TEST_LHE = $(foreach n,$(shell seq -f "%0$(NUM_SPLIT_DIGITS).0f" 0 $$( expr $(NUM_SPLITS) - 1 )),$(TEST_DIR)/$(TEST_LHE_PREFIX)${n}.lhe)
# - HepMC files from showering
TEST_HEPMC = $(patsubst $(TEST_DIR)/%.lhe,$(TEST_DIR)/%.hepmc,$(TEST_LHE))
TEST_HEPMC_FINAL = $(TEST_DIR)/concatenated.hepmc
# - Final full-chain test
TEST_CMSSW_PATH = $(TEST_DIR)/CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO
TEST_SCRAM_ARCH = el8_amd64_gcc12
TEST_MINIAOD_FINAL = $(TEST_DIR)/test_miniAOD.root

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

testWorkflow: $(TEST_MINIAOD_FINAL)

testPythia: Pythia8.exe $(TEST_HEPMC)

testShower: hepmcConcat $(TEST_HEPMC_FINAL)

testSplit: $(TEST_LHE)

testEnv: $(PYTHIA8_HEPMC2_ENV_SCRIPT)
	$(PYTHIA8_HEPMC2_SINGULARITY) --command-to-run \
		"source $(PYTHIA8_HEPMC2_ENV_SCRIPT)"

cleanTest:
	rm -f $(TEST_HEPMC) $(TEST_HEPMC_FINAL) $(TEST_DIR)/Pythia8_lhe.cmnd $(TEST_LHE)
	rm -rf $(TEST_DIR)/CMSSW_* $(TEST_DIR)/*.py $(TEST_DIR)/workflow_cmssw.sh $(TEST_MINIAOD_FINAL) $(TEST_DIR)/*.root

cmssw_configs.tar: $(CONFIG_FILES) $(EXECUTABLES) $(SCRIPTS)
# 	tar -cvf cmssw_configs.tar $(CONFIG_FILES) $(EXECUTABLES) $(PYTHIA8_HEPMC2_ENV_SCRIPT)
	tar -cvf cmssw_configs.tar $(CONFIG_FILES) $(SCRIPTS)

$(TEST_MINIAOD_FINAL): $(TEST_HEPMC_FINAL) $(CONFIG_FILES) workflow_cmssw.sh
	cp $(CONFIG_FILES) workflow_cmssw.sh $(TEST_DIR)/
	chmod +x $(TEST_DIR)/workflow_cmssw.sh
	$(CMSSW_SINGULARITY) --command-to-run \
		"cd $(TEST_DIR) && ./workflow_cmssw.sh $(notdir $(TEST_HEPMC_FINAL)) $(notdir $(TEST_MINIAOD_FINAL)) testRun"


$(TEST_HEPMC_FINAL): hepmcConcat $(TEST_HEPMC)
	$(PYTHIA8_HEPMC2_SINGULARITY) --command-to-run \
		"source $(PYTHIA8_HEPMC2_ENV_SCRIPT) && ./hepmcConcat $(TEST_HEPMC_FINAL) $(TEST_HEPMC) "

$(TEST_DIR)/%.hepmc: $(TEST_DIR)/%.lhe Pythia8.exe $(TEST_DIR)/Pythia8_lhe.cmnd
	@mkdir -p $(dir $@)
	# Run Pythia in the container, write to a temporary file and move atomically
	$(PYTHIA8_HEPMC2_SINGULARITY) --command-to-run \
		"source $(PYTHIA8_HEPMC2_ENV_SCRIPT) && ./Pythia8.exe --lhef $(TEST_DIR)/$*.lhe --cmnd $(TEST_DIR)/Pythia8_lhe.cmnd --output $@" || \
		echo "Pythia 8 exception caught."


$(TEST_DIR)/Pythia8_lhe.cmnd: Pythia8_lhe.cmnd
	@mkdir -p $(dir $@)
	# Only update the copied cmnd when the source is newer to avoid changing timestamps
	if [ ! -f $@ ] || [ "$<" -nt "$@" ]; then \
		cp $< $@; \
	fi

$(TEST_DIR)/$(TEST_LHE_PREFIX)%.lhe: $(TEST_LHE_SOURCE)
	@mkdir -p $(dir $@)
	# The splitter produces all pieces in one invocation. Only run it if this piece
	# does not yet exist to avoid re-running and touching timestamps of existing pieces.
	if [ ! -f $@ ]; then \
		$(LHE_SPLIT_EXECUTABLE) -i $(TEST_LHE_SOURCE) -o $(TEST_DIR) -n $(NUM_SPLITS) --file-prefix $(TEST_LHE_PREFIX) --file-width $(NUM_SPLIT_DIGITS) -seq; \
	fi

hepmcConcat: hepmcConcat.cpp
	$(PYTHIA8_HEPMC2_SINGULARITY) --command-to-run \
		"source $(PYTHIA8_HEPMC2_ENV_SCRIPT) && $(CXX) $(CXXFLAGS) $(HEPMC2_INCLUDES) -o $@ hepmcConcat.cpp $(HEPMC2_LIBS)"

Pythia8.exe: Pythia82.cc
	$(PYTHIA8_HEPMC2_SINGULARITY) --command-to-run \
		"source $(PYTHIA8_HEPMC2_ENV_SCRIPT) && $(CXX) $(CXXFLAGS) $(HEPMC2_INCLUDES) $(PYTHIA8_INCLUDES) -o $@ Pythia82.cc $(HEPMC2_LIBS) $(PYTHIA8_LIBS)"
