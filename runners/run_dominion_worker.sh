#!/bin/bash

pushd "${TARGET}/dominion"
    PYTHONPATH="${TARGET}"/cusdeb-api:"$(pwd)"
    export PYTHONPATH

    export C_FORCE_ROOT=1

    export DJANGO_SETTINGS_MODULE=dominion.settings
    export BUILD_RESULT_PATH="${TARGET}/dominion-workspace"

    "${TARGET}"/dominion-env/bin/celery -A dominion.tasks worker -Q build,email --loglevel=info
popd

