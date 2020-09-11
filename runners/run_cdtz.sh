#!/bin/bash

pushd "${TARGET}/cusdeb-tz"    
    env PYTHONPATH="${TARGET}"/cusdeb-tz PORT="${TZ_PORT}" "${TARGET}"/cusdeb-tz-env/bin/python bin/server.py
popd
