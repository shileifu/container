#!/bin/bash

#1. drop myself in fe
#2. check drop result

HOST_TYPE=${HOST_TYPE:-"IP"}
FE_QUERY_PORT=${FE_QUERY_PORT:-9030}
PROBE_TIMEOUT=60
PROBE_INTERVAL=2
HEARTBEAT_PORT=9050
MY_SELF=
MY_IP=`hostname -i`
MY_HOSTNAME=`hostname -f`
STARROCK_HOME=${STARROCK_HOME:-"/opt/starrocks"}
CN_CONFIG=$STARROCK_HOME/be/conf/cn.conf

log_stderr()
{
    echo "[`date`] $@" >&2
}

show_compute_nodes(){
    timeout 15 mysql --connect-timeout 2 -h $svc -P $FE_QUERY_PORT -u root --skip-column-names --batch -e 'show compute nodes;'
}

parse_confval_from_cn_conf()
{
    # a naive script to grep given confkey from cn conf file
    # assume conf format: ^\s*<key>\s*=\s*<value>\s*$
    local confkey=$1
    local confvalue=`grep "\<$confkey\>" $CN_CONFIG | grep -v '^\s*#' | sed 's|^\s*'$confkey'\s*=\s*\(.*\)\s*$|\1|g'`
    echo "$confvalue"
}

collect_env_info()
{
    # heartbeat_port from conf file
    local heartbeat_port=`parse_confval_from_cn_conf "heartbeat_service_port"`
    if [[ "x$heartbeat_port" != "x" ]] ; then
        HEARTBEAT_PORT=$heartbeat_port
    fi

}

add_self_and_start()
{
    collect_env_info

    if [[ "x$HOST_TYPE" == "xIP" ]] ; then
        MY_SELF=$MY_IP
    else
        MY_SELF=$MY_HOSTNAME
    fi



    local svc=$1
    start=`date +%s`
    local timeout=$PROBE_TIMEOUT

    while true
    do
        timeout 15 mysql --connect-timeout 2 -h $svc -P $FE_QUERY_PORT -u root  --skip-column-names --batch << EOF
ALTER SYSTEM ADD COMPUTE NODE "$MY_SELF:$HEARTBEAT_PORT"
EOF
        memlist=`show_compute_nodes $svc`
        exist=`echo "$memlist" | grep $MY_SELF | awk '{print $2}'`
	echo $exist
        if [[ "x$exist" == "x$MY_SELF" ]] ; then
            break
        fi

        let "expire=start+timeout"
        now=`date +%s`
        if [[ $expire -le $now ]] ; then
            log_stderr "Time out, abort!"
            exit 1
        fi

        sleep $PROBE_INTERVAL

    done

    log_stderr "run start_cn.sh"
    $STARROCK_HOME/be/bin/start_cn.sh
}

svc_name=$1
if [[ "x$svc_name" == "x" ]] ; then
    echo "Need a required parameter!"
    echo "  Example: $0 <fe_service_name>"
    exit 1
fi

add_self_and_start $svc_name
log_stderr "run start_cn.sh"
$STARROCK_HOME/be/bin/start_cn.sh
