# Small library for better log display

SCRIPT_ROOT=$(pwd)
SCRIPT_NAME="Templater Helper"

SCRIPT_VERSION="v1.1.0"
echo "$SCRIPT_ROOT/lib/logutils.sh"
sh "$SCRIPT_ROOT/lib/logutils.sh"

TEMPLATEFILE="templates.json"
REMOTEFOLDER="/usr/share/remarkable/templates"
REMOTEHOMEFOLDER="/home/root/.local/share/remarkable/templates/custom/"
LOCALBACKUPFOLDER="backups"

# trap ctrl-c and call ctrl_c()
trap cleanup INT

cleanup() {
    echo "Exit or interruption detected. Cleaning up"
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

    echo "Pre-requisites checks..."

    # Checking mandatory arguments
    echo "Checking parameter custom template json file"
    if [ -z "${CUSTOMFILE}" ]; then
        echo "Missing custom file (json) with your templates (-c)"
        usage
        exit 401
    fi

    echo "Checking existence of custom template json file"
    if ! [ -f "${CUSTOMFILE}" ]; then
        echo "Custom file '${CUSTOMFILE}' not found"
        usage
        exit 402
    fi

    echo "Checking parameter templates folder"
    if [ -z "${TEMPLATEFOLDER}" ]; then
        echo "Missing template folder (containing png|svg) files (-t)"
        usage
        exit 403
    fi

    echo "Checking existence templates folder"
    if ! [ -e "${TEMPLATEFOLDER}" ]; then
        echo "Template folder '${TEMPLATEFOLDER}' not found"
        usage
        exit 404
    fi

    echo "Checking parameter remote server"
    if [ -z "${REMOTESERVER}" ]; then
        echo "Missing remote server (-r)"
        usage
        exit 405
    fi

    echo "Checking parameter identity file"
    if [ -z "${IDENTITYFILE}" ]; then
        echo "Missing identity file parameter (-i). Note ONLY connection with identity file is managed"
        usage
        exit 406
    fi

    echo "Checking existence identity file"
    if ! [ -f "${IDENTITYFILE}" ]; then
        echo "Identity file '${IDENTITYFILE}' not found"
        usage
        exit 407
    fi

    # Checking commands prerequisites
    echo "Checking dependencies"
    for dependency in jq ssh; do
        echo "Checking for command/tool $dependency"
        if ! [ -x "$(command -v $dependency)" ]; then
            echo >&2 "Required command is not on your PATH: $dependency."
            echo >&2 "Please install it before you continue."
            exit 408
        fi
    done
}

processAllCustom() {
    getFileFromRemote "${REMOTEFOLDER}/$TEMPLATEFILE" "$TEMPLATEFILE"

    echo "FOUND $(jq '.templates | length' $CUSTOMFILE) custom templates in $CUSTOMFILE"

    jq -r -c '.templates[]' ${CUSTOMFILE} | while read i; do
        
        temp=$i
        delimiter="\"name\":\""
        s=$temp$delimiter
        array=()
        while [[ $s ]]; do
            array+=( "${s%%"$delimiter"*}" );
            s=${s#*"$delimiter"};
        done;
        echo ${array[1]}

        delimiter="\",\""
        s=${array[1]}$delimiter
        array1=()
        while [[ $s ]]; do
            array1+=( "${s%%"$delimiter"*}" );
            s=${s#*"$delimiter"};
        done;
        echo ${array1[0]}
        echo "Processing template name ${array1[0]}"
        checkFilename "${i}"
        processOneTemplate "${i}"
    done

    # Backing up remote file
    TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')
    if [ ! -d "./${LOCALBACKUPFOLDER}" ]; then
        mkdir ./${LOCALBACKUPFOLDER}
    fi
    cp $TEMPLATEFILE "${LOCALBACKUPFOLDER}/$TEMPLATEFILE.${TIMESTAMP}"
    echo "In case of error, backup file is: ${LOCALBACKUPFOLDER}/$TEMPLATEFILE.${TIMESTAMP}"

    # Copying file to remote
    echo "Copy files to remote"
    if [ -z $DRYRUN ]; then
        copyFileToRemote "${TEMPLATEFILE}" "${REMOTEFOLDER}/${TEMPLATEFILE}"
    else
        echo "DRYRUN copy ${TEMPLATEFILE} to ${REMOTEFOLDER}/${TEMPLATEFILE}"
    fi

    echo "Restarting main reMarkable application (xochitl)"
    if [ -z $DRYRUN ]; then
        ssh -n -i $IDENTITYFILE root@$REMOTESERVER 'systemctl restart xochitl 2> /dev/null'
    else
        echo "DRYRUN restart interface"
    fi

}

processOneTemplate() {
    local SOURCE="${1}"
    temp=$SOURCE
    delimiter="\"name\":\""
    s=$temp$delimiter
    array=()
    while [[ $s ]]; do
        array+=( "${s%%"$delimiter"*}" );
        s=${s#*"$delimiter"};
    done;
    echo ${array[1]}

    delimiter="\",\""
    s=${array[1]}$delimiter
    array1=()
    while [[ $s ]]; do
        array1+=( "${s%%"$delimiter"*}" );
        s=${s#*"$delimiter"};
    done;
    echo ${array1[0]}
    local TEMP_NAME=${array1[0]}
    
    temp=$SOURCE

    delimiter="\"filename\":\""
    s=$temp$delimiter
    array=()
    while [[ $s ]]; do
        array+=( "${s%%"$delimiter"*}" );
        s=${s#*"$delimiter"};
    done;
    echo ${array[1]}

    delimiter="\",\""
    s=${array[1]}$delimiter
    array1=()
    while [[ $s ]]; do
        array1+=( "${s%%"$delimiter"*}" );
        s=${s#*"$delimiter"};
    done;
    echo ${array1[0]}
    
    local FILENAME=${array1[0]}

    # Copying files. If does already exist, it will be refreshed with the latest version
    local OPT1="${FILENAME}.png"
    if [ -f "${TEMPLATEFOLDER}/${OPT1}" ]; then
        if [ -z $DRYRUN ]; then
            echo "copyFileToRemote ${TEMPLATEFOLDER}/${OPT1} --> ${REMOTEHOMEFOLDER}/${OPT1}"
            copyFileToRemote "${TEMPLATEFOLDER}/${OPT1}" "${REMOTEHOMEFOLDER}/${OPT1}"
            RES=$(ssh -n -i $IDENTITYFILE root@$REMOTESERVER "ln -fsv ${REMOTEHOMEFOLDER}/${OPT1} ${REMOTEFOLDER}/${OPT1}")
        else
            echo "DRYRUN copy ${TEMPLATEFOLDER}/${OPT1} to ${REMOTEHOMEFOLDER}/${OPT1}"
        fi
    fi

    local OPT2="${FILENAME}.svg"
    if [ -f "${TEMPLATEFOLDER}/${OPT2}" ]; then
        if [ -z $DRYRUN ]; then
            echo "copyFileToRemote ${TEMPLATEFOLDER}/${OPT2} --> ${REMOTEHOMEFOLDER}/${OPT2}"
            copyFileToRemote "${TEMPLATEFOLDER}/${OPT2}" "${REMOTEHOMEFOLDER}/${OPT2}"
            RES=$(ssh -n -i $IDENTITYFILE root@$REMOTESERVER "ln -fsv ${REMOTEHOMEFOLDER}/${OPT2} ${REMOTEFOLDER}/${OPT2}")
        else
            echo "DRYRUN copy ${TEMPLATEFOLDER}/${OPT2} to ${REMOTEHOMEFOLDER}/${OPT2}"
        fi
    fi

    # Looking for the template in original file
    GOTIT=$(jq --arg n "${TEMP_NAME}" '[.templates[] | select( .name == $n )] | length' $TEMPLATEFILE)

    if [[ $GOTIT != "1" ]] && [[ $GOTIT != "0" ]]; then
        echo "There is an issue with the search response... Check logs"
        echo $GOTIT
        exit 501
    fi

    if [[ $GOTIT -eq "1" ]]; then
        echo "The template '${TEMP_NAME}' is already there. Skipping."
        return
    fi

    echo "The template '${TEMP_NAME}' is NOT there. Processing."
    RESULT=$(jq -a --argjson s "$SOURCE" '.templates += [$s]' $TEMPLATEFILE)
    echo "${RESULT}" >$TEMPLATEFILE

}

checkFilename() {
    local OBJECT="${1}"
    
    temp=$(cat json_test.json)

    delimiter="\"filename\":\""
    s=$temp$delimiter
    array=()
    while [[ $s ]]; do
        array+=( "${s%%"$delimiter"*}" );
        s=${s#*"$delimiter"};
    done;
    echo ${array[1]}

    delimiter="\",\""
    s=${array[1]}$delimiter
    array1=()
    while [[ $s ]]; do
        array1+=( "${s%%"$delimiter"*}" );
        s=${s#*"$delimiter"};
    done;
    echo ${array1[0]}
    
    FILENAME=${array1[0]}

    local OPT1=${TEMPLATEFOLDER}/${FILENAME}".png"
    local OPT2=${TEMPLATEFOLDER}/${FILENAME}".svg"

    echo "Checking file existence: ${FILENAME}.(png|svg)"
    if [ -f $OPT1 ] || [ -f $OPT2 ]; then
        echo "Files found. Can continue."
    else
        echo "Template files not found. Missing '$OPT1' or '$OPT2' or both"
        exit 409
    fi
}

getFileFromRemote() {
    local SOURCE=$1
    local DEST=$2
    local TEMPFILE=$(mktemp /tmp/$(basename $0).XXXXXX)

    echo "Getting remote file ($SOURCE)"
    scp -i $IDENTITYFILE root@$REMOTESERVER:$SOURCE $DEST 2>$TEMPFILE 1>/dev/null

    echo "SCP log file: $TEMPFILE"

    if [ $? = 0 ]; then
        echo "Copy $SOURCE to $DEST ok"
    else
        echo "Error during copying file from $SOURCE to $DEST. Please check log file: $TEMPFILE "
        exit 502
    fi
}

copyFileToRemote() {
    local SOURCE=$1
    local DEST=$2
    local TEMPFILE=$(mktemp /tmp/$(basename $0).XXXXXX)

    echo "Copying file to remote ($SOURCE)"
    scp -i $IDENTITYFILE $SOURCE root@$REMOTESERVER:$DEST 2>$TEMPFILE >/dev/null

    if [ $? = 0 ]; then
        echo "Copy $SOURCE to $DEST ok"
    else
        echo "Error during copying file from $SOURCE to $DEST. Please check log file: $TEMPFILE "
        exit 503
    fi
}

while getopts "r:i:c:t:dhn" option; do
    case "${option}" in
    d)
        # DEBUG mode activated
        debug="T"
        echo "DEBUG mode activated. "
        ;;
    n)
        DRYRUN=1
        echo "Dry run mode activated. No files will be PUSHED"
        ;;
    h)
        usage
        exit 2
        ;;
    c)
        CUSTOMFILE=${OPTARG}
        echo "Custom file set: $CUSTOMFILE"
        ;;
    t)
        TEMPLATEFOLDER=${OPTARG}
        echo "Folder template set: $TEMPLATEFOLDER"
        ;;
    r)
        REMOTESERVER=${OPTARG}
        echo "Remote server set: $REMOTESERVER"
        ;;
    i)
        IDENTITYFILE=${OPTARG}
        echo "Identity file set: $IDENTITYFILE"
        ;;
    *)
        usage
        exit 4
        ;;
    esac
done
shift $((OPTIND - 1))

checkPrereq
echo "Starting update script"
processAllCustom
echo "Update script done."
exit 0
