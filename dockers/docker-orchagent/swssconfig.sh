#!/usr/bin/env bash

function config_acl {
    if [ -f "/etc/sonic/acl.json" ]; then
        mkdir -p /etc/swss/config.d/acl
        rm -rf /etc/swss/config.d/acl/*
        translate_acl -m /etc/sonic/minigraph.xml -o /etc/swss/config.d/acl /etc/sonic/acl.json
        for filename in /etc/swss/config.d/acl/*.json; do
            [ -e "$filename" ] || break
            swssconfig $filename
        done
    fi
}

HWSKU=`sonic-cfggen -m /etc/sonic/minigraph.xml -v minigraph_hwsku`

SWSSCONFIG_ARGS="00-copp.config.json ipinip.json mirror.json "

if [ "$HWSKU" == "Force10-S6000" ]; then
    SWSSCONFIG_ARGS+="td2.32ports.buffers.json td2.32ports.qos.json "
elif [ "$HWSKU" == "Arista-7050-QX32" ]; then
    SWSSCONFIG_ARGS+="td2.32ports.buffers.json td2.32ports.qos.json "
elif [ "$HWSKU" == "ACS-MSN2700" ]; then
    SWSSCONFIG_ARGS+="msn2700.32ports.buffers.json msn2700.32ports.qos.json "
fi

for file in $SWSSCONFIG_ARGS; do
    swssconfig /etc/swss/config.d/$file
    sleep 1
done

config_acl

