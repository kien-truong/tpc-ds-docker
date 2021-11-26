#!/bin/bash

if [[ "$DEBUG_MODE" == "true" ]]; then
    set -x
fi

cd "$TPC_DS_HOME"

if [[ "$NUM_PARALLEL_JOB" -ge 2 ]]; then
    "$TPC_DS_HOME/dsdgen" -scale "$SCALE_FACTOR" -dir "$OUTPUT_DIR" -parallel "$NUM_PARALLEL_JOB" -child "$JOB_INDEX"
else
    "$TPC_DS_HOME/dsdgen" -scale "$SCALE_FACTOR" -dir "$OUTPUT_DIR"
fi

TPC_DS_FILE_NAME_RE='^([a-zA-Z_]+)_?([0-9_]*)\.dat$'

if [[ "$GOOGLE_APPLICATION_CREDENTIALS" ]] && [[ "$GCS_STORAGE_PREFIX" ]]; then
    "$GCLOUD_SDK_HOME/bin/gcloud" auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS
    for f in $(ls "$OUTPUT_DIR"); do
        [[ $f =~ $TPC_DS_FILE_NAME_RE ]] && TABLE_NAME="${BASH_REMATCH[1]}"
        COMPRESSED_FILE="$f.gz"
        echo "Compressing data: src=$f dest=$COMPRESSED_FILE"
        gzip "$OUTPUT_DIR/$f"
        SRC="$OUTPUT_DIR/$COMPRESSED_FILE"
        DEST="$GCS_STORAGE_PREFIX/$TABLE_NAME/$f.gz"
        echo "Uploading file to Google Cloud. src=$SRC dest=$DEST"
        "$GCLOUD_SDK_HOME/bin/gsutil" cp "$SRC" "$DEST"
    done
fi