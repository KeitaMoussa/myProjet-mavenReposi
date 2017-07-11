#!/bin/bash
INPUT_HDFS_PATH=$1 #"/user/dco_app_simm/work/LINKYQ/rejets"
echo "listeRejets:"$(hadoop fs -ls $INPUT_HDFS_PATH | sed '1d;s/  */ /g' | cut -d\  -f8 | xargs -n 1 basename)