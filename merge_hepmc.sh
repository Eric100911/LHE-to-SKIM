#!/bin/bash
# Merge multiple HepMC files into a single file
# Usage: ./merge_hepmc.sh <output_file> <input_files...>

set -e

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <output_file> <input_file1> [input_file2 ...]"
    echo ""
    echo "Merges multiple HepMC files into a single output file."
    echo "Handles both compressed (.gz) and uncompressed files."
    exit 1
fi

OUTPUT_FILE="$1"
shift
INPUT_FILES=("$@")

echo "==================================================================="
echo "Merging HepMC files"
echo "==================================================================="
echo "Output file: ${OUTPUT_FILE}"
echo "Number of input files: ${#INPUT_FILES[@]}"
echo "==================================================================="

# Check if output file already exists
if [ -f "${OUTPUT_FILE}" ]; then
    echo "WARNING: Output file ${OUTPUT_FILE} already exists. Removing it."
    rm -f "${OUTPUT_FILE}"
fi

# Temporary file for tracking if we've written the header
HEADER_WRITTEN=0
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

# Process each input file
FILE_COUNT=0
EVENT_COUNT=0

for INPUT_FILE in "${INPUT_FILES[@]}"; do
    if [ ! -f "${INPUT_FILE}" ]; then
        echo "WARNING: Input file ${INPUT_FILE} not found. Skipping..."
        continue
    fi
    
    FILE_COUNT=$((FILE_COUNT + 1))
    echo "Processing file ${FILE_COUNT}: ${INPUT_FILE}"
    
    # Determine if file is compressed
    if [[ "${INPUT_FILE}" == *.gz ]]; then
        CAT_CMD="zcat"
    else
        CAT_CMD="cat"
    fi
    
    # Process the file
    if [ ${HEADER_WRITTEN} -eq 0 ]; then
        # First file: write everything
        ${CAT_CMD} "${INPUT_FILE}" >> "${OUTPUT_FILE}"
        HEADER_WRITTEN=1
        echo "  -> Wrote header and events from first file"
    else
        # Subsequent files: skip header, only append events
        # NOTE: This assumes HepMC3 ASCII format where event records start with "E "
        # For HepMC2 format, event records start with "HepMC::IO_GenEvent"
        # If using different HepMC versions, this logic may need adjustment
        ${CAT_CMD} "${INPUT_FILE}" | awk '
            BEGIN { in_events = 0; }
            /^E / { in_events = 1; }
            in_events { print; }
        ' >> "${OUTPUT_FILE}"
        echo "  -> Appended events (skipped header)"
    fi
    
    # Count events in this file
    EVENTS_IN_FILE=$(${CAT_CMD} "${INPUT_FILE}" | grep -c "^E " || echo 0)
    EVENT_COUNT=$((EVENT_COUNT + EVENTS_IN_FILE))
    echo "  -> Events in this file: ${EVENTS_IN_FILE}"
done

echo "==================================================================="
echo "Merge complete"
echo "==================================================================="
echo "Files processed: ${FILE_COUNT}"
echo "Total events   : ${EVENT_COUNT}"
echo "Output file    : ${OUTPUT_FILE}"
echo "==================================================================="

# Optionally compress the output
if [[ "${OUTPUT_FILE}" == *.gz ]]; then
    echo "Output file already has .gz extension, assumed compressed"
elif [ -n "${COMPRESS_OUTPUT}" ]; then
    echo "Compressing output file..."
    gzip "${OUTPUT_FILE}"
    echo "Compressed to: ${OUTPUT_FILE}.gz"
fi
