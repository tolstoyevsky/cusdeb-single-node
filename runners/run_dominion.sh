#!/bin/bash

pushd "${TARGET}/dominion"
    PYTHONPATH="${TARGET}"/dominion:"${TARGET}"/cusdeb-api:"${TARGET}"/shirow:"$(pwd)"
    export PYTHONPATH

    env DJANGO_SETTINGS_MODULE=dominion.settings "${TARGET}"/dominion-env/bin/python bin/server.py \
        --log-file-prefix="${TARGET}"/dominion.log \
        --port="${DOMINION_PORT}" \
        --token-key="${SECRET_KEY}" \
        --logging=debug
popd
