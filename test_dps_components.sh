#!/bin/bash
# Test script for DPS workflow components
# This script tests individual components without requiring full CMSSW setup

set -e

echo "==================================================================="
echo "DPS Workflow Component Tests"
echo "==================================================================="

# Test 1: Build event_splitter
echo ""
echo "Test 1: Building event_splitter..."
make -f Makefile.splitter clean
make -f Makefile.splitter
if [ -f "event_splitter" ]; then
    echo "✓ event_splitter built successfully"
else
    echo "✗ Failed to build event_splitter"
    exit 1
fi

# Test 2: event_splitter help
echo ""
echo "Test 2: Testing event_splitter help..."
./event_splitter --help > /dev/null 2>&1
echo "✓ event_splitter help works"

# Test 3: Create a minimal test LHE file
echo ""
echo "Test 3: Creating minimal test LHE file..."
cat > test_input.lhe << 'EOF'
<LesHouchesEvents version="1.0">
<header>
Test LHE file with 5 events
</header>
<init>
2212 2212 6.500000e+03 6.500000e+03 0 0 0 0 3 1
1.000000e+00 0.000000e+00 1.000000e+00 1
</init>
<event>
2 1 1.0 1.0 1.0 1.0
21 -1 0 0 0 0 0.0 0.0 100.0 100.0 0.0 0.0 9.0
21 -1 0 0 0 0 0.0 0.0 -100.0 100.0 0.0 0.0 9.0
</event>
<event>
2 1 1.0 1.0 1.0 1.0
21 -1 0 0 0 0 0.0 0.0 100.0 100.0 0.0 0.0 9.0
21 -1 0 0 0 0 0.0 0.0 -100.0 100.0 0.0 0.0 9.0
</event>
<event>
2 1 1.0 1.0 1.0 1.0
21 -1 0 0 0 0 0.0 0.0 100.0 100.0 0.0 0.0 9.0
21 -1 0 0 0 0 0.0 0.0 -100.0 100.0 0.0 0.0 9.0
</event>
<event>
2 1 1.0 1.0 1.0 1.0
21 -1 0 0 0 0 0.0 0.0 100.0 100.0 0.0 0.0 9.0
21 -1 0 0 0 0 0.0 0.0 -100.0 100.0 0.0 0.0 9.0
</event>
<event>
2 1 1.0 1.0 1.0 1.0
21 -1 0 0 0 0 0.0 0.0 100.0 100.0 0.0 0.0 9.0
21 -1 0 0 0 0 0.0 0.0 -100.0 100.0 0.0 0.0 9.0
</event>
</LesHouchesEvents>
EOF
echo "✓ Test LHE file created (5 events)"

# Test 4: Split LHE file
echo ""
echo "Test 4: Splitting LHE file into chunks..."
rm -rf test_chunks
./event_splitter \
    --input test_input.lhe \
    --output-dir test_chunks \
    --num-files 2 \
    --file-prefix "chunk_" \
    --sequential

if [ -d "test_chunks" ]; then
    CHUNK_COUNT=$(ls test_chunks/*.lhe 2>/dev/null | wc -l)
    echo "✓ LHE splitting successful (${CHUNK_COUNT} chunks created)"
    
    # Verify events in chunks
    for chunk in test_chunks/*.lhe; do
        EVENT_COUNT=$(grep -c "<event>" "$chunk" || echo 0)
        echo "  - $(basename $chunk): ${EVENT_COUNT} events"
    done
else
    echo "✗ Failed to split LHE file"
    exit 1
fi

# Test 5: Create test HepMC files
echo ""
echo "Test 5: Creating test HepMC files..."
mkdir -p test_hepmc_chunks
cat > test_hepmc_chunks/chunk1.hepmc << 'EOF'
HepMC::Version 3.02.00
HepMC::Asciiv3-START_EVENT_LISTING
E 0 1 2
U GEV MM
A 0 signal_process_id 1
P 1 0 21 0.0 0.0 100.0 100.0 0.0 4
P 2 0 21 0.0 0.0 -100.0 100.0 0.0 4
E 1 1 2
U GEV MM
A 0 signal_process_id 1
P 1 0 21 0.0 0.0 100.0 100.0 0.0 4
P 2 0 21 0.0 0.0 -100.0 100.0 0.0 4
HepMC::Asciiv3-END_EVENT_LISTING
EOF

cat > test_hepmc_chunks/chunk2.hepmc << 'EOF'
HepMC::Version 3.02.00
HepMC::Asciiv3-START_EVENT_LISTING
E 2 1 2
U GEV MM
A 0 signal_process_id 1
P 1 0 21 0.0 0.0 100.0 100.0 0.0 4
P 2 0 21 0.0 0.0 -100.0 100.0 0.0 4
HepMC::Asciiv3-END_EVENT_LISTING
EOF

echo "✓ Test HepMC files created"

# Test 6: Merge HepMC files
echo ""
echo "Test 6: Merging HepMC files..."
./merge_hepmc.sh test_merged.hepmc test_hepmc_chunks/chunk1.hepmc test_hepmc_chunks/chunk2.hepmc

if [ -f "test_merged.hepmc" ]; then
    EVENT_COUNT=$(grep -c "^E " test_merged.hepmc || echo 0)
    echo "✓ HepMC merging successful (${EVENT_COUNT} events in merged file)"
else
    echo "✗ Failed to merge HepMC files"
    exit 1
fi

# Test 7: Test gzip compression/decompression
echo ""
echo "Test 7: Testing HepMC compression..."
cp test_merged.hepmc test_compression.hepmc
ORIGINAL_SIZE=$(wc -c < test_compression.hepmc)
gzip test_compression.hepmc
COMPRESSED_SIZE=$(wc -c < test_compression.hepmc.gz)
COMPRESSION_RATIO=$(echo "scale=1; 100 * (1 - $COMPRESSED_SIZE / $ORIGINAL_SIZE)" | bc)
echo "✓ Compression test successful"
echo "  - Original size   : ${ORIGINAL_SIZE} bytes"
echo "  - Compressed size : ${COMPRESSED_SIZE} bytes"
echo "  - Compression     : ${COMPRESSION_RATIO}% reduction"

gunzip test_compression.hepmc.gz
if [ -f "test_compression.hepmc" ]; then
    echo "✓ Decompression successful"
else
    echo "✗ Decompression failed"
    exit 1
fi

# Test 8: Shell script syntax checks
echo ""
echo "Test 8: Checking shell script syntax..."
bash -n wrapper_dps.sh && echo "✓ wrapper_dps.sh syntax OK"
bash -n merge_hepmc.sh && echo "✓ merge_hepmc.sh syntax OK"
bash -n build_pythia8.sh && echo "✓ build_pythia8.sh syntax OK"

# Test 9: Python configuration syntax
echo ""
echo "Test 9: Checking Python configuration syntax..."
python3 -m py_compile HepMC_GENSIM_13p6TeV_Run3Summer22.py && echo "✓ HepMC_GENSIM config syntax OK"
python3 -m py_compile HadronizerGENSIM_13p6TeV_TuneCP5_pythia8_Run3Summer22.py && echo "✓ HadronizerGENSIM config syntax OK"

# Cleanup
echo ""
echo "Cleaning up test files..."
rm -rf test_chunks test_hepmc_chunks test_input.lhe test_merged.hepmc test_compression.hepmc
echo "✓ Cleanup complete"

echo ""
echo "==================================================================="
echo "All tests passed! ✓"
echo "==================================================================="
echo ""
echo "Notes:"
echo "  - Pythia8 executable build requires CMSSW environment (not tested here)"
echo "  - Full workflow requires cmssw-el7 container and CVMFS access"
echo "  - HTCondor submission requires proper configuration and x509 proxy"
