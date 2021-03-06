#!/usr/bin/env bash

echo ""
echo "#############################"
echo "#                           #"
echo "#     Öffis Paper Setup     #"
echo "#                           #"
echo "#############################"

echo ""
echo ""
echo ""
echo "### check execution directory ###"
echo ""
if ! [[ `echo $0` == "./setup.sh" ]] && ! [[ `pwd` == */scripts ]]; then
    sleep 0.5
    echo >&2 "relative paths will not match!"
    echo >&2 "please execute this script inside '/scripts' directory as './setup.py'"
    exit 1
else
    echo "script started in '/scripts' directory! Proceeding..."
fi


echo ""
echo ""
echo ""
echo "### check for config.json ###"
echo ""

if [[ ! -f ../config.json ]]; then
    sleep 0.5
    echo >&2 "config.json not found in root!"
    echo >&2 "please rename 'config.json.skeleton' to 'config.json' and adapt values"
    exit 1
else
    echo "'config.json' found! Proceeding..."
fi


echo ""
echo ""
echo ""
echo "### checking system dependencies ###"
echo ""

install_msg=""

if ! hash nohup 2>/dev/null; then
    install_msg=" nohup:"
    install_msg="$install_msg\n required for 'start.sh'"
fi

if ! hash nodejs 2>/dev/null; then
    install_msg=" nodejs:"
    install_msg="$install_msg\n required for retrieving OeBB data"
fi

if ! hash npm 2>/dev/null; then
    install_msg=" npm:"
    install_msg="$install_msg\n required for retrieving OeBB data"
fi

if ! hash curl 2>/dev/null; then
    install_msg=" curl:"
    install_msg="$install_msg\n required for downloading the waveshare library"
fi

if ! hash 7z 2>/dev/null; then
    install_msg=" 7z (p7zip-full):"
    install_msg="$install_msg\n required for unpacking the waveshare library"
fi

if ! hash python3 2>/dev/null; then
    install_msg="$install_msg\n python3:"
    install_msg="$install_msg\n required for executing"
fi

satisfied_msg="all system dependencies"

if ! hash dpkg 2>/dev/null; then
    sleep 0.5
    echo -e "dpkg not installed. Probably not running Raspbian..."
    echo -e "dpkg:"
    echo -e " used to check if packages libopenjp2.so.7 libtiff.so.5 python3-venv are installed."
    sleep 1
    echo >&2 -e "\nPlease install libopenjp2.so.7 libtiff.so.5 python3-venv before continuing!"

    check=true
    while ${check}; do
        sleep 1
        echo "continue? y/n"
        read yn
        case ${yn} in
            [Yy]* ) check=false; satisfied_msg="$satisfied_msg probably";;
            [Nn]* ) check=false; echo >&2 -e "Exiting..."; exit;;
        esac
    done
    echo

else
    if ! dpkg -s libopenjp2-7 > /dev/null 2>&1; then
        install_msg=" libopenjp2.so.7 (libopenjp2-7):"
        install_msg="$install_msg\n required for running the pillow library"
    fi

    if ! dpkg -s libtiff5 > /dev/null 2>&1; then
        install_msg=" libtiff5 (libtiff.so.5):"
        install_msg="$install_msg\n required for running the pillow library"
    fi

    if ! dpkg -s python3-venv > /dev/null 2>&1; then
        install_msg=" python3-venv:"
        install_msg="$install_msg\n required for creating python3 virtual environments"
    fi
fi

if [[ -z ${install_msg} ]]; then
    echo "$satisfied_msg satisfied! Proceeding..."
else
    if hash apt 2>/dev/null; then
        # if apt exists, install required packages
        echo "Installing nodejs npm libopenjp2-7 libtiff5 python3 python3-venv p7zip-full curl nohup"
        sudo apt update && sudo apt upgrade -y # update to latest  packages
        if ! sudo apt install nodejs npm libopenjp2-7 libtiff5 python3 python3-venv p7zip-full curl coreutils; then
        sleep 0.5
            echo >&2 "Some error occured. Exiting..."
            exit 1
        fi
    else
        sleep 0.5
        # if apt does not exist, prompt to user
        echo >&2 "Please use your distribution's package manager to install following dependencies first:"
        echo >&2 -e ${install_msg}
        echo >&2 "You might have to install:"
        echo >&2 -e " libopenjp2.so.7 libtiff.so.5 python3-venv"

        check2=true
        while ${check2}; do
            sleep 1
            echo "still continue? y/n"
            read yn
            case ${yn} in
                [Yy]* ) check2=false; satisfied_msg="$satisfied_msg probably";;
                [Nn]* ) check2=false; echo >&2 -e "Exiting..."; exit;;
            esac
        done
    fi
fi


echo ""
echo ""
echo ""
echo "### downloading third party libraries ###"
echo ""
WS_TEMP_DIR=$(mktemp -d /tmp/setup.waveshare.XXXXXXXXXX) || exit 1
echo "created temp directory: $WS_TEMP_DIR"
WS_FILE_NAME="$WS_TEMP_DIR/waveshare_lib.7z"

echo "download latest driver for waveshare 7.5inch e-paper Model B from"
WS_LIB_URL="https://www.waveshare.com/w/upload/archive/0/01/20190327094726%217.5inch_e-paper_hat_b_code.7z"
echo "$WS_LIB_URL"
curl ${WS_LIB_URL} -A "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36" --output ${WS_FILE_NAME}

echo "extracting waveshare raspberryPi python library"
7z x -aoa -o${WS_TEMP_DIR} ${WS_FILE_NAME} > /dev/null # silent 7z

echo "moving waveshare library to ../lib"
mkdir -p ../lib/waveshare

cp -rf ${WS_TEMP_DIR}/RaspberryPi/python3/* ../lib/waveshare

echo "clean up"
rm -rf ${WS_TEMP_DIR}

echo "fix waveshare library imports"
patch -b -d ../lib/waveshare/ < patches/epd7in5b_20190327_import.patch


echo ""
echo ""
echo ""
echo "### downloading third party assets ###"
echo ""

echo "download latest yr.no icons"
YR_ICONS_DIR="../assets/yr"
mkdir -p ${YR_ICONS_DIR}
echo "delete old yr.no icons"
cd ${YR_ICONS_DIR}
rm -f *.png
touch yr_timestamp_reference
for i in `seq 1 50`; do
    curl -O -J -X GET --header 'Accept: image/png' "https://api.met.no/weatherapi/weathericon/1.1/?content_type=image%2Fpng&symbol=$i"
    curl -O -J -X GET --header 'Accept: image/png' "https://api.met.no/weatherapi/weathericon/1.1/?content_type=image%2Fpng&is_night=1&symbol=$i"
done
# find . -type f ! -newer yr_timestamp_reference ! -name "*.png" ! -name "$0" -delete
echo "clean up"
find . -type f -newer yr_timestamp_reference ! -iname \*.png -delete
rm -f yr_timestamp_reference
cd - >> /dev/null


echo ""
echo ""
echo ""
echo "### download fonts ###"
echo ""
FONTS_DIR="../fonts"
mkdir -p ${FONTS_DIR}
echo "downloading ubuntu and ubuntu mono font"
curl "https://raw.githubusercontent.com/google/fonts/master/ufl/ubuntu/Ubuntu-Medium.ttf" > "$FONTS_DIR/Ubuntu-M.ttf"
curl "https://raw.githubusercontent.com/google/fonts/master/ufl/ubuntumono/UbuntuMono-Regular.ttf" > "$FONTS_DIR/UbuntuMono-R.ttf"


echo ""
echo ""
echo ""
echo "### installing python3 venv ###"
echo ""
if ! python3 -m venv ../venv; then
    sleep 0.5
    echo >&2 "Some error occured. Have you python3-venv installed?"
    echo >&2 "Exiting..."
    exit 1
fi
echo "created"


echo ""
echo ""
echo ""
echo "### installing nodejs dependencies from ../lib/node/package.json ###"
echo ""
NODE_DIR="../lib/node/"
mkdir -p $NODE_DIR
cd $NODE_DIR
if ! npm install; then
    sleep 0.5
    echo >&2 "Some error occured. Exiting..."
    exit 1
fi
cd - >> /dev/null


echo ""
echo ""
echo ""
echo "### installing python dependencies from ../requirements.txt ###"
echo ""
../venv/bin/pip3 install --upgrade pip
if ! ../venv/bin/pip3 install -r ../requirements.txt; then
    sleep 0.5
    echo >&2 "Some error occured. Exiting..."
    echo ""
    echo "### Hint ### this process can fail if not run with Pi Hardware"
    echo "Press any button to continue.."
    read
fi


echo ""
echo ""
echo ""
echo "### all done ###"
echo "INFO: use './start.sh' to run in background"
echo "INFO: use './kill.sh' to kill the background process"
echo "INFO: you can run './setup.sh' again to update dependencies, fonts and assets"
