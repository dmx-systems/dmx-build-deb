#!/bin/bash

# This script makes a clone of an existing dm4 instance.
# files we need to touch are
# - /etc/init.d/$INSTANCE
# - /etc/default/${INSTANCE}
# - /etc/deepamehta/${INSTANCE}.conf
# - /etc/deepamehta/${INSTANCE}-logging.conf
#
# Juergen Neumann <juergen.neumann@econauten.de> - Jun. 2017

##  Don't not forget to adjust the ports for http and ws access!



IFS=$'\n'
SOURCE="$1"
TARGET="$2"

function check_root () {
    if [ $( id -u ) -ne 0 ]; then
        echo "ERROR! You must be a root user."
        exit 1
    fi
}

function check_input () {
    if [ -z "${SOURCE}" ] || [ -z "${TARGET}" ]; then
        echo "ERROR! Missing parameters. Enter $0 SOURCE TARGET."
        exit 1
    fi
}

function check_existence () {
    # what are we looking for?
    local INSTANCE="$1"
    declare -a FILES=("/etc/init.d/${INSTANCE}"
        "/etc/default/${INSTANCE}"
        "/etc/deepamehta/${INSTANCE}.conf"
        "/etc/deepamehta/${INSTANCE}-logging.conf")
    for f in ${FILES[@]}; do
    if [ "${INSTANCE}" != "${SOURCE}" ]; then
        if [ -f "${f}" ]; then
        echo "ERROR! Target ${f} exists."
        exit 1
            fi
    elif [ "${INSTANCE}" != "${TARGET}" ]; then
        if [ ! -f "${f}" ]; then
        echo "ERROR! Source ${f} not found."
        exit 1
        fi
    fi
    done
}

function check_running () {
    if [ ! -z "$( ps aux | grep -v grep | grep "${SOURCE}\.conf" )" ]; then
        echo "ERROR! Found instance of ${SOURCE} still running. Please stop."
        exit 1
    fi
}

function replace_string () {
    ## ACTION can be "read", "replace" or "write".
    ## I guess it would be nicer with "case" ...
    local ACTION="$1"
    if [ "${ACTION}" == "read" ]; then
        SOURCEFILE="$2"
        STRING="$( cat ${SOURCEFILE} )"
    elif [ "${ACTION}" == "replace" ]; then
        local REPLACE="$2"
        local SEARCH="$( echo "${REPLACE}" | \
            grep "=" | \
            awk -F'=' '{print $1}'| \
            sed 's/\ //g')"
        local VALUE="$( echo "${STRING}" | \
            grep -v ^'#' | \
            grep ^"${SEARCH}" | \
            grep -v "${SEARCH}\." | \
            grep -v "${SEARCH}\-" | \
            grep -v "${SEARCH}\_" | \
            awk -F'=' '{print $2}'| \
            sed 's/\ //g')"
        ## Is it '=' or ' = ' or ' =' or '= '
        if [ ! -z "$( echo "${STRING}" | grep ^"${SEARCH}=${VALUE}" )" ]; then
            local SEARCH="${SEARCH}=${VALUE}"
        elif [ ! -z "$( echo "${STRING}" | grep ^"${SEARCH} = ${VALUE}" )" ]; then
            local SEARCH="${SEARCH} = ${VALUE}"
        elif [ ! -z "$( echo "${STRING}" | grep ^"${SEARCH}= ${VALUE}" )" ]; then
            local SEARCH="${SEARCH}= ${VALUE}"
        elif [ ! -z "$( echo "${STRING}" | grep ^"${SEARCH} =${VALUE}" )" ]; then
            local SEARCH="${SEARCH} =${VALUE}"
        fi
        ## now check if we can find the string at all
        local FOUND="$( echo "${STRING}" | grep ^"${SEARCH}" )"
        if [ -z "${FOUND}" ]; then
            echo "WARNING! String <${SEARCH}> not found."
        else
            echo "~~ Found source value for replacement: <${SEARCH}>"
            STRING="${STRING//${SEARCH}/${REPLACE}}"
        fi
    elif [ "${ACTION}" == "write" ]; then
        TARGETDIR="$( dirname ${SOURCEFILE} )"
        SOURCENAME="$( basename ${SOURCEFILE} )"
        TARGETNAME="${SOURCENAME/${SOURCE}/${TARGET}}"
        echo -e "\n<= ${SOURCEFILE}\n${STRING} \n=> ${TARGETDIR}/${TARGETNAME}\n\n\n"
        echo "${STRING}" >${TARGETDIR}/${TARGETNAME}
    fi
}

function clone_init () {
    FILE="/etc/init.d/${SOURCE}"
    replace_string "read" "${FILE}"
    replace_string "replace" "NAME=\"${TARGET}\""
    replace_string "replace" "DAEMON=/usr/share/${TARGET}/deepamehta.sh"
    replace_string "write"
    chmod +x /etc/init.d/${TARGETNAME}
    update-rc.d ${TARGETNAME} defaults
}

function clone_default () {
    FILE="/etc/default/${SOURCE}"
    replace_string "read" "${FILE}"
    replace_string "replace" "LOG_DEEPAMEHTA_INIT=/var/log/deepamehta/${TARGET}.log"
    replace_string "replace" "START_DEEPAMEHTA=no"
    replace_string "write"
}

function clone_conf () {
    ## you can skip the source value if uncertain.
    FILE="/etc/deepamehta/${SOURCE}.conf"
    replace_string "read" "${FILE}"
    replace_string "replace" "org.osgi.service.http.port = YOUR_PORT_HERE"
    replace_string "replace" "dm4.websockets.port = YOUR_PORT_HERE"
    replace_string "replace" "dm4.websockets.url = ws://... or wss://YOUR_DOMAIN_HERE"
    replace_string "replace" "dm4.filerepo.path = /var/lib/deepamehta/${TARGET}-filedir"
    replace_string "replace" "felix.fileinstall.dir = /usr/share/${TARGET}/bundle-deploy"
    replace_string "replace" "dm4.host.url = https://YOUR_DOMAIN_HERE/"
    replace_string "replace" "dm4.database.path = /var/lib/deepamehta/${TARGET}-db"
    replace_string "replace" "java.util.logging.config.file = /etc/deepamehta/${TARGET}-logging.conf"
    replace_string "replace" "org.osgi.framework.storage = /var/cache/deepamehta/${TARGET}-bundle-cache"
    replace_string "write"
}

function clone_logging () {
    FILE="/etc/deepamehta/${SOURCE}-logging.conf"
    replace_string "read" "${FILE}"
    replace_string "replace" "java.util.logging.FileHandler.pattern=/var/log/deepamehta/${TARGET}.log"
    replace_string "write"
}

function copy_files () {
    if [ ! -d /usr/share/${TARGET} ]; then
        mkdir -p /usr/share/${TARGET}
    fi
    if [ ! -d /var/lib/deepamehta/${TARGET}-db ]; then
        mkdir -p /var/lib/deepamehta/${TARGET}-db
    fi
    if [ ! -d /var/lib/deepamehta/${TARGET}-filedir ]; then
        mkdir -p /var/lib/deepamehta/${TARGET}-filedir
    fi
    cp -av /usr/share/${SOURCE}/* /usr/share/${TARGET}/
    cp -av /var/lib/deepamehta/${SOURCE}-db/* /var/lib/deepamehta/${TARGET}-db/
    cp -av /var/lib/deepamehta/${SOURCE}-filedir/* /var/lib/deepamehta/${TARGET}-filedir/
    chown -R deepamehta:deepamehta /var/lib/deepamehta/${TARGET}-db/ /var/lib/deepamehta/${TARGET}-filedir/
    chmod 770 /var/lib/deepamehta/${TARGET}-db/ /var/lib/deepamehta/${TARGET}-filedir/
}

## RUN

check_root
check_input
check_existence "${SOURCE}"
check_existence "${TARGET}"
check_running
clone_init
clone_default
clone_conf
clone_logging
copy_files

## END
