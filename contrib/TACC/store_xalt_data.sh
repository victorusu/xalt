#!/bin/bash
# -*- shell-script -*-
MCLAY=~mclay
export PATH=$MCLAY/l/pkg/xalt/xalt/bin:$MCLAY/l/pkg/xalt/xalt/sbin:/opt/rh/rh-python35/root/usr/bin:$PATH
export LD_LIBRARY_PATH=/opt/rh/rh-python35/root/usr/lib64
SYSHOSTS=( maverick2 stampede2 )

SYSLOG_TO_DB=$MCLAY/l/pkg/xalt/xalt/sbin/xalt_syslog_to_db.py

errMsg=""
store_xalt_data ()
{
    clusterName=$1
    WD=$MCLAY/process_xalt/$clusterName
    for log in /data/log/xalt_${clusterName}.log-*; do
        if [ -f $log ]; then
           echo python3 $SYSLOG_TO_DB --syslog $log --syshost $clusterName --reverseMapD $WD/reverseMapD --u2acct $WD/u2acct.json --leftover $WD/leftover.log --confFn $WD/xalt_${clusterName}_db.conf
                python3 $SYSLOG_TO_DB --syslog $log --syshost $clusterName --reverseMapD $WD/reverseMapD --u2acct $WD/u2acct.json --leftover $WD/leftover.log --confFn $WD/xalt_${clusterName}_db.conf
           status=$?
           echo ""
           echo "date: $(date)"
           if [ $status != 0 ]; then
              errMsg="$errMsg\nProblem with XALT ingestion on $clusterName for $log"
           else
              rm $log
           fi 
        fi
    done
}

manager ()
{
   echo "========================================================================"
   XALT_EXECUTABLE_TRACKING=yes LD_PRELOAD= xalt_configuration_report --git_version
   echo "========================================================================"

   echo ""
   echo "Start Date: $(date)"
   for i in "${SYSHOSTS[@]}" ; do
     store_xalt_data $i
   done
   echo "End Date: $(date)"
   echo ""
}



store_log="Store.log-$(date +%Y-%m-%d)"

touch $store_log
chmod 644 $store_log

manager > $store_log 2>&1

find -name 'Store.log-*' -ctime +30 -exec rm -f {} \;

if [ -n "$errMsg" ]; then
  echo -e "$errMsg\n" | mail -s "XALT VM: Problem with XALT ingestion" mclay@tacc.utexas.edu > /dev/null
fi

percentage=$(df /data | tail -n 1 | awk '{print $5}' | sed -e 's/%//')
if [ "$percentage" -gt 90 ]; then
   mail -s '/data disk > 90% on xalt VM' mclay@tacc.utexas.edu < /dev/null > /dev/null
fi

