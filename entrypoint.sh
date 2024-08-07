#!/bin/bash

EXTENSION="${EXTENSION}"
OPERATION="${OPERATION}"
INPUT_DATA_FOLDER="/usr/src/app/input"
OUTPUT_DATA_FOLDER="/usr/src/app/output"

if [ "$OPERATION" = "deflate" ]; then
    echo "Running cog_deflate operation..."
    python "./scripts/cog_deflate.py" "$INPUT_DATA_FOLDER" "$OUTPUT_DATA_FOLDER"

elif [ "$OPERATION" = "compression" ]; then
    echo "Running compression operation..."
    ./scripts/lossy_comp.sh "$INPUT_DATA_FOLDER" "$OUTPUT_DATA_FOLDER"

else
    echo "Error: Invalid operation specified. Use 'deflate' or 'compression'."
    exit 1 
fi
