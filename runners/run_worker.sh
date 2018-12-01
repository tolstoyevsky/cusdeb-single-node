#!/bin/sh

export C_FORCE_ROOT=1

export DJANGO_SETTINGS_MODULE=settings.docker

export PYTHONPATH="${TARGET}"/dominion:"${TARGET}"/dominion/dominion:"${TARGET}"/django-cusdeb-firmwares:"${TARGET}"/django-cusdeb-users

cd "${TARGET}/dominion/dominion" || exit

"${TARGET}"/dominion-env/bin/celery -A tasks worker \
    --base-systems="${TARGET}" \
    --builder-location="${TARGET}"/pieman \
    --loglevel=info \
    --redis-host="${REDIS_HOST}" \
    --redis-port="${REDIS_PORT}" \
    --workspace="${TARGET}"/dominion-workspace
