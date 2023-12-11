# Small library for better log display
SCRIPT_ROOT=$( (cd "$(dirname "$0")" && pwd))
SCRIPT_NAME=$(basename $0)
SCRIPT_VERSION="v1.0.1"
source "$SCRIPT_ROOT/lib/logutils.sh"

TEMPLATEFILE="templates.json"
REMOTEFOLDER="/usr/share/remarkable/templates"
LOCALBACKUPFOLDER="backups"

# trap ctrl-c and call ctrl_c()
trap cleanup INT

cleanup() {
    logwarn "Exit or interruption detected. Cleaning up"
    rm $TEMPLATEFILE 2>/dev/null
    exit 999
}

usage() {
    echo ""
    echo "----------=== ${SCRIPT_NAME} - ${SCRIPT_VERSION} ===----------"
    echo ""
    echo "Source: https://github.com/arnaduga/r2-custom-updater"
    echo "License: MIT"
    echo ""
    echo "Script to update a reMarkable tablet with custome templates (after an update)"
    echo ""
    echo "Usage: update.sh -r <IP_reMarkable> -i <SSH_identity_file> -t <template_folder> -c <custom_json_template_file>"
    echo ""
    echo ""
    echo "  -r <ip_reMarkable.json>           MANDATORY   : IP of the reMarkable tablet"
    echo "  -c <custom_json_template_file>    MANDATORY   : JSON file contains your custom template definition"
    echo "  -i <SSH_identity_file>            MANDATORY   : the private key to connect to reMarkable tablet"
    echo "  -t <template_folder>              MANDATORY   : template hosting all your custom template (png|svg)"
    echo "  -d                                OPTIONAL    : Activate the debug log mode"
    echo "  -h                                OPTIONAL    : Display THIS message"
    echo ""
    echo ""
}

checkPrereq() {

    loginfo "Pre-requisites checks..."

    # Checking mandatory arguments
    logdebug "Checking parameter custom template json file"
    if [ -z "${CUSTOMFILE}" ]; then
        logfatal "Missing custom file (json) with your templates (-c)"
        usage
        exit 401
    fi

    logdebug "Checking existence of custom template json file"
    if ! [ -f "${CUSTOMFILE}" ]; then
        logfatal "Custom file '${CUSTOMFILE}' not found"
        usage
        exit 402
    fi

    logdebug "Checking parameter templates folder"
    if [ -z "${TEMPLATEFOLDER}" ]; then
        logfatal "Missing template folder (containing png|svg) files (-t)"
        usage
        exit 403
    fi

    logdebug "Checking existence templates folder"
    if ! [ -e "${TEMPLATEFOLDER}" ]; then
        logfatal "Template folder '${TEMPLATEFOLDER}' not found"
        usage
        exit 404
    fi

    logdebug "Checking parameter remote server"
    if [ -z "${REMOTESERVER}" ]; then
        logfatal "Missing remote server (-r)"
        usage
        exit 405
    fi

    logdebug "Checking parameter identity file"
    if [ -z "${IDENTITYFILE}" ]; then
        logfatal "Missing identity file parameter (-i). Note ONLY connection with identity file is managed"
        usage
        exit 406
    fi

    logdebug "Checking existence identity file"
    if ! [ -f "${IDENTITYFILE}" ]; then
        logfatal "Identity file '${IDENTITYFILE}' not found"
        usage
        exit 407
    fi

    # Checking commands prerequisites
    loginfo "Checking dependencies"
    for dependency in jq ssh; do
        logdebug "Checking for command/tool $dependency"
        if ! [ -x "$(command -v $dependency)" ]; then
            logfatal >&2 "Required command is not on your PATH: $dependency."
            logfatal >&2 "Please install it before you continue."
            exit 408
        fi
    done
}

processOneTemplate() {
    local SOURCE="${1}"
    local TEMP_NAME=$(jq -c -r '.name' <<<$SOURCE)
    local FILENAME=$(jq -c -r '.filename' <<<$SOURCE)

    # Copying files. If does already exist, it will be refreshed with the latest version
    local OPT1="${FILENAME}.png"
    local OPT2="${FILENAME}.svg"

    if [ -f "${TEMPLATEFOLDER}/${OPT1}" ]; then
        if [ "$DRYRUN" -eq 1 ]; then
            loginfo "DRYRUN copy ${TEMPLATEFOLDER}/${OPT1} to ${REMOTEFOLDER}/${OPT1}"
        else
            copyFileToRemote "${TEMPLATEFOLDER}/${OPT1}" "${REMOTEFOLDER}/${OPT1}"
        fi
        logdebug "copyFileToRemote ${TEMPLATEFOLDER}/${OPT1} --> ${REMOTEFOLDER}/${OPT1}"
    fi

    if [ -f "${TEMPLATEFOLDER}/${OPT2}" ]; then
        if [ "$DRYRUN" -eq 1 ]; then
            loginfo "DRYRUN copy ${TEMPLATEFOLDER}/${OPT2} to ${REMOTEFOLDER}/${OPT2}"
        else
            copyFileToRemote "${TEMPLATEFOLDER}/${OPT2}" "${REMOTEFOLDER}/${OPT2}"
        fi
        logdebug "copyFileToRemote ${TEMPLATEFOLDER}/${OPT2} --> ${REMOTEFOLDER}/${OPT2}"
    fi

    # Looking for the template in original file
    GOTIT=$(jq --arg n "${TEMP_NAME}" '[.templates.[] | select( .name == $n )] | length' $TEMPLATEFILE)

    if [[ $GOTIT != "1" ]] && [[ $GOTIT != "0" ]]; then
        logfatal "There is an issue with the search response... Check logs"
        logerror $GOTIT
        exit 501
    fi

    if [[ $GOTIT -eq "1" ]]; then
        logdebug "The template '${TEMP_NAME}' is already there. Skipping."
        return
    fi

    logdebug "The template '${TEMP_NAME}' is NOT there. Processing."
    RESULT=$(jq -a --argjson s "$SOURCE" '.templates += [$s]' $TEMPLATEFILE)
    echo "${RESULT}" >$TEMPLATEFILE

}

getFileFromRemote() {
    local SOURCE=$1
    local DEST=$2
    local TEMPFILE=$(mktemp /tmp/$(basename $0).XXXXXX)

    loginfo "Getting remote file ($SOURCE)"
    scp -i $IDENTITYFILE root@$REMOTESERVER:$SOURCE $DEST 2>$TEMPFILE 1>/dev/null

    logdebug "SCP log file: $TEMPFILE"

    if [ $? == 0 ]; then
        logdebug "Copy $SOURCE to $DEST ok"
    else
        logfatal "Error during copying file from $SOURCE to $DEST. Please check log file: $TEMPFILE "
        exit 502
    fi
}

copyFileToRemote() {
    local SOURCE=$1
    local DEST=$2
    local TEMPFILE=$(mktemp /tmp/$(basename $0).XXXXXX)

    loginfo "Copying file to remote ($SOURCE)"
    scp -i $IDENTITYFILE $SOURCE root@$REMOTESERVER:$DEST 2>$TEMPFILE >/dev/null

    if [ $? == 0 ]; then
        logdebug "Copy $SOURCE to $DEST ok"
    else
        logfatal "Error during copying file from $SOURCE to $DEST. Please check log file: $TEMPFILE "
        exit 503
    fi
}

checkFilename() {
    local OBJECT="${1}"
    FILENAME=$(jq -r -c '.filename' <<<$OBJECT)

    local OPT1=${TEMPLATEFOLDER}/${FILENAME}".png"
    local OPT2=${TEMPLATEFOLDER}/${FILENAME}".svg"

    logdebug "Checking file existence: ${FILENAME}.(png|svg)"
    if [ -f $OPT1 ] || [ -f $OPT2 ]; then
        logdebug "Files found. Can continue."
    else
        logfatal "Template files not found. Missing '$OPT1' or '$OPT2' or both"
        exit 409
    fi
}

processAllCustom() {

    # To parametrize (command argument)
    local CUSTFILE="custom.json"

    getFileFromRemote "${REMOTEFOLDER}/$TEMPLATEFILE" "$TEMPLATEFILE"

    jq -c '.templates[]' $CUSTFILE | while read i; do
        loginfo "Processing template name $(jq -r -c '.name' <<<$i)"
        # Check if file exist
        checkFilename "${i}"
        # Manage ONE template
        processOneTemplate "${i}"
    done

    # Backing up remote file
    TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')
    if [ ! -d "./${LOCALBACKUPFOLDER}" ]; then
        mkdir ./${LOCALBACKUPFOLDER}
    fi
    cp $TEMPLATEFILE "${LOCALBACKUPFOLDER}/$TEMPLATEFILE.${TIMESTAMP}"
    stdlog "In case of error, backup file is: ${LOCALBACKUPFOLDER}/$TEMPLATEFILE.${TIMESTAMP}"

    # Copying file to remote
    loginfo "Copy files to remote"
    if [ "$DRYRUN" -eq 1 ]; then
        loginfo "DRYRUN copy ${TEMPLATEFILE} to ${REMOTEFOLDER}/${TEMPLATEFILE}"
    else
        copyFileToRemote "${TEMPLATEFILE}" "${REMOTEFOLDER}/${TEMPLATEFILE}"
    fi

    loginfo "Restarting main reMarkable application (xochitl)"
    if [ "$DRYRUN" -eq 1 ]; then
        loginfo "DRYRUN restart interface"
    else
        ssh -i $IDENTITYFILE root@$REMOTESERVER 'systemctl restart xochitl 2> /dev/null'
    fi

}

while getopts "r:i:c:t:dhn" option; do
    case "${option}" in
    d)
        # DEBUG mode activated
        debug="T"
        logdebug "DEBUG mode activated. "
        ;;
    n)
        DRYRUN=1
        loginfo "Dry run mode activated. No files will be PUSHED"
        ;;
    h)
        usage
        exit 2
        ;;
    c)
        CUSTOMFILE=${OPTARG}
        logdebug "Custom file set: $CUSTOMFILE"
        ;;
    t)
        TEMPLATEFOLDER=${OPTARG}
        logdebug "Folder template set: $TEMPLATEFOLDER"
        ;;
    r)
        REMOTESERVER=${OPTARG}
        logdebug "Remote server set: $REMOTESERVER"
        ;;
    i)
        IDENTITYFILE=${OPTARG}
        logdebug "Identity file set: $IDENTITYFILE"
        ;;
    *)
        usage
        exit 4
        ;;
    esac
done
shift $((OPTIND - 1))

checkPrereq
stdlog "Starting update script"
processAllCustom
stdlog "Update script done."
exit 0
