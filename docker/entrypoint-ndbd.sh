#!/bin/bash
set -e

NDB_DAEMON="${NDB_DAEMON:-ndbmtd}"
NDB_MGM_HOSTS="${NDB_MGM_HOSTS:?NDB_MGM_HOSTS must be set}"

ARGS=(
    "--ndb-connectstring=${NDB_MGM_HOSTS}"
    "--nodaemon"
)

# Use explicit node ID if set; otherwise derive from StatefulSet pod ordinal plus
# NDB_NODE_ID_OFFSET (default 1, since NDB node IDs are 1-based).
# StatefulSet pod names have the form <name>-<ordinal>, e.g. ndbd-0, ndbd-2.
if [ -n "${NDB_NODE_ID}" ]; then
    ARGS+=("--ndb-nodeid=${NDB_NODE_ID}")
else
    ORDINAL="${HOSTNAME##*-}"
    if [[ "${ORDINAL}" =~ ^[0-9]+$ ]]; then
        OFFSET="${NDB_NODE_ID_OFFSET:-1}"
        ARGS+=("--ndb-nodeid=$(( ORDINAL + OFFSET ))")
    fi
fi

exec "${NDB_DAEMON}" "${ARGS[@]}" "$@"
