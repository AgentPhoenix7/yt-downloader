#!/bin/bash

# === Metadata ===
VERSION="1.0.0"
SCRIPT_NAME="youtube_downloader.sh"
UPDATE_URL="https://raw.githubusercontent.com/AgentPhoenix7/yt-downloader/main/$SCRIPT_NAME"

# === Colors ===
BOLD='\033[1m'
RESET='\033[0m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

# === Help screen ===
print_help() {
  echo -e "${CYAN}${BOLD}YouTube Downloader - CLI Options${RESET}"
  echo -e "${YELLOW}Usage:${RESET} ${GREEN}./youtube_downloader.sh [options]${RESET}"
  echo -e ""
  echo -e "${YELLOW}Options:${RESET}"
  echo -e "  ${CYAN}--url URL${RESET}            ${BLUE}📺  Provide a YouTube video or playlist URL${RESET}"
  echo -e "  ${CYAN}--audio${RESET}              ${BLUE}🎵  Download audio only (e.g., mp3)${RESET}"
  echo -e "  ${CYAN}--video${RESET}              ${BLUE}🎞️  Download full video${RESET}"
  echo -e "  ${CYAN}--format FORMAT${RESET}      ${BLUE}🔊  Audio format (e.g., mp3, m4a). Default: mp3${RESET}"
  echo -e "  ${CYAN}--quality QUALITY${RESET}    ${BLUE}📼  Video quality: best, medium, or worst${RESET}"
  echo -e "  ${CYAN}--dir PATH${RESET}           ${BLUE}📁  Download directory (default: $HOME)${RESET}"
  echo -e "  ${CYAN}--no-clipboard${RESET}       ${BLUE}❌  Disable clipboard auto-paste${RESET}"
  echo -e "  ${CYAN}--check-update${RESET}       ${BLUE}🔍  Check for newer version${RESET}"
  echo -e "  ${CYAN}--update${RESET}             ${BLUE}⬆️   Auto-update script from GitHub${RESET}"
  echo -e "  ${CYAN}-h, --help${RESET}           ${BLUE}📖  Show this help message${RESET}"
  exit 0
}

# === Parse CLI args ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      URL="$2"; shift 2 ;;
    --audio)
      TYPE="Audio only"; shift ;;
    --video)
      TYPE="Audio + Video"; shift ;;
    --format)
      FORMAT="$2"; shift 2 ;;
    --quality)
      QUALITY="$2"; shift 2 ;;
    --dir)
      SAVE_DIR="$2"; shift 2 ;;
    --no-clipboard)
      USE_CLIPBOARD=0; shift ;;
    --check-update)
      echo -e "${CYAN}🔍 Checking for updates...${RESET}"
      REMOTE_VERSION=$(curl -s "$UPDATE_URL" | grep -E '^VERSION=' | cut -d'"' -f2)
      if [[ -z "$REMOTE_VERSION" ]]; then
        echo -e "${RED}❌ Could not fetch remote version.${RESET}"
        exit 1
      fi
      if [[ "$VERSION" != "$REMOTE_VERSION" ]]; then
        echo -e "${YELLOW}⚠️  Update available: $VERSION → $REMOTE_VERSION${RESET}"
        echo -e "Run: ${CYAN}$0 --update${RESET} to upgrade."
      else
        echo -e "${GREEN}✅ You're using the latest version: $VERSION${RESET}"
      fi
      exit 0 ;;
    --update)
      echo -e "${CYAN}⬇️  Downloading latest version...${RESET}"
      curl -s -o "$0.tmp" "$UPDATE_URL" || {
        echo -e "${RED}❌ Failed to fetch update.${RESET}"
        exit 1
      }
      chmod +x "$0.tmp"
      mv "$0.tmp" "$0"
      echo -e "${GREEN}✅ Script updated to latest version.${RESET}"
      exit 0 ;;
    -h|--help)
      print_help ;;
    *)
      echo -e "${RED}⚠️  Unknown option: '$1'${RESET}"
      echo -e "   Use ${CYAN}--help${RESET} to see available options."
      exit 1 ;;
  esac
done

# === Temp & Archive Setup ===
COMMANDS_FILE=$(mktemp)
LOG_FILE="/tmp/yt-dlp-error-$(date +%s).log"
trap 'rm -f "$COMMANDS_FILE"; echo -e "${RED}\nInterrupted. Temp files cleaned.${RESET}"; exit 1' INT TERM

clear
echo -e "${CYAN}${BOLD}YouTube Downloader - Terminal Edition${RESET}"

# === Step 1: URL Input ===
echo -e "${YELLOW}${BOLD}📥 Paste the full YouTube URL (single video or playlist).${RESET}"
echo -en "${YELLOW}Example: https://www.youtube.com/watch?v=abc123${RESET}\n> "
read -r URL
[[ -z "$URL" ]] && echo -e "${RED}❌ No URL entered. Exiting.${RESET}" && exit 1
if ! [[ "$URL" =~ ^https?://(www\.)?(youtube\.com|youtu\.be)/ ]]; then
    echo -e "${RED}❌ Invalid YouTube URL. Exiting.${RESET}"
    exit 1
fi

# === Step 2: Playlist or Video ===
IS_PLAYLIST=$(yt-dlp --flat-playlist --no-warnings -J "$URL" 2>/dev/null | jq -r 'has("entries")')

if [[ "$IS_PLAYLIST" == "true" ]]; then
    echo -e "${CYAN}📃 Playlist detected. Use ↑↓ to move, <tab> to select, <enter> to confirm.${RESET}"
    METADATA=$(yt-dlp --flat-playlist -J "$URL" 2>/dev/null)
    ENTRIES=$(echo "$METADATA" | jq -r '.entries[] | "\(.title) | \(.id)"' | fzf --multi --header="🎯 Select videos to download")
    [[ -z "$ENTRIES" ]] && echo -e "${RED}❌ No videos selected. Exiting.${RESET}" && exit 1
else
    echo -e "${CYAN}🎬 Single video detected.${RESET}"
    VIDEO_ID=$(yt-dlp --get-id "$URL")
    VIDEO_TITLE=$(yt-dlp --get-title "$URL")
    ENTRIES="$VIDEO_TITLE | $VIDEO_ID"
fi

# === Step 3: Audio or Video ===
echo -e "${YELLOW}${BOLD}🎚️ Choose download type:${RESET}"
echo -e "1. 🎵 Audio only (e.g., MP3, M4A)\n2. 🎞️ Audio + Video (full video)"
select TYPE in "Audio only" "Audio + Video"; do
    [[ -n "$TYPE" ]] && break
done

# === Step 4: Format/Quality ===
if [[ "$TYPE" == "Audio only" ]]; then
    echo -e "${YELLOW}🎧 Enter desired audio format.${RESET}"
    echo -e "Supported formats: ${CYAN}mp3${RESET}, ${CYAN}m4a${RESET}, ${CYAN}flac${RESET}, ${CYAN}wav${RESET}, ${CYAN}opus${RESET}"
    echo -en "Leave blank for default (mp3):\n> "
    read -r FORMAT
    FORMAT=${FORMAT:-mp3}
else
    echo -e "${YELLOW}${BOLD}🎞️ Choose video quality preset:${RESET}"
    echo -e "1. 📈 Best (highest available)\n2. 📉 Medium (up to 480p)\n3. 🪶 Worst (lowest quality)"
    select QUALITY in "Best" "Medium (480p)" "Worst"; do
        case $QUALITY in
            "Best") FMT="bestvideo+bestaudio/best"; break ;;
            "Medium (480p)") FMT="bv[height<=480]+ba/best[height<=480]"; break ;;
            "Worst") FMT="worstvideo+worstaudio/worst"; break ;;
            *) echo -e "${RED}❌ Invalid option. Try again.${RESET}" ;;
        esac
    done
fi

# === Step 5: Save Directory ===
echo -e "${YELLOW}📁 Enter directory where downloads will be saved.${RESET}"
echo -en "Leave blank for default: $HOME\n> "
read -r SAVE_DIR
SAVE_DIR=${SAVE_DIR:-$HOME}
[[ -z "$SAVE_DIR" ]] && echo -e "${RED}❌ No directory provided. Exiting.${RESET}" && exit 1
mkdir -p "$SAVE_DIR" || { echo -e "${RED}❌ Cannot create directory.${RESET}"; exit 1; }
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
        echo "echo '[\$i/\$TOTAL] Downloading: \$SAFE_TITLE'; yt-dlp \
        --download-archive '\$ARCHIVE_FILE' \
        --no-overwrites --restrict-filenames --continue --no-part \
        --write-thumbnail --embed-thumbnail \
        --write-sub --write-auto-sub --sub-lang en --sub-format srt \
        --retries infinite --fragment-retries infinite --abort-on-error \
        -f bestaudio --extract-audio --audio-format \$FORMAT \
        -o '\$SAVE_DIR/%(title)s.%(ext)s' '\$VIDEO_URL' \
        && rm -f '\$SAVE_DIR/'*.webp '\$SAVE_DIR/'*.srt" \
        >> "$COMMANDS_FILE"
    else
        echo "echo '[\$i/\$TOTAL] Downloading: \$SAFE_TITLE'; yt-dlp \
        --download-archive '\$ARCHIVE_FILE' \
        --no-overwrites --restrict-filenames --continue --no-part \
        --write-thumbnail --embed-thumbnail \
        --write-sub --write-auto-sub --sub-lang en --sub-format srt --embed-subs \
        --retries infinite --fragment-retries infinite --abort-on-error \
        -f '\$FMT' -o '\$SAVE_DIR/%(title)s.%(ext)s' '\$VIDEO_URL' \
        && rm -f '\$SAVE_DIR/'*.webp '\$SAVE_DIR/'*.srt" \
        >> "$COMMANDS_FILE"
    fi
    ((i++))
done <<< "$ENTRIES"

# === Step 7: Run Downloads in Parallel ===
echo -e "${CYAN}🚀 Starting parallel downloads...${RESET}"
parallel --joblog "$LOG_FILE" --eta < "$COMMANDS_FILE"

# === Step 8: Notify on Completion ===
if command -v notify-send &>/dev/null; then
    notify-send "YouTube Downloader" "All downloads completed!" --icon=video
fi

rm -f "$COMMANDS_FILE"
echo -e "${GREEN}${BOLD}✅ All downloads completed successfully!${RESET}"
echo -e "${CYAN}📄 Error log (if any): ${LOG_FILE}${RESET}"
