#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
    echo 'usage: trace_rank.sh project runner example output_dir' >&2
    exit 2
fi
: "${WNLQG_TRACE_DIR:?set WNLQG_TRACE_DIR to an absolute existing directory}"
rank=${OMPI_COMM_WORLD_RANK:-0}
exec "${FIRSTUSE_JULIA_EXECUTABLE:-julia}" --startup-file=no --threads=1 "--project=$1" "--trace-compile=$WNLQG_TRACE_DIR/rank_$rank.jl" "$2" "$3" "$4"
