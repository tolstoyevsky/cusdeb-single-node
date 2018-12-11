#!/bin/bash

pushd "${TARGET}/dashboard/dashboard"
    # The script is supposed to be run as root, but redirect the output as a
    # regular user, so it's necessary to ignore SC2024.

    # shellcheck disable=SC2024
    sudo -u "${USER}" env PATH="${PATH}" \
                      npm install >> "${TARGET}/dashboard-client.log" 2>&1

    # shellcheck disable=SC2024
    sudo -u "${USER}" env PATH="${PATH}" \
                          RPC_ADDR=ws://localhost:"${BM_PORT}"/rpc/token/%token \
                          DOMINION_ADDR=ws://localhost:"${DOMINION_PORT}"/dominion/token/%token \
                          ORION_ADDR=ws://localhost:"${ORION_PORT}"/orion/token/%token \
                      npm run webpack_dev >> "${TARGET}/dashboard-client.log" 2>&1
popd
