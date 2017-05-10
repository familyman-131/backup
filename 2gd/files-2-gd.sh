#!/bin/bash

BACKUP_START_TIME="012000"
BACKUP_END_TIME="141900"
######
CP=$(which cp)
FIND=$(which find)
TEE=$(which tee)
ECHO=$(which echo)
TAR=$(which tar)
RCLONE=$(which rclone)
AWK=$(which awk)
RM=$(which rm)
CAT=$(which cat)
HEAD=$(which head)
MV=$(which mv)
TAIL=$(which tail)
GREP=$(which grep)
SLEEP=$(which sleep)
TAIL=$(which tail)
SED=$(which sed)
WC=$( which wc)
######
TMP="/tmp"
LOG="${TMP}/files-2-gd.log"
SRC="/var/log"
RCLONE_DEST="backup:backup/test/files"
LIST="${TMP}/file.list"
MAIL="t-131@yandex.ru"
EXCLUDED_FOLDERS="asterisk|apt"
SED_RELATIVE_PATH="\/var\/log\/"
######
if [ -s ${LIST} ]
    then
        ${ECHO} "file exist, go ahead"
        ${SLEEP} 2
        ${CAT} "${LIST}" | ${WC} -l
    else
        ${CAT} "${LIST}" | ${WC} -l
        # tail -n +2 because first line is path to directory
        LIST=$(${FIND} ${SRC} -maxdepth 1 -type d | ${TAIL} -n +2  | ${SED} s"/${SED_RELATIVE_PATH}//" | ${GREP} -vwE "(${EXCLUDED_FOLDERS})" > ${TMP}/file.list )
        LIST="${TMP}/file.list"
        ${ECHO} "recreate file.list"
        ${CAT} "${LIST}" | ${WC} -l
        ${SLEEP} 2
fi

while read NAME
do

CURRENT_TIME=`date +"%H%M%S"`
if [[ ${CURRENT_TIME} -ge ${BACKUP_START_TIME} && ${CURRENT_TIME} -le ${BACKUP_END_TIME} ]];
    then
        ${ECHO} "do next - time is ${CURRENT_TIME}"
        ${SLEEP} 2
        TAR_NAME="${NAME}.tar.gz"
        LOG="/var/log/rclone/${NAME}.log"

        ${ECHO} "${NAME}"
        ${ECHO} "copying"
        ${CP} -r ${SRC}/${NAME}/.  ${TMP}/${NAME}/
        ${ECHO} "Packing"
        ${TAR} -czvf ${TMP}/${TAR_NAME} -C ${TMP}/ ${NAME}/
        ${ECHO} "Rclone"
        ${RCLONE}  copy  ${TMP}/${TAR_NAME}  ${RCLONE_DEST}/  -v > ${LOG}  2>&1
        # we can use exit code http://rclone.org/docs/#exit-code
        # If any errors occurred during the command, rclone with an exit code of 1. This allows scripts to detect when rclone operations have failed.
        # Or we can use "rclone check ${TMP}/${TAR_NAME} ${RCLONE_DEST}/${TAR_NAME}" output
        # it can be "MD5 differ" or "Sizes differ"
        ${ECHO} "checking"
        #${ECHO} "remote md5sum var is ${RCLONE_DEST}/${TAR_NAME}"
        LOCAL_MD5=$(${RCLONE} md5sum ${TMP}/${TAR_NAME}  | ${AWK} '{print $1}' )
        REMOTE_MD5=$(${RCLONE} md5sum ${RCLONE_DEST}/${TAR_NAME}  | ${AWK} '{print $1}' )
        ${ECHO} "Remote md5sum = ${REMOTE_MD5}" >> ${LOG}
        ${ECHO} "Local md5sum =  ${LOCAL_MD5}" >> ${LOG}
        if [ ${REMOTE_MD5} == ${LOCAL_MD5} ]
            then
                ${ECHO} "EQ" >> ${LOG}
                LIST=$(${TAIL} -n +2 ${TMP}/file.list > ${TMP}/file.list.tmp && ${MV} ${TMP}/file.list.tmp ${TMP}/file.list)
            else
                ${ECHO} "NEQ" >> ${LOG}
        fi
        ${ECHO} "Cleaning"
        ${RM} -rf ${TMP}/${NAME}/
        ${RM} ${TMP}/${TAR_NAME}
        ${ECHO} "job is done"
    else
        ${ECHO} "stoping - time is ${CURRENT_TIME}"
        exit
fi

done < ${LIST}
exit
