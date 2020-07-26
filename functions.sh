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
    local executables=(curl docker nc pkg-config python3 supervisord virtualenv)
    local python_dev_installed=false

    for executable in "${executables[@]}"; do
        if ! command -v "${executable}" > /dev/null; then
            fatal "could not find ${executable}"
            exit 1
        fi
    done

    if ! check_python_version; then
        fatal "Python ${PYTHON_MAJOR_VER}.${PYTHON_MINOR_VER} or higher is required"
        exit 1
    fi

    for minor_ver in "${PYTHON_DEV_MINOR_VER[@]}"; do
        if [ -n "$(pkg-config --libs "python-${PYTHON_MAJOR_VER}.${minor_ver}" 2> /dev/null)" ]; then
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
        "${BM_PORT}"
        "${DOMINION_PORT}"
        "${ORION_PORT}"
        "${MONGO_PORT}"
        "${PG_PORT}"
        "${RABBITMQ_PORT}"
        "${REDIS_PORT}"
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
        appleseed,ng
        blackmagic,ng
        dominion,master
        orion,master
        pieman,master
        shirow,ng
    )

    for service in "${github[@]}"; do
        IFS=',' read -r -a pieces <<< "${service}"

        info "cloning ${pieces[0]}"
        sudo -u "${USER}" git clone -b "${pieces[1]}" https://github.com/tolstoyevsky/"${pieces[0]}".git "${TARGET}/${pieces[0]}"
    done
}

comment_by_pattern() {
    local pattern=$1
    local f=$2

    # Make a copy of the file not to read and write the same file.
    cp "${f}" "${f}.copy"

    while read -r line; do
        if [[ ${line} == *"${pattern}"* ]]; then
            sed -i "s/${line//\//\\/}/#${line//\//\\/}/g" "${f}.copy"
        fi
    done < "${f}"

    mv "${f}.copy" "${f}"
}

create_virtenvs() {
    local envs=(
        appleseed-env
        blackmagic-env
        dominion-env
        orion-env
    )

    for env in "${envs[@]}"; do
        info "creating ${env} virtual environment"
        sudo -u "${USER}" virtualenv -p python3 "${TARGET}/${env}"
    done

    # The Pieman virtual environment is called venv and must be in the Pieman
    # root source tree.
    pushd "${TARGET}/pieman"
        info "creating pieman/venv virtual environment"
        sudo -u "${USER}" virtualenv -p python3 venv
    popd
}

build_env() {
    local state=$1
    local how=$2

    case "${state}" in
    init)
        if [ "${how}" = "full" ]; then
            if ! is_empty_dir "${TARGET}"; then
                fatal "the specified directory is not empty"
                exit 1
            fi
        fi

        info "checking ports"
        check_ports

        info "creating directory for the resolver"
        info "${USER}" "${TARGET}"
        sudo -u "${USER}" mkdir "${TARGET}"/blackmagic-workspace

        info "creating directory for the result images"
        sudo -u "${USER}" mkdir "${TARGET}"/dominion-workspace

        switch_state_to clone

        ;&
    clone)
        info "cloning services git repos"
        clone_git_repos

        # It's necessary to comment some dependencies, so that they would not be
        # installed to virtual environments. All the dependencies will be passed
        # through PYTHONPATH.

        comment_by_pattern dominion "${TARGET}"/blackmagic/requirements.txt
        comment_by_pattern shirow "${TARGET}"/blackmagic/requirements.txt

        comment_by_pattern django-cusdeb-firmwares "${TARGET}"/dominion/requirements.txt
        comment_by_pattern django-cusdeb-users "${TARGET}"/dominion/requirements.txt
        comment_by_pattern shirow "${TARGET}"/dominion/requirements.txt

        comment_by_pattern shirow "${TARGET}"/orion/requirements.txt

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

        sudo -u "${USER}" git -C "${TARGET}"/blackmagic checkout .
        sudo -u "${USER}" git -C "${TARGET}"/dominion checkout .
        sudo -u "${USER}" git -C "${TARGET}"/orion checkout .

        switch_state_to toolset

        ;&
    toolset)
        info "building Pieman toolset"

        if [ "${how}" = "full" ]; then
            info "setting up toolset"
            pushd "${TARGET}"/pieman
                env PREPARE_ONLY_TOOLSET=true ./pieman.sh
            popd
        fi

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

        pushd "${TARGET}"/orion-env/lib/python3.*/site-packages/tornado
            patch -f -p0 < "${cwd}"/patches/prevent_access_control_allow_origin.patch
        popd

        switch_state_to containers

        ;&
    containers)
        info "fetching wait-for-it.sh"
        curl -O https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh
        chmod +x wait-for-it.sh

        run_containers

        if [ "${how}" = "full" ]; then
            exec_with_retries docker run -it --rm --link cusdeb-postgres:postgres -e PGPASSWORD="${PG_PASSWORD}" postgres:"${PG_TAG}" createdb -h postgres -U postgres cusdeb
        fi

        switch_state_to indexes

        ;&
    indexes)
        if [ "${how}" = "full" ]; then
            info "uploading indexes into database "
            distros=(
                "debian,buster,armhf,http://deb.debian.org/debian/,main"
                "raspbian,buster,armhf,http://archive.raspbian.org/raspbian/,main"
                "ubuntu,xenial,armhf,http://ports.ubuntu.com/ubuntu-ports/,main"
                "ubuntu,bionic,armhf,http://ports.ubuntu.com/ubuntu-ports/,main"
                "ubuntu,bionic,arm64,http://ports.ubuntu.com/ubuntu-ports/,main"
                "ubuntu,bionic,armhf,http://ports.ubuntu.com/ubuntu-ports/,universe"
                "ubuntu,bionic,arm64,http://ports.ubuntu.com/ubuntu-ports/,universe"
            )

            for distro in "${distros[@]}"; do
                IFS=',' read -r -a pieces <<< "${distro}"

                "${TARGET}"/appleseed-env/bin/python "${TARGET}"/appleseed/bin/appleseed.py \
                    --mongodb-host="${MONGO_HOST}" \
                    --mongodb-port="${MONGO_PORT}" \
                    --distro="${pieces[0]}" \
                    --suite="${pieces[1]}" \
                    --arch="${pieces[2]}" \
                    --mirror="${pieces[3]}" \
                    --section="${pieces[4]}"
            done
        fi

        switch_state_to migrate

        ;&
    migrate)
        # TODO: invoke 'manage.py migrate' from cusdeb-api

        switch_state_to node

        ;&
    node)
        info "Installing Node.js"
        node=node-v"${NODE_VER}"-linux-x64.tar.xz
        sudo -u "${USER}" curl -o "${TARGET}/${node}" https://nodejs.org/dist/v"${NODE_VER}/${node}"
        sudo -u "${USER}" tar xJf "${TARGET}/${node}" -C "${TARGET}"
        tar=${node%.*}
        dir=${tar%.*}
        sudo -u "${USER}" mv "${TARGET}"/"${dir}" "${TARGET}"/node
        sudo -u "${USER}" rm "${TARGET}"/"${node}"

        switch_state_to chroots

        ;&
    chroots)
        info "creating chroots environments"

        mkdir -p "${TARGET}"/chroots

        if [[ "${how}" == "fast" ]]; then
            pushd "${TARGET}/chroots"
                mkdir "${TARGET}"/pieman/build
                # Create empty directories with chroots names in pieman/build
                # to skip creating those chroots which has already been created.
                find . -maxdepth 1 ! -name 'chroots' ! -name '.' ! -name '..' -exec mkdir "${TARGET}"/pieman/build/{} \;
            popd
        fi

        OS=()

        pushd "${TARGET}"/pieman
            for device_os in devices/*/*; do
                IFS='/' read -r -a pieces <<< "${device_os}"
                os="${pieces[-1]}"
                device="${pieces[-2]}"

                # shellcheck disable=SC2076
                if [[ " ${OS[*]} " =~ " ${os} " ]]; then
                    continue
                fi

                if [[ -d "build/${os}" ]]; then
                    continue
                fi

                OS+=("${os}")

                if ! env CREATE_ONLY_CHROOT=true OS="${os}" PROJECT_NAME="${os}" DEVICE="${device}" ./pieman.sh; then
                    rm -r build/"${os}"
                fi

                mv build/"${os}"/chroot "${TARGET}/chroots/${os}"
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
}

export_node_envs() {
    export PATH=${PATH}:"${TARGET}"/node/bin

    export NODE_PATH="${TARGET}"/node/lib/node_modules
}

get_state() {
    local f

    f="$(pwd)/current-build-state"

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
        dominion
        orion
    )

    for service in "${services[@]}"; do
        info "installing requirements to ${service}-env"
        sudo -u "${USER}" "${TARGET}/${service}"-env/bin/pip install pip=="${PIP_VER}"
        sudo -u "${USER}" "${TARGET}/${service}"-env/bin/pip install -r "${TARGET}/${service}"/requirements.txt
    done

    # Shirow is used as an external dependency for BlackMagic and Dominion

    sudo -u "${USER}" "${TARGET}"/blackmagic-env/bin/pip install -r "${TARGET}"/shirow/requirements.txt

    sudo -u "${USER}" "${TARGET}"/dominion-env/bin/pip install -r "${TARGET}"/shirow/requirements.txt

    sudo -u "${USER}" "${TARGET}"/orion-env/bin/pip install -r "${TARGET}"/shirow/requirements.txt

    info "installing requirements to pieman/venv"
    sudo -u "${USER}" "${TARGET}"/pieman/venv/bin/pip install pieman
}

run_containers() {
    #
    # MongoDB
    #
    if ! docker images mongo:"${MONGO_TAG}" | grep -q mongo; then
        docker pull mongo:"${MONGO_TAG}"
    fi
    docker run --name cusdeb-mongo --rm -v "${TARGET}"/_mongodb:/data/db -p "${MONGO_PORT}":27017 -d mongo:"${MONGO_TAG}"
    wait_for "${MONGO_PORT}"
    #
    # PostgreSQL
    #
    if ! docker images "postgres:${PG_TAG}" | grep -q postgres; then
        docker pull "postgres:${PG_TAG}"
    fi
    docker run --name cusdeb-postgres --rm -e POSTGRES_PASSWORD="${PG_PASSWORD}" -v "${TARGET}"/_postgres:/var/lib/postgresql/data -p "${PG_PORT}":5432 -d postgres:"${PG_TAG}"
    wait_for "${PG_PORT}"

    #
    # RabbitMQ
    #

    if ! docker images rabbitmq:"${RABBITMQ_TAG}" | grep -q rabbitmq; then
        docker pull rabbitmq:"${RABBITMQ_TAG}"
    fi
    docker run -d --hostname my-rabbit --name cusdeb-rabbit --rm -e RABBITMQ_ERLANG_COOKIE='secret' -p "${RABBITMQ_PORT}":5672 rabbitmq:"${RABBITMQ_TAG}"
    wait_for "${RABBITMQ_PORT}"

    #
    # Redis
    #
    if ! docker images redis:"${REDIS_TAG}" | grep -q redis; then
        docker pull redis:"${REDIS_TAG}"
    fi
    docker run --name cusdeb-redis --rm -p "${REDIS_PORT}":6379 -d redis:"${REDIS_TAG}"
    wait_for "${REDIS_PORT}"
}

run_manage_py() {
    check_if_cusdeb_single_node_is_installed

    TARGET="$(cat cusdeb)"

    # TODO: run manage.py from cusdeb-api
}

stop_container() {
    local container=$1

    if docker ps -a | grep --quiet "${container}"; then
        info "stopping and removing container ${container}"
        docker stop "${container}"
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

    for container in "${containers[@]}"; do
        stop_container "${container}"
    done
}

run_daemons() {
    env PATH="${TARGET}/dominion-dev/bin:$(pwd)/runners:${PATH}" supervisord -c config/supervisord.conf
}

stop_daemons() {
    for pid in $(supervisorctl -c ./config/supervisord.conf pid all); do
        # If a process is stopped, supervisorctl shows that the pid of the
        # process is 0. It's not what we need.
        if [[ "${pid}" -gt 0 ]]; then
            info "killing ${pid}"
            kill -9 -"${pid}"
        fi
    done

    kill -9 "$(supervisorctl -c ./config/supervisord.conf pid)"
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

resume_state() {
    state="$(get_state)"
    if [ "${state}" != "init" ] && ! prompt "The build command was interrupted. Do you want to resume it?"; then
        switch_state_to init
    fi
}
