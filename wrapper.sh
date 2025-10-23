#!/bin/bash

# Arguments: <input_LHE_path> <output_MINIAOD_path> <x509 certificate>
# - Always restrict the name of processed LHE files to $LHE_LOCAL .
INPUT_LHE="$1"
OUTPUT_MINIAOD="$2"
X509_CERT="$3"
LHE_LOCAL="input.lhe"
HOME_DIR=$(pwd)

# Log prefix for output files: extract from the input LHE file name.
LOG_PREFIX=$(basename "$INPUT_LHE" .lhe)

# 1. Configure the x509 certificate
export X509_USER_PROXY="$X509_CERT"

# 2. Set SCRAM architecture for CMSSW_12_X_X and CMSSW_13_X_X
export SCRAM_ARCH=el8_amd64_gcc12

# 3. Set up CMSSW_12_4_14_patch3 for GEN-SIM, RAW, RECO.
source /cvmfs/cms.cern.ch/cmsset_default.sh
scram project -n CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO CMSSW_12_4_14_patch3
cp HadronizerGENSIM_13p6TeV_TuneCP5_pythia8_Run3Summer22.py CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO/src/
cp DIGI_13p6TeV_TuneCP5_pythia8_Run3Summer22.py    CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO/src/
cp RECO_13p6TeV_TuneCP5_pythia8_Run3Summer22.py   CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO/src/
# - Copy the LHE file to the CMSSW source directory also.
cp "$INPUT_LHE"                                                "CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO/src/$LHE_LOCAL"
cd CMSSW_12_4_14_patch3_GEN-SIM-RAW-RECO/src
eval `scram runtime -sh`

# 4. Run the GEN-SIM, RAW, RECO step. Using user-defined configuration all the way.
# - The intermidiate files are stored in the current directory and are designed to link up.
cmsRun HadronizerGENSIM_13p6TeV_TuneCP5_pythia8_Run3Summer22.py -j FrameworkJob_${LOG_PREFIX}_GENSIM.xml
cmsRun DIGI_13p6TeV_TuneCP5_pythia8_Run3Summer22.py    -j FrameworkJob_${LOG_PREFIX}_RAW.xml
cmsRun RECO_13p6TeV_TuneCP5_pythia8_Run3Summer22.py   -j FrameworkJob_${LOG_PREFIX}_RECO.xml
# - The output root file is stored in the current directory.
# - The produced framework output files are moved to $HOME_DIR
# mv FrameworkJob_${LOG_PREFIX}_GENSIM.xml "$HOME_DIR/FrameworkJob_${LOG_PREFIX}_GENSIM.xml"
# mv FrameworkJob_${LOG_PREFIX}_RAW.xml    "$HOME_DIR/FrameworkJob_${LOG_PREFIX}_RAW.xml"
# mv FrameworkJob_${LOG_PREFIX}_RECO.xml   "$HOME_DIR/FrameworkJob_${LOG_PREFIX}_RECO.xml"
mv step3_AOD.root "$HOME_DIR/step3_AOD.root"

# 5. Create a new directory for the MINIAOD step.
# - Unset the "cmsenv" to avoid conflicts.
eval `scram unsetenv -sh`
cd "$HOME_DIR"
scram project -n CMSSW_13_0_13_MINIAOD CMSSW_13_0_13
cp Mini_13p6TeV_TuneCP5_pythia8_Run3Summer22.py CMSSW_13_0_13_MINIAOD/src/
cd CMSSW_13_0_13_MINIAOD/src
eval `scram runtime -sh`

# 6. Move the AOD file to the new directory.
cp "$HOME_DIR/step3_AOD.root" .

# 7. Run the MINIAOD step.
cmsRun Mini_13p6TeV_TuneCP5_pythia8_Run3Summer22.py -j FrameworkJob_${LOG_PREFIX}_MINIAOD.xml

# 8. Collect and send away the output MiniAOD file.
mv step4_MiniAOD.root "$OUTPUT_MINIAOD"

# 9. Collect log files for retrieval.
# mv "FrameworkJob_${LOG_PREFIX}_MINIAOD.xml" "$HOME_DIR/FrameworkJob_${LOG_PREFIX}_MINIAOD.xml"
