#!/bin/zsh
set -euo pipefail

APP_NAME="Scribbles-N-Scripts"
DEFAULT_X="${1:-80}"
DEFAULT_Y="${2:-60}"
DEFAULT_WIDTH="${3:-1440}"
DEFAULT_HEIGHT="${4:-920}"

if ! osascript -e "tell application \"System Events\" to get name of every process whose visible is true" | grep -q "$APP_NAME"; then
  echo "$APP_NAME is not visible. Launch it first with 'swift run $APP_NAME' or from the built binary." >&2
  exit 1
fi

osascript \
  -e "tell application \"System Events\" to tell process \"$APP_NAME\" to set frontmost to true" \
  -e "tell application \"System Events\" to tell process \"$APP_NAME\" to set position of front window to {$DEFAULT_X, $DEFAULT_Y}" \
  -e "tell application \"System Events\" to tell process \"$APP_NAME\" to set size of front window to {$DEFAULT_WIDTH, $DEFAULT_HEIGHT}" \
  -e "tell application \"System Events\" to tell process \"$APP_NAME\" to set focused of front window to true"

sleep 1

osascript \
  -e "tell application \"System Events\" to tell process \"$APP_NAME\" to get {name of front window, position of front window, size of front window}"
