#!/bin/bash

pushd "${TARGET}/dominion-workspace"
    python3 -m http.server "${BUILD_RESULT_PORT}"
popd
