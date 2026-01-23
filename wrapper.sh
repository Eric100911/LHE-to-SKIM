#!/bin/bash

# Arguments: <INPUT_LHE> <OUTPUT_MINIAOD> <x509 certificate>
# - Always restrict the name of showered output to a fixed name for simplicity.
INPUT_LHE="$1"
OUTPUT_MINIAOD="$2"
X509_CERT="$3"
HEPMC_LOCAL="Pythia8_shower_output.dat"
CMSSW_EL7_ENV_SCRIPT="cmssw-el7_env.sh"
PYTHIA_CMND="Pythia8_lhe.cmnd"
HOME_DIR=$(pwd)

# Log prefix for output files: extract from the input LHE file name.
LOG_PREFIX=$(basename "$INPUT_LHE" .hepmc)
tar -xf cmssw_configs.tar

# 1. Configure the x509 certificate
export X509_USER_PROXY="$X509_CERT"

# 2. Set SCRAM architecture for CMSSW_12_X_X and CMSSW_13_X_X
export SCRAM_ARCH=el8_amd64_gcc12

# 3. Split LHE, shower each and then merge back.
cmssw-el7 --command-to-run \
    "source $CMSSW_EL7_ENV_SCRIPT && \
    ./split_and_shower.sh '$INPUT_LHE' '$PYTHIA_CMND' '$HEPMC_LOCAL'"

# 4. Run the full CMSSW workflow (GEN-SIM -> MiniAOD)
chmod +x workflow_cmssw.sh
./workflow_cmssw.sh "$HEPMC_LOCAL" "$OUTPUT_MINIAOD" "$LOG_PREFIX"

# 5. Clean up (optional, currently handled by job removal)
