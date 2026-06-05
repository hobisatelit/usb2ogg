#!/bin/bash
# Copyright 2026 hobisatelit
# https://github.com/hobisatelit/usb2ogg
# License: GPL-3.0-or-later
# convert iq raw sat to ogg 
# exit if pipeline fails or unset variables
set -eu

# satellites list that the audio will be recorded in USB (upper side band) modulation
# 68446 - HADES-SA 

# default value, this value will be used when not set at station.env
: "${USB_ENABLE:=true}"
: "${USB_NORAD:= 68446}"
: "${SATNOGS_OUTPUT_PATH:=/tmp/.satnogs/data}"
: "${IQ_DUMP_FILENAME:=/tmp/.satnogs/iq.raw}"
: "${USB_APP_DIR:=/app/usb2ogg}"
: "${MAX_WAIT_TIME:=180}" # Maximum time, script will waiting audio .ogg from satnogs-client. Default: 3 minutes in seconds
: "${CHECK_INTERVAL:=1}"  # Check every 1 second
: "${USB_FREQ_OFFSET:=-900.0}" # in Hz, applies frequency offset adjustment and USB bandwidth filtering
: "${USB_BANDWIDTH:=2600.0}" # in Hz

# Launch with: {command} {{ID}} {{FREQ}} {{TLE}} {{TIMESTAMP}} {{BAUD}} {{SCRIPT_NAME}}
# /app/usb2ogg/usb2ogg.sh stop 14185671 436875000 '{"tle0": "HADES-SA", "tle1": "1 68446U 26067AG  26148.45558498  .00022066  00000-0  10761-2 0  9991", "tle2": "2 68446  97.4395 107.0599 0008859 130.8185 229.3819 15.18292837  8934"}' 2026-05-29T07-25-38 48000 satnogs_fm.py

ID="$2"      # $2 observation ID
TLE="$4"     # $4 used tle's
DATE="$5"    # $5 timestamp Y-m-dTH-M-S
BAUD="$6"    # $6 baudrate

# Extract satellite name and NORAD
SATNAME=${TLE#*tle0\": \"}
SATNAME=${SATNAME%%\"*}
NORAD=${TLE#*tle2\": \"2 }
NORAD=${NORAD%% *}
OGG_FILE="satnogs_${ID}_${DATE}.ogg"
OGG_FILE_UPLOAD="satnogs_${ID}_${DATE}_MOD.ogg"
ELAPSED=0

if [[ " $USB_NORAD " =~ .*\ ${NORAD}\ .* && ${USB_ENABLE,,} == true ]]; then
        echo "[USB2OGG] ✓ UPPER SIDE BAND (USB) Converter Start"
                echo "[USB2OGG] INFO: $ID, Norad: $NORAD, Sat: $SATNAME, Baud: $BAUD, TLE: $TLE"

        # run usb2ogg.py in background to make sure it executed as fast as possible
        cd "${USB_APP_DIR}"
        rm -rfv "${SATNOGS_OUTPUT_PATH}/usb.wav"
        ./usb2ogg.py --freq_offset "${USB_FREQ_OFFSET}" --bandwidth "${USB_BANDWIDTH}" "${IQ_DUMP_FILENAME}"* "${SATNOGS_OUTPUT_PATH}/usb.wav"  && ./sox "${SATNOGS_OUTPUT_PATH}/usb.wav" -C 10 "${SATNOGS_OUTPUT_PATH}/${OGG_FILE_UPLOAD}" && echo "[USB2OGG] ✓ ${OGG_FILE_UPLOAD} Saved!" &

        cd $SATNOGS_OUTPUT_PATH

        # Loop until original ogg file from satnogs_client is ready or timeout.
        # this function to make sure the original .ogg file from satnogs_client is deleted
        while [ $ELAPSED -lt $MAX_WAIT_TIME ]; do
                # Check if file exists and is readable
                if [ -f "$OGG_FILE" ]; then
                       echo "[USB2OGG] ✓ DELETE ORIGINAL ${OGG_FILE} .." 
                       rm -rfv $OGG_FILE
                       #exit 0
                       break
                fi

                # Sleep before next check
                sleep $CHECK_INTERVAL
                ELAPSED=$((ELAPSED + CHECK_INTERVAL))

                # Optional: Print progress every 10 seconds
                if [ $((ELAPSED % 10)) -eq 0 ]; then
                        echo "[USB2OGG] Still waiting... ($ELAPSED seconds elapsed)"
                fi
        done

fi
