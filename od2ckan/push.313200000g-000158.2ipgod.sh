#!/bin/bash

# Author : Ceasar Sun , Power by IPGOD project
# 20170830: version 1

## S1: 需確認之整體參數

### S1.1: CKAN site and required library/toolkit  environment

API_KEY="xxx-xxx-xxx-xxx"  # key for CKAN site
SITE="http://ipgod.nchc.org.tw"
LIB_DIR='/opt/ipgod_production/od2ckan/lib'	# need to use push2ckan.py , update2ckan.py

### S1.2:  publish data info 
WD="/opt/ipgod_production/data_download/313200000g-000158"
PACKAGE_ID="313200000g-000158"
FILENAME_PREFIX="${PACKAGE_ID}-"
FORMAT_LIST="xml csv json"

## S2: 下列參數不需更改

LATEST_LOG="latest-${PACKAGE_ID}.log"		#Content: "format:resource_id:md5sum:filename"
RESOURCE_JSON="/tmp/${PACKAGE_ID}.tmp.json"

### main ###

pushd $WD

[ -f "$LATEST_LOG" ] || touch $LATEST_LOG || exit 1;

for format in $FORMAT_LIST ; do

    resource_id=''
    latest_filename=''
    latest_md5sum=''

    last_filename=''
    last_md5sum=''

    need_to_update_log='n'

    latest_filename=$(ls -t ${FILENAME_PREFIX}*.${format} 2>/dev/null | head -1)    
    [ -z "$latest_filename" ] && continue;
    latest_md5sum=$(md5sum $latest_filename | awk -F " " '{print $1}')
    
    resource_id=$(grep -E "^$format" $LATEST_LOG | awk -F ":" '{print $2}')
    if [ -n "$resource_id" ] ;then 
        last_filename=$(grep -E "^$format" $LATEST_LOG | awk -F ":" '{print $4}')
        last_md5sum=$(grep -E "^$format" $LATEST_LOG | awk -F ":" '{print $3}')
    fi

    echo "'$format':'$resource_id':'${latest_filename}/${last_filename}':'${latest_md5sum}/${last_md5sum}'"

    if [ -z "$resource_id" ] ; then
        # New add and be as the latest , use : `${LIB_DIR}/push2ckan.py --api_key key --package package-id --name name --file file`
        ${LIB_DIR}/push2ckan.py --api_key $API_KEY --package $PACKAGE_ID --name $latest_filename --file $latest_filename
        ${LIB_DIR}/push2ckan.py --api_key $API_KEY --package $PACKAGE_ID --name latest-${PACKAGE_ID}.$format --file $latest_filename > $RESOURCE_JSON

        resource_id=$(grep -E "^\s*\"id\":" $RESOURCE_JSON | awk -F ":" '{print $2}' |  tr -d ", \"") 
        need_to_update_log='y'

    elif [ ! "$latest_md5sum" = "$last_md5sum"  ] ; then
        # Update resource
        ${LIB_DIR}/push2ckan.py --api_key $API_KEY --package $PACKAGE_ID --name $latest_filename --file $latest_filename
        ${LIB_DIR}/update2ckan.py --api_key $API_KEY --resource $resource_id --name latest-${PACKAGE_ID}.$format --file $latest_filename
        need_to_update_log='y'
    else
	echo "No need to update latest '$format' file . Skip !"
        continue;
    fi

    if [ "$need_to_update_log" = "y" ] ; then
        # delete old recoder then add new one
        sed -i "/^$format:/d" $LATEST_LOG
        ### LATEST_LOG="latest.log"		#Content: "format:resource_id:md5sum:filename"
        echo "${format}:${resource_id}:$latest_md5sum:$latest_filename" >> $LATEST_LOG
    fi

done

popd;
