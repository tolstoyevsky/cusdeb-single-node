#!/bin/bash

pushd "${TARGET}/blackmagic"
    export DJANGO_SETTINGS_MODULE=settings.prod

    PYTHONPATH="${TARGET}"/blackmagic:"${TARGET}"/shirow:"$(pwd)"
    export PYTHONPATH

    "${TARGET}"/blackmagic-env/bin/python bin/server.py \
        --base-systems-path="${TARGET}" \
        --dominion-workspace="${TARGET}"/dominion-workspace \
        --log-file-prefix="${TARGET}"/blackmagic.log \
        --max-builds-number=1 \
        --mongodb-host="${MONGO_HOST}" \
        --mongodb-port="${MONGO_PORT}" \
        --port="${BM_PORT}" \
        --token-key="${TOKEN_KEY}" \
        --logging=debug 2>> "${TARGET}"/blackmagic.log
popd
