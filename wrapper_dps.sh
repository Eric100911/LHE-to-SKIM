#!/bin/bash
# Enhanced wrapper script for DPS (J/psi+J/psi)+phi(1020) event production
# 
# This script extends the standard LHE-to-SKIM workflow with:
# 1. LHE file splitting into 30-event chunks
# 2. Standalone Pythia8 reshowering with DPS in cmssw-el7 container
# 3. HepMC file merging
# 4. Optional HepMC file retention and compression
# 5. Standard CMSSW workflow (GEN-SIM, DIGI, RECO, MINIAOD)
#
# Arguments: <input_LHE_path> <output_MINIAOD_path> <x509_cert> [--keep-hepmc] [--hepmc-dir <dir>]

set -e  # Exit on error

# =============================================================================
# Parse arguments
# =============================================================================
INPUT_LHE="$1"
OUTPUT_MINIAOD="$2"
X509_CERT="$3"
shift 3

# Optional arguments
KEEP_HEPMC=0
HEPMC_DIR=""
USE_DPS_WORKFLOW=1  # Default: use DPS workflow

while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-hepmc)
            KEEP_HEPMC=1
            shift
            ;;
        --hepmc-dir)
            HEPMC_DIR="$2"
            KEEP_HEPMC=1
            shift 2
            ;;
        --no-dps)
            USE_DPS_WORKFLOW=0
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 <input_LHE> <output_MINIAOD> <x509_cert> [--keep-hepmc] [--hepmc-dir <dir>] [--no-dps]"
            exit 1
            ;;
    esac
done

# =============================================================================
# Setup
# =============================================================================
LHE_LOCAL="input.lhe"
HOME_DIR=$(pwd)
LOG_PREFIX=$(basename "$INPUT_LHE" .lhe)

echo "==================================================================="
echo "LHE to SKIM Wrapper with DPS Support"
echo "==================================================================="
echo "Input LHE      : ${INPUT_LHE}"
echo "Output MiniAOD : ${OUTPUT_MINIAOD}"
echo "Use DPS workflow: ${USE_DPS_WORKFLOW}"
echo "Keep HepMC     : ${KEEP_HEPMC}"
if [ ${KEEP_HEPMC} -eq 1 ]; then
    echo "HepMC directory: ${HEPMC_DIR:-<same as MiniAOD>}"
fi
echo "==================================================================="

# Configure x509 certificate
export X509_USER_PROXY="$X509_CERT"

# Set SCRAM architecture
export SCRAM_ARCH=el8_amd64_gcc12

# Setup CMSSW environment
source /cvmfs/cms.cern.ch/cmsset_default.sh

# =============================================================================
# Copy input LHE file
# =============================================================================
echo ""
echo ">>> Copying LHE file ${INPUT_LHE}..."
cp "$INPUT_LHE" "$LHE_LOCAL"

# =============================================================================
# DPS Workflow: Split LHE, Reshower with Pythia8, Merge HepMC
# =============================================================================
if [ ${USE_DPS_WORKFLOW} -eq 1 ]; then
    echo ""
    echo "==================================================================="
    echo "DPS Workflow: LHE Splitting and Pythia8 Reshowering"
    echo "==================================================================="
    
    # Create directories for splitting and HepMC output
    SPLIT_DIR="${HOME_DIR}/lhe_chunks"
    HEPMC_CHUNKS_DIR="${HOME_DIR}/hepmc_chunks"
    mkdir -p "${SPLIT_DIR}" "${HEPMC_CHUNKS_DIR}"
    
    # Step 1: Split LHE file into 30-event chunks
    echo ""
    echo ">>> Step 1: Splitting LHE file into 30-event chunks..."
    
    # Count events in input file
    EVENT_COUNT=$(grep -c "<event>" "$LHE_LOCAL" || echo 0)
    NUM_CHUNKS=$(( (EVENT_COUNT + 29) / 30 ))  # Round up
    echo "Total events: ${EVENT_COUNT}"
    echo "Number of chunks: ${NUM_CHUNKS}"
    
    if [ ! -f "event_splitter" ]; then
        echo "Building event_splitter..."
        make -f Makefile.splitter
    fi
    
    ./event_splitter \
        --input "$LHE_LOCAL" \
        --output-dir "${SPLIT_DIR}" \
        --num-files "${NUM_CHUNKS}" \
        --file-prefix "chunk_" \
        --sequential
    
    echo "LHE splitting complete. Chunks in: ${SPLIT_DIR}"
    
    # Step 2: Build Pythia8 executable in cmssw-el7 container
    echo ""
    echo ">>> Step 2: Building Pythia8 executable..."
    
    if [ ! -f "pythia8_lhe_to_hepmc" ]; then
        echo "Building Pythia8 executable in cmssw-el7 container..."
        cmssw-el7 --command-to-run "source /cvmfs/cms.cern.ch/cmsset_default.sh && bash build_pythia8.sh"
        
        if [ ! -f "pythia8_lhe_to_hepmc" ]; then
            echo "ERROR: Failed to build pythia8_lhe_to_hepmc"
            exit 1
        fi
    else
        echo "Pythia8 executable already exists"
    fi
    
    # Step 3: Process each chunk with Pythia8 (with error handling)
    echo ""
    echo ">>> Step 3: Reshowering LHE chunks with Pythia8..."
    
    SUCCESSFUL_CHUNKS=0
    FAILED_CHUNKS=0
    
    for CHUNK_FILE in "${SPLIT_DIR}"/chunk_*.lhe; do
        if [ ! -f "$CHUNK_FILE" ]; then
            continue
        fi
        
        CHUNK_NAME=$(basename "$CHUNK_FILE" .lhe)
        HEPMC_OUTPUT="${HEPMC_CHUNKS_DIR}/${CHUNK_NAME}.hepmc"
        
        echo "  Processing ${CHUNK_NAME}..."
        
        # Run Pythia8 in cmssw-el7 container with timeout and error handling
        set +e  # Temporarily disable exit on error
        timeout 300 cmssw-el7 --command-to-run \
            "cd ${HOME_DIR} && ./pythia8_lhe_to_hepmc pythia8_lhe_to_hepmc.cmnd ${CHUNK_FILE} ${HEPMC_OUTPUT}" \
            > "${HOME_DIR}/pythia8_${CHUNK_NAME}.log" 2>&1
        EXIT_CODE=$?
        set -e
        
        if [ ${EXIT_CODE} -eq 0 ] && [ -f "${HEPMC_OUTPUT}" ]; then
            echo "    -> Success"
            SUCCESSFUL_CHUNKS=$((SUCCESSFUL_CHUNKS + 1))
            
            # Compress HepMC chunk to save space
            if [ -f "${HEPMC_OUTPUT}" ]; then
                gzip "${HEPMC_OUTPUT}"
                echo "    -> Compressed to ${HEPMC_OUTPUT}.gz"
            fi
        else
            echo "    -> FAILED (exit code: ${EXIT_CODE})"
            FAILED_CHUNKS=$((FAILED_CHUNKS + 1))
            # Continue processing other chunks
        fi
    done
    
    echo ""
    echo "Reshowering complete:"
    echo "  Successful chunks: ${SUCCESSFUL_CHUNKS}"
    echo "  Failed chunks    : ${FAILED_CHUNKS}"
    
    if [ ${SUCCESSFUL_CHUNKS} -eq 0 ]; then
        echo "ERROR: No chunks were successfully processed!"
        exit 1
    fi
    
    # Step 4: Merge HepMC files
    echo ""
    echo ">>> Step 4: Merging HepMC chunks..."
    
    MERGED_HEPMC="${HOME_DIR}/merged_output.hepmc"
    
    # Collect all successful HepMC chunks
    HEPMC_FILES=($(ls "${HEPMC_CHUNKS_DIR}"/chunk_*.hepmc.gz 2>/dev/null || true))
    
    if [ ${#HEPMC_FILES[@]} -eq 0 ]; then
        echo "ERROR: No HepMC files to merge!"
        exit 1
    fi
    
    echo "Merging ${#HEPMC_FILES[@]} HepMC files..."
    ./merge_hepmc.sh "${MERGED_HEPMC}" "${HEPMC_FILES[@]}"
    
    # Compress merged HepMC file
    gzip "${MERGED_HEPMC}"
    echo "Compressed merged HepMC to: ${MERGED_HEPMC}.gz"
    
    # Use the merged HepMC for CMSSW workflow
    CMSSW_INPUT="${MERGED_HEPMC}.gz"
    USE_HEPMC_INPUT=1
    
    echo ""
    echo "==================================================================="
    echo "DPS workflow complete. HepMC file ready for CMSSW."
    echo "==================================================================="
    
else
    # Standard workflow without DPS
    CMSSW_INPUT="$LHE_LOCAL"
    USE_HEPMC_INPUT=0
fi

# =============================================================================
# CMSSW Workflow: GEN-SIM, DIGI, RECO, MINIAOD
# =============================================================================
echo ""
echo "==================================================================="
echo "CMSSW Workflow"
echo "==================================================================="

# Create CMSSW area for GEN-SIM, DIGI, RECO
scram project -n CMSSW_12_4_14_patch3_GEN-SIM-DIGI-RECO CMSSW_12_4_14_patch3

# Copy configuration files
if [ ${USE_HEPMC_INPUT} -eq 1 ]; then
    cp HepMC_GENSIM_13p6TeV_Run3Summer22.py CMSSW_12_4_14_patch3_GEN-SIM-DIGI-RECO/src/
    GENSIM_CONFIG="HepMC_GENSIM_13p6TeV_Run3Summer22.py"
    
    # Decompress HepMC for CMSSW (CMSSW might not handle .gz directly)
    gunzip -c "${CMSSW_INPUT}" > CMSSW_12_4_14_patch3_GEN-SIM-DIGI-RECO/src/input.hepmc
else
    cp HadronizerGENSIM_13p6TeV_TuneCP5_pythia8_Run3Summer22.py CMSSW_12_4_14_patch3_GEN-SIM-DIGI-RECO/src/
    GENSIM_CONFIG="HadronizerGENSIM_13p6TeV_TuneCP5_pythia8_Run3Summer22.py"
    cp "$LHE_LOCAL" CMSSW_12_4_14_patch3_GEN-SIM-DIGI-RECO/src/
fi

cp DIGI_13p6TeV_TuneCP5_pythia8_Run3Summer22.py CMSSW_12_4_14_patch3_GEN-SIM-DIGI-RECO/src/
cp RECO_13p6TeV_TuneCP5_pythia8_Run3Summer22.py CMSSW_12_4_14_patch3_GEN-SIM-DIGI-RECO/src/

cd CMSSW_12_4_14_patch3_GEN-SIM-DIGI-RECO/src
eval `scram runtime -sh`

# Run GEN-SIM, DIGI, RECO steps
echo ""
echo ">>> Running GEN-SIM step..."
cmsRun ${GENSIM_CONFIG} -j FrameworkJob_${LOG_PREFIX}_GENSIM.xml

echo ""
echo ">>> Running DIGI step..."
cmsRun DIGI_13p6TeV_TuneCP5_pythia8_Run3Summer22.py -j FrameworkJob_${LOG_PREFIX}_DIGI.xml

echo ""
echo ">>> Running RECO step..."
cmsRun RECO_13p6TeV_TuneCP5_pythia8_Run3Summer22.py -j FrameworkJob_${LOG_PREFIX}_RECO.xml

mv step3_AOD.root "$HOME_DIR/step3_AOD.root"

# Unset CMSSW environment
eval `scram unsetenv -sh`
cd "$HOME_DIR"

# Create CMSSW area for MINIAOD
scram project -n CMSSW_13_0_13_MINIAOD CMSSW_13_0_13
cp Mini_13p6TeV_TuneCP5_pythia8_Run3Summer22.py CMSSW_13_0_13_MINIAOD/src/
cd CMSSW_13_0_13_MINIAOD/src
eval `scram runtime -sh`

cp "$HOME_DIR/step3_AOD.root" .

echo ""
echo ">>> Running MINIAOD step..."
cmsRun Mini_13p6TeV_TuneCP5_pythia8_Run3Summer22.py -j FrameworkJob_${LOG_PREFIX}_MINIAOD.xml

# =============================================================================
# Output file handling
# =============================================================================
echo ""
echo "==================================================================="
echo "Output File Handling"
echo "==================================================================="

# Copy MiniAOD output
echo ">>> Copying MiniAOD output to ${OUTPUT_MINIAOD}..."
mv step4_MiniAOD.root "$OUTPUT_MINIAOD"
echo "MiniAOD output complete: ${OUTPUT_MINIAOD}"

# Handle HepMC file if requested
if [ ${USE_DPS_WORKFLOW} -eq 1 ] && [ ${KEEP_HEPMC} -eq 1 ]; then
    echo ""
    echo ">>> Saving HepMC file..."
    
    # Determine HepMC output location
    if [ -z "${HEPMC_DIR}" ]; then
        # Same directory as MiniAOD, just change extension
        HEPMC_OUTPUT="${OUTPUT_MINIAOD%.root}.hepmc.gz"
    else
        # Specified directory
        mkdir -p "${HEPMC_DIR}"
        HEPMC_FILENAME=$(basename "${OUTPUT_MINIAOD%.root}.hepmc.gz")
        HEPMC_OUTPUT="${HEPMC_DIR}/${HEPMC_FILENAME}"
    fi
    
    cp "${HOME_DIR}/merged_output.hepmc.gz" "${HEPMC_OUTPUT}"
    echo "HepMC file saved: ${HEPMC_OUTPUT}"
    
    # File size information
    HEPMC_SIZE=$(du -h "${HEPMC_OUTPUT}" | cut -f1)
    echo "HepMC file size: ${HEPMC_SIZE}"
    echo ""
    echo "NOTE: HepMC files are compressed with gzip."
    echo "      To use them, decompress first: gunzip <file>.hepmc.gz"
    echo "      Compressed format reduces storage by ~70-80%"
    echo "      but requires decompression before reading (adds I/O overhead)"
fi

echo ""
echo "==================================================================="
echo "Workflow Complete"
echo "==================================================================="
echo "MiniAOD output: ${OUTPUT_MINIAOD}"
if [ ${USE_DPS_WORKFLOW} -eq 1 ] && [ ${KEEP_HEPMC} -eq 1 ]; then
    echo "HepMC output  : ${HEPMC_OUTPUT}"
fi
echo "==================================================================="
