#!/bin/bash

pushd "${TARGET}/cusdeb-api"
    "${TARGET}"/cusdeb-api-env/bin/python manage.py runserver 0.0.0.0:"${CUSDEB_API_PORT}" &>> "${TARGET}"/cusdeb-api.log
popd
