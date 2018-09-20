#!/bin/bash

pushd "${TARGET}/dominion"
    export DJANGO_SETTINGS_MODULE=settings.docker
    export PYTHONPATH="${TARGET}/django-cusdeb-firmwares:${TARGET}/django-cusdeb-users:${TARGET}/dominion:${TARGET}/shirow:$(pwd)"

    "${TARGET}"/dominion-env/bin/python bin/server.py \
        --build-log-dir="${TARGET}"/dominion-workspace \
        --log-file-prefix="${TARGET}"/dominion.log \
        --port="${DOMINION_PORT}" \
        --redis-host="${REDIS_HOST}" \
        --redis-port="${REDIS_PORT}" \
        --token-key="${TOKEN_KEY}" \
        --logging=debug
popd
