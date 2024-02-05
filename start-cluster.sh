#!/bin/bash

USERSCRIPT=$HOME/start-cluster.sh

if [ -x "$USERSCRIPT" ]; then
    exec "$USERSCRIPT" "$@"
fi
