#!/bin/bash
# Build script for Pythia8 standalone executable
# This script should be run inside a cmssw-el7 container with CMSSW environment set up

set -e  # Exit on error

echo "==================================================================="
echo "Building Pythia8 LHE to HepMC converter"
echo "==================================================================="

# Setup CMSSW environment
source /cvmfs/cms.cern.ch/cmsset_default.sh

# Check if we're in a CMSSW environment
if [ -z "$CMSSW_BASE" ]; then
    echo "WARNING: CMSSW_BASE not set. Attempting to create CMSSW environment..."
    
    # Set SCRAM architecture
    export SCRAM_ARCH=el8_amd64_gcc12
    
    # Create temporary CMSSW area if not already in one
    if [ ! -d "CMSSW_12_4_14_patch3" ]; then
        scram project -n CMSSW_12_4_14_patch3_BUILD CMSSW_12_4_14_patch3
    fi
    cd CMSSW_12_4_14_patch3_BUILD/src
    eval `scram runtime -sh`
    cd ../..
fi

echo "CMSSW_BASE: $CMSSW_BASE"
echo "SCRAM_ARCH: $SCRAM_ARCH"

# Build the Pythia8 executable
echo ""
echo "Building Pythia8 executable..."
make -f Makefile.pythia8

# Check if build was successful
if [ -f "pythia8_lhe_to_hepmc" ]; then
    echo ""
    echo "==================================================================="
    echo "Build successful!"
    echo "Executable: pythia8_lhe_to_hepmc"
    echo "==================================================================="
    ./pythia8_lhe_to_hepmc 2>&1 | head -5 || true
else
    echo ""
    echo "ERROR: Build failed - executable not found"
    exit 1
fi
