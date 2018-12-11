#!/bin/bash

pushd "${TARGET}/orion"
    PYTHONPATH="${TARGET}/shirow:$(pwd)"
    export PYTHONPATH

    env PATH="${PATH}:$(pwd)/bin" "${TARGET}"/orion-env/bin/python ./bin/server.py \
        --log-file-prefix="${TARGET}"/orion.log \
        --logging=debug \
        --port="${ORION_PORT}" \
        --redis-host="${REDIS_HOST}" \
        --redis-port="${REDIS_PORT}" \
        --token-key="${TOKEN_KEY}" \
        --dominion-workspace="${TARGET}"/dominion-workspace
popd
