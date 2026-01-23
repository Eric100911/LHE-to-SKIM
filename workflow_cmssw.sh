#!/bin/bash

# Arguments: <INPUT_HEPMC> <OUTPUT_MINIAOD> <LOG_PREFIX>
INPUT_HEPMC="$1"
OUTPUT_MINIAOD="$2"
LOG_PREFIX="$3"
HEPMC_LOCAL="Pythia8_shower_output.dat"
HOME_DIR=$(pwd)

# 1. Ensure SCRAM_ARCH is set
if [ -z "$SCRAM_ARCH" ]; then
    echo "SCRAM_ARCH not set, setting to default el8_amd64_gcc12"
    export SCRAM_ARCH=el8_amd64_gcc12
fi

# 2. Set up CMSSW source environment
if [ -f /cvmfs/cms.cern.ch/cmsset_default.sh ]; then
    source /cvmfs/cms.cern.ch/cmsset_default.sh
else
    echo "CVMFS not available? Continuing hoping environment is set."
fi

# 3. Set up CMSSW_12_4_14_patch3 for GEN-SIM, RAW, RECO.
if [ -d "CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO" ]; then
    echo "CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO already exists. Removing it to start fresh..."
    rm -rf CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO
fi
scram project -n CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO CMSSW_12_4_14_patch3
# Copy config files
# Assuming these files are in HOME_DIR (current dir when script starts)
cp "$HOME_DIR/HepMCtoSIM_Run3Summer22.py"                   CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO/src/
cp "$HOME_DIR/DIGI_13p6TeV_TuneCP5_pythia8_Run3Summer22.py" CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO/src/
cp "$HOME_DIR/RECO_13p6TeV_TuneCP5_pythia8_Run3Summer22.py" CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO/src/

# - Copy the HepMC file to the CMSSW source directory also.
echo ">>> Copying HepMC file ${INPUT_HEPMC}."
cp "$INPUT_HEPMC"                                   "CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO/src/$HEPMC_LOCAL"

cd CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO/src
eval `scram runtime -sh`

# 4. Run the GEN-SIM, RAW, RECO step.
cmsRun HepMCtoSIM_Run3Summer22.py -j FrameworkJob_${LOG_PREFIX}_GENSIM.xml
cmsRun DIGI_13p6TeV_TuneCP5_pythia8_Run3Summer22.py    -j FrameworkJob_${LOG_PREFIX}_RAW.xml
cmsRun RECO_13p6TeV_TuneCP5_pythia8_Run3Summer22.py   -j FrameworkJob_${LOG_PREFIX}_RECO.xml

# The step3_AOD.root is generated in the current src directory
mv step3_AOD.root "$HOME_DIR/step3_AOD.root"

# 5. Create a new directory for the MINIAOD step.
eval `scram unsetenv -sh`
cd "$HOME_DIR"
if [ -d "CMSSW_13_0_13_MINIAOD" ]; then
    echo "CMSSW_13_0_13_MINIAOD already exists. Removing it..."
    rm -rf CMSSW_13_0_13_MINIAOD
fi

scram project -n CMSSW_13_0_13_MINIAOD CMSSW_13_0_13
cp "$HOME_DIR/Mini_13p6TeV_TuneCP5_pythia8_Run3Summer22.py" CMSSW_13_0_13_MINIAOD/src/
cd CMSSW_13_0_13_MINIAOD/src
eval `scram runtime -sh`

# 6. Move the AOD file to the new directory.
cp "$HOME_DIR/step3_AOD.root" .

# 7. Run the MINIAOD step.
cmsRun Mini_13p6TeV_TuneCP5_pythia8_Run3Summer22.py -j FrameworkJob_${LOG_PREFIX}_MINIAOD.xml

# 8. Collect and send away the output MiniAOD file.
echo "Copy output MiniAOD to ${OUTPUT_MINIAOD}"
if [[ "$OUTPUT_MINIAOD" = /* ]]; then
    # Absolute path
    mv step4_MiniAOD.root "$OUTPUT_MINIAOD"
else
    # Relative path, assuming relative to the initial directory (HOME_DIR)
    mv step4_MiniAOD.root "$HOME_DIR/$OUTPUT_MINIAOD"
fi

cd "$HOME_DIR"
