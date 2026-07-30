#!/bin/sh
# ==============================================================================
#  socaToDate v1.0 - Automated Enigma2 IPTV Bouquet & Stream URL Updater
# ==============================================================================
#  Description: Synchronizes live stream URLs from your provider's M3U playlist 
#               with your Enigma2 userbouquet file without altering channel names 
#               or bouquet structure.
#  Author:      SocaDLV - https://github.com/SocaDLV
#  License:     MIT
# ==============================================================================

# ------------------------------------------------------------------------------
# USER CONFIGURATION
# ------------------------------------------------------------------------------
# Paste your IPTV provider's M3U URL here:
M3U_URL="YOUR_M3U_URL_HERE"

# Temporary workspace & logs directory (USB drive recommended to save Flash RAM)
BASE_DIR="/media/hdd/socaToDate"

# Enigma2 bouquets directory
E2_DIR="/etc/enigma2"

# User-Agent string for downloads (prevents server blocking)
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Display On-Screen Messages in Enigma2 (1 = Yes, 0 = No)
SHOW_OSD=1

# Restart Enigma2 GUI after updating (1 = Yes, 0 = No)
RESTART_GUI=1

# ------------------------------------------------------------------------------
# SCRIPT EXECUTION
# ------------------------------------------------------------------------------
TODAY=$(date +"%d_%m_%Y")
WORK_DIR="$BASE_DIR/$TODAY"

# Helper function to send messages via OpenWebif
send_osd_msg() {
    [ "$SHOW_OSD" -eq 1 ] && wget -qO - "http://127.0.0.1/web/message?text=$1&type=$2&timeout=5" > /dev/null 2>&1
}

# 1. Locate the existing IPTV userbouquet
BOUQUET_PATH=$(ls "$E2_DIR"/userbouquet.iptv*.tv 2>/dev/null | head -n 1)
if [ -z "$BOUQUET_PATH" ]; then
    send_osd_msg "SocaToDate%20Error%3A%20No%20userbouquet.iptv%20file%20found%20in%20/etc/enigma2" 3
    echo "[ERROR] No userbouquet.iptv*.tv file found in $E2_DIR"
    exit 1
fi

if [ "$M3U_URL" = "YOUR_M3U_URL_HERE" ] || [ -z "$M3U_URL" ]; then
    send_osd_msg "SocaToDate%20Error%3A%20M3U_URL%20is%20not%20configured%20in%20script" 3
    echo "[ERROR] M3U_URL is empty or not configured."
    exit 1
fi

BOUQUET_FILE=$(basename "$BOUQUET_PATH")
COUNT_UPDATED=0

# Define working file paths
M3U_FILE="$WORK_DIR/channels_$TODAY.m3u"
M3U_PARSED="$WORK_DIR/m3u_parsed.txt"
M3U_UNMATCHED="$WORK_DIR/m3u_unmatched.txt"
BOUQUET_COPIA="$WORK_DIR/userbouquet.iptv_${TODAY}__tv.tv"
BOUQUET_EDITADO="$WORK_DIR/nuevo_userbouquet.tv"
NO_MATCH_FILE="$WORK_DIR/userbouquet.iptv_NO_MATCH_${TODAY}__tv.tv"
LOG_FILE="$WORK_DIR/log_$TODAY.txt"

# Prepare workspace
if [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
fi
mkdir -p "$WORK_DIR"
> "$LOG_FILE"

echo "[INFO] Starting SocaToDate IPTV update..." >> "$LOG_FILE"

# Download M3U playlist with User-Agent spoofing
wget -qO "$M3U_FILE" --user-agent="$USER_AGENT" "$M3U_URL"

# Verify downloaded M3U validity
if [ ! -f "$M3U_FILE" ] || ! grep -q "#EXTM3U" "$M3U_FILE"; then
    echo "[ERROR] Downloaded file is not a valid M3U playlist." >> "$LOG_FILE"
    send_osd_msg "SocaToDate%20Error%3A%20Failed%20to%20download%20M3U%20playlist" 3
    exit 1
fi

# Parse M3U channel names and URLs (stops at VOD/Movies/Series)
awk -F',' '
/^#EXTINF/ {
    if ($0 ~ /group-title=".*VOD/) { exit }
    name=$NF
    sub(/[ \t\r]+$/, "", name)
}
/^http/ {
    if ($0 ~ /\/movie\// || $0 ~ /\/series\//) { exit }
    
    if (name != "") {
        url=$0
        sub(/[ \t\r]+$/, "", url)
        gsub(/:/, "%3A", url)
        gsub(/&/, "%26", url)
        print name "|" url
        name=""
    }
}' "$M3U_FILE" > "$M3U_PARSED"

cp "$BOUQUET_PATH" "$BOUQUET_COPIA"
cp "$M3U_PARSED" "$M3U_UNMATCHED"
> "$BOUQUET_EDITADO"

# Compare Enigma2 bouquet links against updated M3U URLs
while IFS= read -r line || [ -n "$line" ]; do
    line=$(echo "$line" | tr -d '\r')
    
    if echo "$line" | grep -q "^#NAME"; then
        echo "#NAME IPTV $TODAY" >> "$BOUQUET_EDITADO"
        
    elif echo "$line" | grep -q "^#SERVICE .*http"; then
        NAME_E2=$(echo "$line" | awk -F':' '{print $NF}' | sed 's/[ \t]*$//')
        PREFIX=$(echo "$line" | cut -d':' -f1-10)
        OLD_URL=$(echo "$line" | cut -d':' -f11)
        
        MATCH=$(awk -F'|' -v n="$NAME_E2" '$1 == n {print $0; exit}' "$M3U_PARSED")
        
        if [ -n "$MATCH" ]; then
            NEW_URL=$(echo "$MATCH" | cut -d'|' -f2-)
            NEW_LINE="${PREFIX}:${NEW_URL}:${NAME_E2}"
            
            if [ "$OLD_URL" != "$NEW_URL" ]; then
                echo "$NEW_LINE" >> "$BOUQUET_EDITADO"
                echo "UPDATED_LINK: $NAME_E2" >> "$LOG_FILE"
                COUNT_UPDATED=$((COUNT_UPDATED + 1))
            else
                echo "$line" >> "$BOUQUET_EDITADO"
                echo "NO_CHANGE: $NAME_E2" >> "$LOG_FILE"
            fi
            
            awk -F'|' -v n="$NAME_E2" '$1 != n' "$M3U_UNMATCHED" > "${M3U_UNMATCHED}.tmp"
            mv "${M3U_UNMATCHED}.tmp" "$M3U_UNMATCHED"
        else
            echo "$line" >> "$BOUQUET_EDITADO"
            echo "NOT_FOUND_ONLINE: $NAME_E2" >> "$LOG_FILE"
        fi
    else
        echo "$line" >> "$BOUQUET_EDITADO"
    fi
done < "$BOUQUET_COPIA"

# Generate bouquet with new/unmatched channels from M3U
echo "#NAME NEW IPTV CHANNELS $TODAY" > "$NO_MATCH_FILE"
while IFS='|' read -r name url || [ -n "$name" ]; do
    if [ -n "$name" ]; then
        echo "#SERVICE 4097:0:1:0:0:0:0:0:0:0:${url}:${name}" >> "$NO_MATCH_FILE"
        echo "#DESCRIPTION $name" >> "$NO_MATCH_FILE"
        echo "NEW_CHANNEL: $name" >> "$LOG_FILE"
    fi
done < "$M3U_UNMATCHED"

# Apply updated bouquet to Enigma2
cp "$BOUQUET_EDITADO" "$BOUQUET_PATH"

echo "[SUCCESS] Update completed. Links updated: $COUNT_UPDATED" >> "$LOG_FILE"

# Send On-Screen notification
MSG="SocaToDate%20Updated%20%3B%29%0ALinks%20updated%3A%20$COUNT_UPDATED"
send_osd_msg "$MSG" 1

# Cleanup temporary files
rm -f "$M3U_PARSED" "$M3U_UNMATCHED" "$BOUQUET_EDITADO"

# Restart Enigma2 GUI if enabled
if [ "$RESTART_GUI" -eq 1 ]; then
    sleep 3
    wget -qO - "http://127.0.0.1/web/powerstate?newstate=3" > /dev/null 2>&1
fi

exit 0