#!/bin/bash

pushd "${TARGET}/blackmagic"
    export DJANGO_SETTINGS_MODULE=settings.prod
    export PYTHONPATH="${TARGET}"/django-cusdeb-firmwares:"${TARGET}"/django-cusdeb-users:"${TARGET}"/dominion:"${TARGET}"/shirow:"$(pwd)"

    "${TARGET}"/blackmagic-env/bin/python bin/blackmagic.py \
        --base-systems-path="${TARGET}" \
        --dominion-workspace="${TARGET}"/dominion-workspace \
        --log-file-prefix="${TARGET}"/blackmagic.log \
        --max-builds-number=1 \
        --mongodb-host="${MONGO_HOST}" \
        --mongodb-port="${MONGO_PORT}" \
        --port="${BM_PORT}" \
        --redis-host="${REDIS_HOST}" \
        --redis-port="${REDIS_PORT}" \
        --token-key="${TOKEN_KEY}" \
        --workspace="${TARGET}"/blackmagic-workspace \
        --logging=debug
popd
