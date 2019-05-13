#!/bin/sh

cd "$(dirname "$0")"

if [ -z $1 ]; then
    CONFIG="/etc/dmx/config.properties"
else
    CONFIG="$1"
fi

if [ ! -f ${CONFIG} ]; then
    echo "ERROR! Config file ${CONFIG} not found."
    exit 1
fi

if [ -r /etc/default/dmx ]; then 
    . /etc/default/dmx
    if [ "${START_DMX}" != "yes" ]; then
        echo "   ${DESC} is disabled in /etc/default/${NAME}."
        exit 1
    else
        exec java -Xms${DM_JAVA_XMS}M -Xmx${DM_JAVA_XMX}M -Dfile.encoding=UTF-8 -Dfelix.system.properties=file:${CONFIG} -jar bin/felix.jar
    fi
else
    echo "WARNING! Config file /etc/default/dmx not found. Starting with default JAVA memory settings."
    exec java -Dfile.encoding=UTF-8 -Dfelix.system.properties=file:${CONFIG} -jar bin/felix.jar
fi
