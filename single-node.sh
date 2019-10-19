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

USAGE="USAGE: $0 build <target directory>|compilemessages|create-superuser|dbshell|loaddata|makemessages|makemigrations|migrate|rebuild|remove|restart|shell <service>|start|stop"

if [ -z "$1" ]; then
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
    # localsettings may not exist, so it's necessary to ignore SC1091.
    # shellcheck disable=SC1091
    . ./localsettings
fi

set -x

export HOST=${HOST:=localhost}

export DASHBOARD_PORT=${DASHBOARD_PORT:=8001}

export DJANGO_CONFIGURATION=${DJANGO_CONFIGURATION:=Docker}

export BM_PORT=${BM_PORT:=8002}

export DOMINION_PORT=${DOMINION_PORT:=8003}

export ORION_PORT=${ORION_PORT:=8004}

export MONGO_DATABASE=${MONGO_DATABASE:=cusdeb}

export MONGO_HOST=${MONGO_HOST:=localhost}

export MONGO_PORT=${MONGO_PORT:=33018}

export MONGO_TAG=${MONGO_TAG:=3.2}

export PG_DATABASE=${PG_DATABASE:=cusdeb}

export PG_HOST=${PG_HOST:=localhost}

export PG_PASSWORD=${PG_PASSWORD:=secret}

export PG_PORT=${PG_PORT:=54321}

export PG_TAG=${PG_TAG:=9.4}

export PG_USER=${PG_USER:=postgres}

export RABBITMQ_PORT=${RABBITMQ_PORT:=5672}

export RABBITMQ_TAG=${RABBITMQ_TAG:=3.7}

export REDIS_HOST=${REDIS_HOST=localhost}

export REDIS_PORT=${REDIS_PORT:=63791}

export REDIS_TAG=${REDIS_TAG:=3.2}

export TOKEN_KEY=${TOKEN_KEY:="gl3q^2f^fh)b=&g)*cah9h5n-d#if9k3s1#tnz2hre\$1ea1zd^"}

USER="$(get_owner .)"
export USER

export VOLUME_PREFIX=${VOLUME_PREFIX:=/srv}

set +x

info "checking dependencies"
check_dependencies

#
# Parse params
#

case $1 in
build)
    if [ -f cusdeb ]; then
        fatal "cusdeb-single-node is already installed. Run rebuild command."
        exit 1
    fi

    if [ -z "$2" ]; then
        fatal "target directory is not specified"
        exit 1
    fi

    if [ ! -d "$2" ]; then
        fatal "$2 does not exist"
        exit 1
    fi

    resume_state
    state="$(get_state)"

    TARGET="$(get_absolute_path "$2")"

    build_env "${state}" full

    ;;
rebuild)
    TARGET="$(<cusdeb)"

    if [ -z "$2" ]; then
        recipe=fast

        chroots=(
                "debian-buster-armhf"
                "devuan-jessie-armhf"
                "raspbian-buster-armhf"
                "ubuntu-xenial-armhf"
                "ubuntu-bionic-arm64"
                "ubuntu-bionic-armhf"
                "ubuntu-bionic-arm64-xfce4"
                "ubuntu-bionic-armhf-xfce4"
            )

        for chroot in "${chroots[@]}"; do
            lines="$(find "$TARGET" -maxdepth 1 -name "$chroot"| wc -l)"
            if [ "$lines" -eq 0  ]; then
                fatal "target directory does not have nessesary build - $chroot, so use full rebuild."
                exit 1
            fi
        done
    else
        recipe="$2"
    fi

    resume_state
    state="$(get_state)"

    if [ "${state}" = "init" ] || [ "${state}" = "clone" ]; then
        info "cleaning up"

        case $recipe in
        fast)
            pushd "$TARGET"
                to_be_deleted="$(find . -maxdepth 1 ! -name '*arm64' ! -name '*armhf' ! -name '*.')"

                # shellcheck disable=SC2068
                for item in ${to_be_deleted[@]}; do
                    if [ ! "$item" = "" ]; then
                        rm -r "$item"
                    fi
                done
            popd
            ;;
        full)
            if [ "$(ls -A "$TARGET")" ]; then
                # shellcheck disable=SC2115
                rm -r "$TARGET"/*
            fi
        esac
    fi

    build_env "$state" "$recipe"

    ;;
compilemessages)
    run_manage_py compilemessages -l ru

    ;;
create-superuser)
    run_manage_py createsuperuser

    ;;
dbshell)
    run_manage_py dbshell

    ;;
loaddata)
    if [ -z "$2" ]; then
        fatal "fixture is not specified"
        exit 1
    fi

    run_manage_py loaddata "$2"

    ;;
makemessages)
    run_manage_py makemessages -l ru

    ;;
makemigrations)
    run_manage_py makemigrations

    ;;
migrate)
    run_manage_py migrate

    ;;
remove)
    >&2 echo "stub"
    ;;
restart)
    >&2 echo "stub"
    ;;
shell)
    run_manage_py shell

    ;;
start)
    check_if_cusdeb_single_node_is_installed

    TARGET="$(cat cusdeb)"
    export TARGET

    export_node_envs

    check_ports

    run_containers
    trap "stop_containers && exit 130" 2

    run_daemons

    ;;
stop)
    check_if_cusdeb_single_node_is_installed

    stop_containers

    TARGET="$(cat cusdeb)"
    export TARGET

    stop_daemons

    ;;
*)
    >&2 echo "${USAGE}"
    exit 1
    ;;
esac
