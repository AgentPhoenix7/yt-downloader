#!/bin/bash

# === Metadata ===
VERSION="1.0.0"
SCRIPT_NAME="youtube_downloader.sh"
UPDATE_URL="https://raw.githubusercontent.com/AgentPhoenix7/yt-downloader/main/$SCRIPT_NAME"

# === Colors ===
BOLD='\033[1m'
RESET='\033[0m'
@@ -8,119 +13,223 @@ CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'

# === Defaults ===
USE_CLIPBOARD=1
TYPE=""
FORMAT=""
FMT=""
URL=""
SAVE_DIR=""
QUALITY=""

# === Help screen ===
print_help() {
  echo -e "${CYAN}${BOLD}YouTube Downloader - CLI Options${RESET}"
  echo -e "${YELLOW}Usage:${RESET} ./youtube_downloader.sh [options]"
  echo -e ""
  echo -e "${YELLOW}Options:${RESET}"
  echo -e "  --url URL            📺  Provide a YouTube video or playlist URL"
  echo -e "  --audio              🎵  Download audio only (e.g., mp3)"
  echo -e "  --video              🎞️  Download full video"
  echo -e "  --format FORMAT      🔊  Audio format (e.g., mp3, m4a). Default: mp3"
  echo -e "  --quality QUALITY    📼  Video quality: best, medium, or worst"
  echo -e "  --dir PATH           📁  Download directory (default: \$HOME)"
  echo -e "  --no-clipboard       ❌  Disable clipboard auto-paste"
  echo -e "  --check-update       🔍  Check for newer version"
  echo -e "  --update             ⬆️   Auto-update script from GitHub"
  echo -e "  -h, --help           📖  Show this help message"
  exit 0
}

# === Parse CLI args ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --audio) TYPE="Audio only"; shift ;;
    --video) TYPE="Audio + Video"; shift ;;
    --format) FORMAT="$2"; shift 2 ;;
    --quality) QUALITY="$2"; shift 2 ;;
    --dir) SAVE_DIR="$2"; shift 2 ;;
    --no-clipboard) USE_CLIPBOARD=0; shift ;;
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
      exit 0
      ;;
    --update)
      echo -e "${CYAN}⬇️  Downloading latest version...${RESET}"
      curl -s -o "$0.tmp" "$UPDATE_URL" || {
        echo -e "${RED}❌ Failed to fetch update.${RESET}"
        exit 1
      }
      chmod +x "$0.tmp"
      mv "$0.tmp" "$0"
      echo -e "${GREEN}✅ Script updated to latest version.${RESET}"
      exit 0
      ;;
    -h|--help) print_help ;;
    *) echo -e "${RED}⚠️  Unknown option: $1${RESET}"; print_help ;;
  esac
done

# === Temp setup ===
COMMANDS_FILE=$(mktemp)
LOG_FILE="/tmp/yt-dlp-error-$(date +%s).log"
trap 'rm -f "$COMMANDS_FILE"; echo -e "${RED}\nInterrupted. Temp files cleaned.${RESET}"; exit 1' INT TERM

clear
echo -e "${CYAN}${BOLD}YouTube Downloader - Terminal Edition (v$VERSION)${RESET}"

# === Clipboard support ===
if [[ -z "$URL" && "$USE_CLIPBOARD" == 1 ]]; then
  if command -v wl-paste &>/dev/null; then
    CLIP_URL=$(wl-paste --no-newline 2>/dev/null)
  elif command -v xclip &>/dev/null; then
    CLIP_URL=$(xclip -o -selection clipboard 2>/dev/null)
  elif command -v xsel &>/dev/null; then
    CLIP_URL=$(xsel --clipboard 2>/dev/null)
  fi

  if [[ "$CLIP_URL" =~ ^https?://(www\.)?(youtube\.com|youtu\.be)/ ]]; then
    echo -e "${YELLOW}📋 Clipboard contains a YouTube link:${RESET}"
    echo -e "→ $CLIP_URL"
    echo -en "Use this URL? (Y/n): "
    read -r USE_CLIP
    case "$USE_CLIP" in
      [nN]*) CLIP_URL="";;
    esac
    [[ -n "$CLIP_URL" ]] && URL="$CLIP_URL"
  fi
fi

# === URL prompt fallback ===
if [[ -z "$URL" ]]; then
  echo -e "${YELLOW}Paste the full YouTube URL (video or playlist):${RESET}"
  echo -en "Example: https://www.youtube.com/watch?v=abc123\n> "
  read -r URL
fi





[[ -z "$URL" ]] && echo -e "${RED}No URL entered. Exiting.${RESET}" && exit 1
if ! [[ "$URL" =~ ^https?://(www\.)?(youtube\.com|youtu\.be)/ ]]; then
  echo -e "${RED}Invalid YouTube URL. Exiting.${RESET}"
  exit 1
fi

# === Playlist or single video ===
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

# === Download type ===
if [[ -z "$TYPE" ]]; then
  echo -e "${YELLOW}Choose download type:${RESET}"
  select TYPE in "Audio only" "Audio + Video"; do
    [[ -n "$TYPE" ]] && break
  done
fi

# === Format or quality ===
if [[ "$TYPE" == "Audio only" ]]; then
  if [[ -z "$FORMAT" ]]; then
    echo -e "${YELLOW}Enter audio format (default: mp3):${RESET}"

    read -r FORMAT
    FORMAT=${FORMAT:-mp3}
  fi
else
  if [[ -n "$QUALITY" ]]; then
    case $QUALITY in
      best) FMT="bestvideo+bestaudio/best" ;;
      medium) FMT="bv[height<=480]+ba/best[height<=480]" ;;
      worst) FMT="worstvideo+worstaudio/worst" ;;
      *) echo -e "${RED}Invalid quality: $QUALITY${RESET}"; exit 1 ;;
    esac
  else
    echo -e "${YELLOW}Choose video quality:${RESET}"
    select QUALITY in "Best" "Medium (480p)" "Worst"; do
      case $QUALITY in
        "Best") FMT="bestvideo+bestaudio/best"; break ;;
        "Medium (480p)") FMT="bv[height<=480]+ba/best[height<=480]"; break ;;
        "Worst") FMT="worstvideo+worstaudio/worst"; break ;;
        *) echo -e "${RED}Invalid option. Try again.${RESET}" ;;
      esac
    done
  fi
fi

# === Save directory ===
if [[ -z "$SAVE_DIR" ]]; then
  echo -e "${YELLOW}Enter save directory (default: $HOME):${RESET}"
  read -r SAVE_DIR
  SAVE_DIR=${SAVE_DIR:-$HOME}
fi

mkdir -p "$SAVE_DIR" || { echo -e "${RED}Cannot create directory. Exiting.${RESET}"; exit 1; }
ARCHIVE_FILE="$SAVE_DIR/.yt-dlp-archive.txt"

# === Build commands ===
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

# === Run ===
echo -e "${CYAN}⏬ Starting downloads...${RESET}"
parallel --joblog "$LOG_FILE" --eta < "$COMMANDS_FILE"

# === Notify ===
if command -v notify-send &>/dev/null; then
  notify-send "YouTube Downloader" "All downloads completed!" --icon=video
fi

rm -f "$COMMANDS_FILE"
echo -e "${GREEN}${BOLD}✔️ All downloads completed successfully!${RESET}"
echo -e "${CYAN}📝 Error log (if any): ${LOG_FILE}${RESET}"