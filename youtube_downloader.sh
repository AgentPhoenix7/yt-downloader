#!/bin/bash

# === Colors ===
BOLD='\033[1m'
RESET='\033[0m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'

# === Temp & Archive Setup ===
COMMANDS_FILE=$(mktemp)
LOG_FILE="/tmp/yt-dlp-error-$(date +%s).log"
trap 'rm -f "$COMMANDS_FILE"; echo -e "${RED}\nInterrupted. Temp files cleaned.${RESET}"; exit 1' INT TERM

clear
echo -e "${CYAN}${BOLD}YouTube Downloader - Terminal Edition${RESET}"

# === Step 1: URL Input ===
echo -e "${YELLOW}Paste the full YouTube URL (single video or playlist).${RESET}"
echo -en "${YELLOW}Example: https://www.youtube.com/watch?v=abc123${RESET}\n> "
read -r URL
[[ -z "$URL" ]] && echo -e "${RED}No URL entered. Exiting.${RESET}" && exit 1
if ! [[ "$URL" =~ ^https?://(www\.)?(youtube\.com|youtu\.be)/ ]]; then
    echo -e "${RED}Invalid YouTube URL. Exiting.${RESET}"
    exit 1
fi

# === Step 2: Playlist or Video ===
IS_PLAYLIST=$(yt-dlp --flat-playlist --no-warnings -J "$URL" 2>/dev/null | jq -r 'has("entries")')

if [[ "$IS_PLAYLIST" == "true" ]]; then
    echo -e "${CYAN}Fetching playlist... Use ↑↓ to move, <tab> to select, <enter> to confirm.${RESET}"
    METADATA=$(yt-dlp --flat-playlist -J "$URL" 2>/dev/null)
    ENTRIES=$(echo "$METADATA" | jq -r '.entries[] | "\(.title) | \(.id)"' | fzf --multi --header="Select videos to download")
    [[ -z "$ENTRIES" ]] && echo -e "${RED}No videos selected. Exiting.${RESET}" && exit 1
else
    echo -e "${CYAN}Single video detected.${RESET}"
    VIDEO_ID=$(yt-dlp --get-id "$URL")
    VIDEO_TITLE=$(yt-dlp --get-title "$URL")
    ENTRIES="$VIDEO_TITLE | $VIDEO_ID"
fi

# === Step 3: Audio or Video ===
echo -e "${YELLOW}Choose download type:${RESET}"
echo -e "1. Audio only (e.g., MP3, M4A)\n2. Audio + Video (full video)"
select TYPE in "Audio only" "Audio + Video"; do
    [[ -n "$TYPE" ]] && break
done

# === Step 4: Format/Quality ===
if [[ "$TYPE" == "Audio only" ]]; then
    echo -e "${YELLOW}Enter desired audio format.${RESET}"
    echo -e "Common options: mp3, m4a, flac, wav"
    echo -en "Leave blank for default (mp3):\n> "
    read -r FORMAT
    FORMAT=${FORMAT:-mp3}
else
    echo -e "${YELLOW}Choose video quality preset:${RESET}"
    echo -e "1. Best (highest available)\n2. Medium (up to 480p)\n3. Worst (lowest quality)"
    select QUALITY in "Best" "Medium (480p)" "Worst"; do
        case $QUALITY in
            "Best") FMT="bestvideo+bestaudio/best"; break ;;
            "Medium (480p)") FMT="bv[height<=480]+ba/best[height<=480]"; break ;;
            "Worst") FMT="worstvideo+worstaudio/worst"; break ;;
            *) echo -e "${RED}Invalid option. Try again.${RESET}" ;;
        esac
    done
fi

# === Step 5: Save Directory ===
echo -e "${YELLOW}Enter directory where downloads will be saved.${RESET}"
echo -en "Leave blank for default: $HOME\n> "
read -r SAVE_DIR
SAVE_DIR=${SAVE_DIR:-$HOME}
[[ -z "$SAVE_DIR" ]] && echo -e "${RED}No directory provided. Exiting.${RESET}" && exit 1
mkdir -p "$SAVE_DIR" || { echo -e "${RED}Cannot create directory.${RESET}"; exit 1; }
ARCHIVE_FILE="$SAVE_DIR/.yt-dlp-archive.txt"

# === Step 6: Build Download Commands ===
TOTAL=$(echo "$ENTRIES" | wc -l)
i=1

while IFS='|' read -r TITLE ID; do
    TITLE=$(echo "$TITLE" | xargs)
    ID=$(echo "$ID" | xargs)
    SAFE_TITLE=$(printf "%q" "$TITLE")
    VIDEO_URL="https://www.youtube.com/watch?v=$ID"

    if [[ "$TYPE" == "Audio only" ]]; then
        echo "echo '[$i/$TOTAL] Downloading: $SAFE_TITLE'; yt-dlp \
        --download-archive '$ARCHIVE_FILE' \
        --no-overwrites --restrict-filenames --continue --no-part \
        --write-thumbnail --embed-thumbnail \
        --write-sub --write-auto-sub --sub-lang en --sub-format srt \
        --retries infinite --fragment-retries infinite --abort-on-error \
        -f bestaudio --extract-audio --audio-format $FORMAT \
        -o '$SAVE_DIR/%(title)s.%(ext)s' '$VIDEO_URL' \
        && rm -f '$SAVE_DIR/'*.webp '$SAVE_DIR/'*.srt" \
        >> "$COMMANDS_FILE"
    else
        echo "echo '[$i/$TOTAL] Downloading: $SAFE_TITLE'; yt-dlp \
        --download-archive '$ARCHIVE_FILE' \
        --no-overwrites --restrict-filenames --continue --no-part \
        --write-thumbnail --embed-thumbnail \
        --write-sub --write-auto-sub --sub-lang en --sub-format srt --embed-subs \
        --retries infinite --fragment-retries infinite --abort-on-error \
        -f '$FMT' -o '$SAVE_DIR/%(title)s.%(ext)s' '$VIDEO_URL' \
        && rm -f '$SAVE_DIR/'*.webp '$SAVE_DIR/'*.srt" \
        >> "$COMMANDS_FILE"
    fi
    ((i++))
done <<< "$ENTRIES"

# === Step 7: Run Downloads in Parallel ===
echo -e "${CYAN}Starting parallel downloads...${RESET}"
parallel --joblog "$LOG_FILE" --eta < "$COMMANDS_FILE"

# === Step 8: Notify on Completion ===
if command -v notify-send &>/dev/null; then
    notify-send "YouTube Downloader" "All downloads completed!" --icon=video
fi

rm -f "$COMMANDS_FILE"
echo -e "${GREEN}${BOLD}All downloads completed successfully!${RESET}"
echo -e "${CYAN}Error log (if any): ${LOG_FILE}${RESET}"
