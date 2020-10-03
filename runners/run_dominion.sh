#!/bin/bash

pushd "${TARGET}/dominion"
    PYTHONPATH="${TARGET}"/dominion:"${TARGET}"/shirow:"$(pwd)"
    export PYTHONPATH

    "${TARGET}"/dominion-env/bin/python bin/server.py \
        --build-log-dir="${TARGET}"/dominion-workspace \
        --log-file-prefix="${TARGET}"/dominion.log \
        --port="${DOMINION_PORT}" \
        --token-key="${SECRET_KEY}" \
        --logging=debug
popd
