#!/bin/bash

pushd "${TARGET}/cusdeb-web-client"
    sudo -u "${USER}" \
        env PATH="${TARGET}"/node/bin:"${PATH}" \
            NODE_PATH="${TARGET}"/node/lib/node_modules \
            \
            CUSDEB_TZ_URL=http://localhost/tz \
            CUSDEB_HELPIK_URL=http://localhost:"${HELPIK_PORT}" \
            CUSDEB_API_URL=http://localhost:"${CUSDEB_API_PORT}" \
            BLACKMAGIC_URL=ws://localhost:"${BM_PORT}"/rpc/token/%token \
            DOMINION_URL=ws://localhost:"${DOMINION_PORT}"/dominion/token/%token \
            PORT="${CUSDEB_WEB_CLIENT_PORT}" \
        npm run dev
popd
