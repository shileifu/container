#!/bin/bash

STARROCKS_ROOT=${STARROCKS_ROOT:-"/opt/starrocks"}
STARROCKS_HOME=$STARROCKS_ROOT/fe

# graceful stop cn
$STARROCKS_HOME/bin/stop_cn.sh -g
