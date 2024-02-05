#!/bin/bash

USERSCRIPT=$HOME/stop-cluster.sh

if [ -x "$USERSCRIPT" ]; then
    exec "$USERSCRIPT" "$@"
fi
