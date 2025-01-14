#!/bin/sh
# SPDX-FileCopyrightText: 2024 Splunk, Inc.
# SPDX-License-Identifier: Apache-2.0
#
# credit for improvement to http://splunk-base.splunk.com/answers/41391/rlogsh-using-too-much-cpu

# shellcheck disable=SC1091
. "$(dirname "$0")"/common.sh

OLD_SEEK_FILE=$SPLUNK_HOME/var/run/splunk/unix_audit_seekfile # For handling upgrade scenarios
CURRENT_AUDIT_FILE=/var/log/audit/audit.log # For handling upgrade scenarios
SEEK_FILE=$SPLUNK_HOME/var/run/splunk/unix_audit_seektime
TMP_ERROR_FILTER_FILE=$SPLUNK_HOME/var/run/splunk/unix_rlog_error_tmpfile # For filering out "no matches" error from stderr
AUDIT_FILE="/var/log/audit/audit.log*"

if [ "$KERNEL" = "Linux" ] ; then
    assertHaveCommand service
    assertHaveCommandGivenPath /sbin/ausearch
    if [ -n "$(service auditd status 2>/dev/null)" ] && [ "$(service auditd status 2>/dev/null)" ] ; then
            CURRENT_TIME=$(date --date="1 seconds ago"  "+%x %T") # 1 second ago to avoid data loss

            if [ -e "$SEEK_FILE" ] ; then
                SEEK_TIME=$(head -1 "$SEEK_FILE")
                # shellcheck disable=SC2086
                awk " { print } " $AUDIT_FILE | /sbin/ausearch -i -ts $SEEK_TIME -te $CURRENT_TIME 2>$TMP_ERROR_FILTER_FILE | grep -v "^----";
                # shellcheck disable=SC2086
                grep -v "<no matches>" < $TMP_ERROR_FILTER_FILE 1>&2

            elif [ -e "$OLD_SEEK_FILE" ] ; then
                rm -rf "$OLD_SEEK_FILE" # remove previous checkpoint
                # start ingesting from the first entry of current audit file
                # shellcheck disable=SC2086
                awk ' { print } ' $CURRENT_AUDIT_FILE | /sbin/ausearch -i -te $CURRENT_TIME 2>$TMP_ERROR_FILTER_FILE | grep -v "^----";
                # shellcheck disable=SC2086
                grep -v "<no matches>" <$TMP_ERROR_FILTER_FILE 1>&2

            else
                # no checkpoint found
                # shellcheck disable=SC2086
                awk " { print } " $AUDIT_FILE | /sbin/ausearch -i -te $CURRENT_TIME 2>$TMP_ERROR_FILTER_FILE | grep -v "^----";
                # shellcheck disable=SC2086
                grep -v "<no matches>" <$TMP_ERROR_FILTER_FILE 1>&2
            fi
            echo "$CURRENT_TIME" > "$SEEK_FILE" # Checkpoint+

    else   # Added this condition to get error logs
        echo "error occured while running 'service auditd status' command in rlog.sh script. Output : $(service auditd status). Command exited with exit code $?" 1>&2
    fi
    # remove temporary error redirection file if it exists
    # shellcheck disable=SC2086
    rm $TMP_ERROR_FILTER_FILE 2>/dev/null

elif [ "$KERNEL" = "SunOS" ] ; then
    :
elif [ "$KERNEL" = "Darwin" ] ; then
    :
elif [ "$KERNEL" = "HP-UX" ] ; then
	:
elif [ "$KERNEL" = "FreeBSD" ] ; then
	:
fi
