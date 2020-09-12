#!/bin/bash

pushd "${TARGET}/cusdeb-anonymous"    
    env PYTHONPATH="${TARGET}"/cusdeb-anonymous PORT="${ANONYMOUS_PORT}" SECRET_KEY="${SECRET_KEY}" "${TARGET}"/cusdeb-anonymous-env/bin/python bin/server.py
popd
