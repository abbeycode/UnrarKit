#!/bin/bash


export UNCOMPRESSED_FILE="$1"
export ARCHIVE_NAME="`dirname $1`/large-archive.rar"

"../Tests/Test Data/bin/rar" a -ep ${ARCHIVE_NAME} ${UNCOMPRESSED_FILE}