#!/bin/bash

pushd "${TARGET}/orion"
    export PYTHONPATH="${TARGET}/shirow:${TARGET}/cusdeb-api:$(pwd)"
    export DJANGO_SETTINGS_MODULE=orion.settings

    env "${TARGET}"/orion-env/bin/python ./bin/server.py \
        --log-file-prefix="${TARGET}"/orion.log \
        --port="${ORION_PORT}" \
        --token-key="${SECRET_KEY}" \
        --logging=debug
popd
