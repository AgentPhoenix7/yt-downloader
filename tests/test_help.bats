#!/usr/bin/env bats

@test "display help" {
  run ../youtube_downloader.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"YouTube Downloader - CLI Options"* ]]
}
