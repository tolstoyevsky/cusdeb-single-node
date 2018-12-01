# Copyright (C) 2018 Evgeny Golyshev <eugulixes@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

check_dependencies() {
    local executables=(curl docker nc pkg-config pandoc python3 supervisord virtualenv)
    local python_dev_installed=false

    for executable in "${executables[@]}"; do
        if ! which "${executable}" > /dev/null; then
            fatal "could not find ${executable}"
            exit 1
        fi
    done

    if ! check_python_version; then
        fatal "Python ${PYTHON_MAJOR_VER}.${PYTHON_MINOR_VER} or higher is required"
        exit 1
    fi

    for minor_ver in ${PYTHON_DEV_MINOR_VER[@]}; do
        if [ ! -z "$(pkg-config --libs "python-${PYTHON_MAJOR_VER}.${minor_ver}" 2> /dev/null)" ]; then
            python_dev_installed=true
            break
        fi
    done

    if ! ${python_dev_installed}; then
        fatal "header files and a static library for Python are not installed"
        exit 1
    fi

    if [ -z "$(pkg-config --libs libpq 2> /dev/null)" ]; then
        fatal "header files for PostgreSQL are not installed"
        exit 1
    fi
}

check_if_cusdeb_single_node_is_installed() {
    if [ ! -f cusdeb ]; then
        fatal "cusdeb-single-node hasn't been installed yet."

        exit 1
    fi
}

check_ports() {
    local ports=(
        ${PROXY_PORT}
        ${DASHBOARD_PORT}
        ${BM_PORT}
        ${DOMINION_PORT}
        ${MONGO_PORT}
        ${POSGRESQL_PORT}
        ${RABBITMQ_PORT}
        ${REDIS_PORT}
    )

    for port in "${ports[@]}"; do
        if is_port_in_use "${port}"; then
            fatal "port ${port} is in use";
            exit 1
        fi

        success "port ${port} is available"
    done
}

clone_git_repos() {
    local github=(
        blackmagic
        django-cusdeb-firmwares
        dominion
        pieman
        shirow
    )
    local bitbucket=(
        appleseed
        django-cusdeb-users
        dashboard
    )

    for service in ${github[@]}; do
        info "cloning ${service}"
        sudo -u "${USER}" git clone https://github.com/tolstoyevsky/"${service}".git "${TARGET}/${service}"
    done

    for service in ${bitbucket[@]}; do
        info "cloning ${service}"
        sudo -u "${USER}" git clone git@bitbucket.org:cusdeb/"${service}".git "${TARGET}/${service}"
    done
}

comment_by_pattern() {
    local pattern=$1
    local f=$2

    while read -r line; do
        if [[ ${line} == *"${pattern}"* ]]; then
            sed -i "s/${line//\//\\/}/#${line//\//\\/}/g" ${f}
        fi
    done < ${f}
}

create_virtenvs() {
    local envs=(
        appleseed-env
        blackmagic-env
        dashboard-env
        dominion-env
        pieman-env
    )

    for env in ${envs[@]}; do
        info "creating ${env} virtual environment"
        sudo -u "${USER}" virtualenv -p python3 "${TARGET}/${env}"
    done
}

export_node_envs() {
    export PATH=${PATH}:"${TARGET}"/node/bin

    export NODE_PATH="${TARGET}"/node/lib/node_modules
}

get_state() {
    local f="$(pwd)/current-build-state"

    if [ ! -f "${f}" ]; then
        echo "init"
    else
        cat "${f}"
    fi
}

install_requirements_to_virtenvs() {
    services=(
        appleseed
        blackmagic
        dashboard
        dominion
    )

    for service in ${services[@]}; do
        info "installing requirements to ${service}-env"
        sudo -u "${USER}" "${TARGET}/${service}"-env/bin/pip install pip=="${PIP_VER}"
        sudo -u "${USER}" "${TARGET}/${service}"-env/bin/pip install -r "${TARGET}/${service}"/requirements.txt
    done

    # django-cusdeb-users is used as an external dependency for Dashboard.
    # However, django-cusdeb-users doesn't have requirements.txt.
    sudo -u "${USER}" "${TARGET}"/dashboard-env/bin/pip install pyjwt redis

    # Shirow is used as an external dependency for BlackMagic and Dominion
    sudo -u "${USER}" "${TARGET}"/blackmagic-env/bin/pip install -r "${TARGET}"/shirow/requirements.txt

    sudo -u "${USER}" "${TARGET}"/dominion-env/bin/pip install -r "${TARGET}"/shirow/requirements.txt

    info "installing requirements to pieman-env"
    sudo -u "${USER}" "${TARGET}"/pieman-env/bin/pip install -r "${TARGET}"/pieman/pieman/requirements.txt

    pushd "${TARGET}"/pieman/pieman
        sudo -u "${USER}" ${TARGET}/pieman-env/bin/python setup.py build
        sudo -u "${USER}" ${TARGET}/pieman-env/bin/python setup.py install
    popd
}

run_containers() {
    #
    # MongoDB
    #
    docker pull mongo:"${MONGO_TAG}"
    docker run --name cusdeb-mongo -v "${VOLUME_PREFIX}"/mongodb:/data/db -p "${MONGO_PORT}":27017 -d mongo:"${MONGO_TAG}"
    wait_for "${MONGO_PORT}"
    #
    # PostgreSQL
    #
    docker pull "postgres:${PG_TAG}"
    docker run --name cusdeb-postgres -e POSTGRES_PASSWORD="${PG_PASSWORD}" -v "${VOLUME_PREFIX}"/postgres:/var/lib/postgresql/data -p "${PG_PORT}":5432 -d postgres:"${PG_TAG}"
    wait_for "${PG_PORT}"

    #
    # RabbitMQ
    #

    docker pull rabbitmq:"${RABBITMQ_TAG}"
    docker run -d --hostname my-rabbit --name cusdeb-rabbit -e RABBITMQ_ERLANG_COOKIE='secret' -p "${RABBITMQ_PORT}":5672 rabbitmq:"${RABBITMQ_TAG}"
    wait_for "${RABBITMQ_PORT}"

    #
    # Redis
    #
    docker pull redis:"${REDIS_TAG}"
    docker run --name cusdeb-redis -p "${REDIS_PORT}":6379 -d redis:"${REDIS_TAG}"
    wait_for "${REDIS_PORT}"
}

run_manage_py() {
    check_if_cusdeb_single_node_is_installed

    TARGET="$(cat cusdeb)"

    pushd "${TARGET}"/dashboard
        env PYTHONPATH="${TARGET}/django-cusdeb-firmwares:${TARGET}/django-cusdeb-users:$(pwd)" \
            ${TARGET}/dashboard-env/bin/python manage.py "$@"
    popd
}

stop_container() {
    local container=$1

    if docker ps -a | grep --quiet "${container}"; then
        info "stopping and removing container ${container}"
        docker stop "${container}"
        docker rm "${container}"
    else
        info "container ${container} is not running"
    fi
}

stop_containers() {
    containers=(
        cusdeb-postgres
        cusdeb-mongo
        cusdeb-rabbit
        cusdeb-redis
    )

    for container in ${containers[@]}; do
        stop_container "${container}"
    done
}

run_daemons() {
    env PATH="${TARGET}/dominion-dev/bin:$(pwd)"/runners:"${PATH}" supervisord -c config/supervisord.conf
}

stop_daemons() {
    for pid in $(sudo supervisorctl -c ./config/supervisord.conf pid all); do
        # If a process is stopped, supervisorctl shows that the pid of the
        # process is 0. It's not what we need.
        if [[ "${pid}" > 0 ]]; then
            info "killing ${pid}"
            kill -9 -"${pid}"
        fi
    done

    kill -9 "$(sudo supervisorctl -c ./config/supervisord.conf pid)"
}

switch_state_to() {
    local state=$1

    echo "${state}" > "$(pwd)/current-build-state"
}

wait_for() {
    local port=$1

    info "wait while port ${port} is ready to accept incoming connections"
    ./wait-for-it.sh -h "127.0.0.1" -p "${port}" -t 90 -- >&2 echo "done"
}
