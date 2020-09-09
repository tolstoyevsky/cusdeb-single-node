#!/bin/bash

pushd "${TARGET}/cusdeb-helpik"    
    env PYTHONPATH="${TARGET}"/cusdeb-helpik PORT="${HELPIK_PORT}" "${TARGET}"/cusdeb-helpik-env/bin/python bin/server.py
popd
