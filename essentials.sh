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

# shellcheck disable=SC2034
NODE_VER=12.18.3

# shellcheck disable=SC2034
PIP_VER=20.0.2

PYTHON_MAJOR_VER=3

PYTHON_MINOR_VER=5

PYTHON_DEV_MINOR_VER=(5 6 7 8)

text_in_red_color=$(tput setaf 1)

text_in_green_color=$(tput setaf 2)

text_in_yellow_color=$(tput setaf 3)

reset=$(tput sgr0)

# Prints the specified message with the level fatal.
# Globals:
#     None
# Arguments:
#     Message
# Returns:
#     None
fatal() {
    >&2 echo "${text_in_red_color}Fatal${reset}: ${*}"
}

# Prints the specified message with the level info.
# Globals:
#     None
# Arguments:
#     Message
# Returns:
#     None
info() {
    >&2 echo "${text_in_yellow_color}Info${reset}: ${*}"
}

# Prints the specified message with the level success.
# Globals:
#     None
# Arguments:
#     Message
# Returns:
#     None
success() {
    >&2 echo "${text_in_green_color}Success${reset}: ${*}"
}

# Checks if the current Python version is equal or greater than required.
# Globals:
#     PYTHON_MAJOR_VER
#     PYTHON_MINOR_VER
# Arguments:
#     None
# Returns:
#     Boolean
check_python_version() {
    local current_python_version=()

    IFS='.' read -ra current_python_version <<< "$(python3 -V | cut -d' ' -f2)"

    if (("${current_python_version[0]}" >= "${PYTHON_MAJOR_VER}")) && (("${current_python_version[1]}" >= "${PYTHON_MINOR_VER}")); then
        true
    else
        false
    fi
}

exec_with_retries() {
    n=0
    until [ ${n} -ge 5 ]; do
        "$@" && break
        n=$((n + 1))
        info "retrying in 1 sec"
        sleep 1
    done
}

get_absolute_path() {
    readlink -f "$1"
}

get_owner() {
    stat -c "%U" "$1"
}

is_empty_dir() {
    local dir=$1

    if [ -z "$(ls -A "${dir}")" ]; then
        true
    else
        false
    fi
}

is_port_in_use() {
    local port=$1

    if nc -w1 -z 127.0.0.1 "${port}"; then
	    true
    else
        false
    fi
}

prompt() {
    local text=$1

    read -p "${text} (y/n) " -n 1 -r
    echo
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
        true
    else
        false
    fi
}

