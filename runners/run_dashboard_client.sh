#!/bin/bash

pushd "${TARGET}/dashboard/dashboard"
    sudo -u "${USER}" env PATH="${PATH}" \
                      npm install >> "${TARGET}/dashboard-client.log" 2>&1

    sudo -u "${USER}" env PATH="${PATH}" \
                          RPC_ADDR=ws://localhost:"${BM_PORT}"/rpc/token/%token \
                          DOMINION_ADDR=ws://localhost:"${DOMINION_PORT}"/dominion/token/%token \
                      npm run webpack_dev >> "${TARGET}/dashboard-client.log" 2>&1
popd
