#!/bin/bash
set -e

NDB_MGMD_DIR="${NDB_MGMD_DIR:-/var/lib/ndb_mgmd}"
NDB_CONFIG_FILE="${NDB_CONFIG_FILE:-/etc/ndb/config.ini}"

mkdir -p "${NDB_MGMD_DIR}"

ARGS=(
    "-f" "${NDB_CONFIG_FILE}"
    "--configdir=${NDB_MGMD_DIR}"
    "--nodaemon"
)

# On first start the configdir is empty; --initial initialises mgmd state.
# On subsequent starts --initial must be omitted to preserve cluster metadata.
if [ -z "$(ls -A "${NDB_MGMD_DIR}")" ]; then
    ARGS+=("--initial")
fi

ORDINAL="${HOSTNAME##*-}"
if [[ "${ORDINAL}" =~ ^[0-9]+$ ]]; then
    OFFSET="${NDB_NODE_ID_OFFSET:-1}"
    ARGS+=("--ndb-nodeid=$(( ORDINAL + OFFSET ))")
fi

exec ndb_mgmd "${ARGS[@]}" "$@"
