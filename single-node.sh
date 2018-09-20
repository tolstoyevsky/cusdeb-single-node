#!/bin/bash
# Copyright 2018 Evgeny Golyshev. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

USAGE="USAGE: $0 build <target directory>|compilemessages|create-superuser|dbshell|makemessages|makemigrations|migrate|remove|restart|shell <service>|start|stop"

if [ -z $1 ]; then
    >&2 echo "${USAGE}"
    exit 1
fi

if [ "$(id -u)" != "0" ]; then
    >&2 echo "This script must be run as root"
    exit 1
fi

. ./essentials.sh

. ./functions.sh

if [ -f localsettings ]; then
    . ./localsettings
fi

set -x

export HOST=${HOST:=localhost}

PROXY_PORT=${PROXY_PORT:=8000}

DASHBOARD_PORT=${DASHBOARD_PORT:=8001}

BM_PORT=${BM_PORT:=8002}

DOMINION_PORT=${DOMINION_PORT:=8003}

MONGO_DATABASE=${MONGO_DATABASE:=cusdeb}

MONGO_HOST=${MONGO_HOST:=localhost}

MONGO_PORT=${MONGODB_PORT:=33018}

MONGO_TAG=${MONGO_TAG:=3.2}

PG_DATABASE=${PG_DATABASE:=cusdeb}

PG_HOST=${PG_HOST:=localhost}

PG_PASSWORD=${PG_PASSWORD:=secret}

PG_PORT=${PG_PORT:=54321}

PG_TAG=${POSGRESQL_TAG:=9.4}

PG_USER=${PG_USER:=postgres}

RABBITMQ_PORT=${RABBITMQ_PORT:=5672}

RABBITMQ_TAG=${RABBITMQ_PORT:=3.7}

REDIS_HOST=${REDIS_HOST=localhost}

REDIS_PORT=${REDIS_PORT:=63791}

REDIS_TAG=${REDIS_TAG:=3.2}

TOKEN_KEY=${TOKEN_KEY:=secret}

USER="$(get_owner .)"

set +x

if [ -f cusdeb ]; then
    TARGET="$(cat cusdeb)"

    export_main_envs
fi

run_scripts "helpers"

info "checking dependencies"
check_dependencies

#
# Parse params
#

case $1 in
build)
    if [ -f cusdeb ]; then
        fatal "cusdeb-single-node is already installed. Run the script with remove param before running build."
        exit 1
    fi

    if [ -z $2 ]; then
        fatal "target directory is not specified"
        exit 1
    fi

    if [ ! -d $2 ]; then
        fatal "$2 does not exist"
        exit 1
    fi

    state="$(get_state)"
    if [ "${state}" != "init" ] && ! prompt "The build command was interrupted. Do you want to resume it?"; then
        switch_state_to init
        state="$(get_state)"
    fi

    TARGET="$(get_absolute_path $2)"

    export_main_envs

    case "${state}" in
    init)
        if ! is_empty_dir "${TARGET}"; then
            fatal "the specified directory is not empty"
            exit 1
        fi

        info "checking ports"
        check_ports

        info "creating directory for the resolver"
        sudo -u "${USER}" mkdir "${TARGET}"/blackmagic-workspace

        info "creating directory for the result images"
        sudo -u "${USER}" mkdir "${TARGET}"/dominion-workspace

        switch_state_to clone

        ;&
    clone)
        info "cloning services git repos"
        clone_git_repos

        info "cloning debootstap git repo"
        pushd "${TARGET}"/pieman
            sudo -u "${USER}" git clone https://anonscm.debian.org/git/d-i/debootstrap.git
            sudo -u "${USER}" git -C debootstrap checkout "${DEBOOTSTRAP_VER}"
        popd

        # It's necessary to comment some dependencies, so that they would not be
        # installed to virtual environments. All the dependencies will be passed
        # through PYTHONPATH.
        comment_by_pattern django-cusdeb-firmwares "${TARGET}"/dashboard/requirements.txt
        comment_by_pattern django-cusdeb-users "${TARGET}"/dashboard/requirements.txt

        comment_by_pattern django-cusdeb-firmwares "${TARGET}"/blackmagic/requirements.txt
        comment_by_pattern django-cusdeb-users "${TARGET}"/blackmagic/requirements.txt
        comment_by_pattern dominion "${TARGET}"/blackmagic/requirements.txt
        comment_by_pattern shirow "${TARGET}"/blackmagic/requirements.txt

        comment_by_pattern django-cusdeb-firmwares "${TARGET}"/dominion/requirements.txt
        comment_by_pattern django-cusdeb-users "${TARGET}"/dominion/requirements.txt
        comment_by_pattern shirow "${TARGET}"/dominion/requirements.txt

        pushd "${TARGET}"/blackmagic
            cp settings/prod.py.template settings/prod.py
            sed -i -e "s/{MONGO_DATABASE}/${MONGO_DATABASE}/" settings/prod.py
            sed -i -e "s/{MONGO_HOST}/${MONGO_HOST}/" settings/prod.py
            sed -i -e "s/{MONGO_PORT}/${MONGO_PORT}/" settings/prod.py
            sed -i -e "s/{PG_DATABASE}/${PG_DATABASE}/" settings/prod.py
            sed -i -e "s/{PG_HOST}/${PG_HOST}/" settings/prod.py
            sed -i -e "s/{PG_PASSWORD}/${PG_PASSWORD}/" settings/prod.py
            sed -i -e "s/{PG_PORT}/${PG_PORT}/" settings/prod.py
            sed -i -e "s/{PG_USER}/${PG_USER}/" settings/prod.py
        popd

        switch_state_to virtenv

        ;&
    virtenv)
        info "creating virtual environments"
        create_virtenvs

        switch_state_to requirements

        ;&
    requirements)
        info "installing requirements to virtual environments"
        install_requirements_to_virtenvs

        # Undo commenting the dependencies
        sudo -u "${USER}" git -C "${TARGET}"/dashboard checkout .
        sudo -u "${USER}" git -C "${TARGET}"/blackmagic checkout .
        sudo -u "${USER}" git -C "${TARGET}"/dominion checkout .

        switch_state_to patch

        ;&
    patch)
        info "patching Tornado"

        cwd="$(pwd)"
        pushd "${TARGET}"/blackmagic-env/lib/python3.*/site-packages/tornado
            patch -f -p0 < "${cwd}"/patches/prevent_access_control_allow_origin.patch
        popd

        pushd "${TARGET}"/dominion-env/lib/python3.*/site-packages/tornado
            patch -f -p0 < "${cwd}"/patches/prevent_access_control_allow_origin.patch
        popd

        switch_state_to containers

        ;&
    containers)
        info "fetching wait-for-it.sh"
        curl -O https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh
        chmod +x wait-for-it.sh

        run_containers

        exec_with_retries docker run -it --rm --link cusdeb-postgres:postgres -e PGPASSWORD="${PG_PASSWORD}" postgres:"${PG_TAG}" createdb -h postgres -U postgres cusdeb

        switch_state_to indexes

        ;&
    indexes)
        info "uploading indexes into database "
        distros=(
            "devuan,jessie,armhf,http://auto.mirror.devuan.org/merged/"
            "raspbian,stretch,armhf,http://archive.raspbian.org/raspbian/"
            "ubuntu,xenial,armhf,http://ports.ubuntu.com/ubuntu-ports/"
            "ubuntu,bionic,armhf,http://ports.ubuntu.com/ubuntu-ports/"
            "ubuntu,bionic,arm64,http://ports.ubuntu.com/ubuntu-ports/"
        )

        for distro in "${distros[@]}"; do
            IFS=',' read -r -a pieces <<< "${distro}"

            "${TARGET}"/appleseed-env/bin/python "${TARGET}"/appleseed/bin/appleseed.py \
                --mongodb-host="${MONGO_HOST}" \
                --mongodb-port="${MONGO_PORT}" \
                --distro="${pieces[0]}" \
                --suite="${pieces[1]}" \
                --arch="${pieces[2]}" \
                --mirror="${pieces[3]}"
        done

        switch_state_to migrate

        ;&
    migrate)
        pushd "${TARGET}"/dashboard
            ${DASHBOARD_MANAGE_PY} migrate
            ${DASHBOARD_MANAGE_PY} loaddata "${TARGET}"/dashboard/fixtures/account_types.json
        popd

        switch_state_to node

        ;&
    node)
        if [ -z "$(which node)" ]; then
            info "Installing Node.js"
            node=node-v"${NODE_VER}"-linux-x64.tar.xz
            sudo -u "${USER}" curl -o "${TARGET}/${node}" https://nodejs.org/dist/v"${NODE_VER}/${node}"
            sudo -u "${USER}" tar xJvf "${TARGET}/${node}" -C "${TARGET}"
            tar=${node%.*}
            dir=${tar%.*}
            sudo -u "${USER}" mv "${TARGET}"/"${dir}" "${TARGET}"/node
            sudo -u "${USER}" rm "${TARGET}"/"${node}"
        else
            info "Node.js is already installed"
        fi

        switch_state_to chroots

        ;&
    chroots)
        info "creating chroots environments"

        chroots=(
            "devuan-jessie-armhf,rpi-3-b"
            "raspbian-stretch-armhf,rpi-3-b"
            "ubuntu-xenial-armhf,rpi-2-b"
            "ubuntu-bionic-arm64,rpi-3-b"
            "ubuntu-bionic-armhf,rpi-3-b"
        )

        pushd "${TARGET}"/pieman
            for chroot in "${chroots[@]}"; do
                IFS=',' read -r -a pieces <<< "${chroot}"

                env CREATE_ONLY_CHROOT=true \
                    OS="${pieces[0]}" \
                    PROJECT_NAME="${pieces[0]}" \
                    DEVICE="${pieces[1]}" \
                    PYTHON="${TARGET}"/pieman-env/bin/python \
                ./pieman.sh

                mv build/"${pieces[0]}"/chroot "${TARGET}/${pieces[0]}"
            done
        popd

        switch_state_to success

        ;&
    success)
        sudo -u "${USER}" sh -c "echo ${TARGET} > cusdeb"

        switch_state_to init

        stop_containers

        success "development environment is done"

        ;;
    *)
        fatal "unknown state ${state}"
        exit 1
    esac

    ;;
compilemessages)
    export_main_envs

    pushd "${TARGET}"/dashboard
        ${DASHBOARD_MANAGE_PY} compilemessages -l ru
    popd

    ;;
create-superuser)
    export_main_envs

    pushd "${TARGET}"/dashboard
        ${DASHBOARD_MANAGE_PY} createsuperuser
    popd

    ;;
dbshell)
    export_main_envs

    pushd "${TARGET}"/dashboard
        ${DASHBOARD_MANAGE_PY} dbshell
    popd

    ;;
makemessages)
    export_main_envs

    pushd "${TARGET}"/dashboard
        ${DASHBOARD_MANAGE_PY} makemessages -l ru -e html
    popd

    ;;
makemigrations)
    export_main_envs

    pushd "${TARGET}"/dashboard
        ${DASHBOARD_MANAGE_PY} makemigrations
    popd

    ;;
migrate)
    export_main_envs

    pushd "${TARGET}"/dashboard
        ${DASHBOARD_MANAGE_PY} migrate
    popd

    ;;
remove)
    >&2 echo "stub"
    ;;
restart)
    >&2 echo "stub"
    ;;
shell)
    export_main_envs

    pushd "${TARGET}"/dashboard
        ${DASHBOARD_MANAGE_PY} shell
    popd

    ;;
start)
    export_main_envs

    export_node_envs

    check_ports

    run_containers

    env PATH="${TARGET}/dominion-dev/bin:$(pwd)"/runners:"${PATH}" \
        BM_PORT="${BM_PORT}" \
        DASHBOARD_PORT="${DASHBOARD_PORT}" \
        DOMINION_PORT="${DOMINION_PORT}" \
        REDIS_HOST="${REDIS_HOST}" \
        REDIS_PORT="${REDIS_PORT}" \
        TARGET="${TARGET}" \
        TOKEN_KEY="${TOKEN_KEY}" \
        USER="${USER}" \
    supervisord -c config/supervisord.conf

    ;;
stop)
    stop_containers

    for pid in $(sudo supervisorctl -c ./config/supervisord.conf pid all); do
        # If a process is stopped, supervisorctl shows that the pid of the
        # process is 0. It's not what we need.
        if [[ "${pid}" > 0 ]]; then
            info "killing ${pid}"
            kill -9 -"${pid}"
        fi
    done

    kill -9 "$(sudo supervisorctl -c ./config/supervisord.conf pid)"

    ;;
*)
    >&2 echo "${USAGE}"
    exit 1
    ;;
esac
