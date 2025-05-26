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
        echo -e "${GREEN}✅ You are using the latest version: $VERSION${RESET}"
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
      echo -e "${GREEN}✅ Script updated to latest version!${RESET}"
      exit 0
      ;;
    -h|--help) print_help ;;
    *) echo -e "${RED}⚠️  Unknown option: $1${RESET}"; print_help ;;
  esac
done
