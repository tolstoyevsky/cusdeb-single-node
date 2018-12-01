#!/bin/bash

pushd "${TARGET}/dashboard"
    PYTHONPATH="${TARGET}/django-cusdeb-firmwares:${TARGET}/django-cusdeb-users:$(pwd)"
    export PYTHONPATH

    "${TARGET}"/dashboard-env/bin/python manage.py runserver 0.0.0.0:"${DASHBOARD_PORT}" >> "${TARGET}"/dashboard-server.log 2>&1
popd
