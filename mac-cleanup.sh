#!/bin/bash
# mac-cleanup.sh v2 — find and clean non-critical "System Data" on macOS
#
#   ./mac-cleanup.sh                        scan only, deletes nothing
#   ./mac-cleanup.sh --clean                ask about every non-empty, non-critical item
#   ./mac-cleanup.sh --clean --min-mb 100   also review smaller app folders (default 500 MB)
#
# Caches/logs/build junk are deleted outright (they regenerate).
# App data folders and screen recordings are MOVED TO TRASH (recoverable) —
# empty the Trash afterwards to actually reclaim the space.
#
# Never offered: anything Apple-owned (com.apple.*), password managers,
# iCloud/backups/Mail/Messages data, /System, swap, /private/var/folders.
# Give Terminal Full Disk Access for accurate sizes; quit apps before cleaning.

set -u
MODE="scan"; MIN_MB=500
while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean) MODE="clean" ;;
    --min-mb) MIN_MB="${2:?need a number}"; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
  esac
  shift
done

B=$(tput bold 2>/dev/null || true); R=$(tput sgr0 2>/dev/null || true)
FREE_BEFORE=$(df -k / | awk 'NR==2{print $4}')
TRASHED_KB=0
LIB="$HOME/Library"

human() { awk -v k="${1:-0}" 'BEGIN{split("KB MB GB TB",u);i=1;while(k>=1024&&i<4){k/=1024;i++};printf "%.1f %s",k,u[i]}'; }

size_kb() {
  local total=0 p s
  for p in "$@"; do
    [[ -e "$p" ]] || continue
    s=$(du -sk "$p" 2>/dev/null | awk '{print $1}')
    total=$((total + ${s:-0}))
  done
  echo "$total"
}

item() { printf "%s%-40s%s %10s   %s\n" "$B" "$1" "$R" "$(human "$2")" "${3:-}"; }

# y/N prompt; never asks for empty items or in scan mode
confirm() {
  [[ "$MODE" == "clean" && "${1:-0}" -gt 0 ]] || return 1
  local ans; read -r -p "    -> Clean this? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# Trash / Open / Skip prompt for things that aren't pure junk
choose() {
  local ans; read -r -p "    -> [t] move to Trash  [o] open in Finder  [s] skip: " ans
  echo "${ans:-s}"
}

empty_dir() {
  local p
  for p in "$@"; do
    [[ -d "$p" ]] && find "$p" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
  done
}

to_trash() {
  local src="$1" kb dest
  kb=$(size_kb "$src")
  dest="$HOME/.Trash/$(basename "$src")"
  [[ -e "$dest" ]] && dest="$dest $(date +%H%M%S)"
  mv "$src" "$dest" && TRASHED_KB=$((TRASHED_KB + kb)) && echo "    moved to Trash"
}

# Folders that are never offered in the app-data review
is_protected() {
  case "$1" in
    *com.apple*|*Apple*|AddressBook|CallHistory*|MobileSync|Knowledge|CloudDocs|FileProvider|iCloud*|\
    CrashReporter|*[Aa]gilebits*|*1[Pp]assword*|*[Bb]itwarden*|*[Kk]eychain*|*[Dd]ocker*|*orbstack*)
      return 0 ;;
  esac
  return 1
}

echo
echo "${B}=== Where the space is going (largest items in ~/Library) ===${R}"
for d in "$LIB" "$LIB/Application Support" "$LIB/Containers" "$LIB/Group Containers"; do
  [[ -d "$d" ]] || continue
  echo "-- $d"
  du -sk "$d"/* 2>/dev/null | sort -rn | head -8 | while IFS=$'\t' read -r kb path; do
    printf "   %10s  %s\n" "$(human "$kb")" "${path#$d/}"
  done
done

echo
echo "${B}=== Junk (deleted outright — regenerates) ===${R}"

S=$(size_kb "$LIB/Caches");  item "User caches" "$S"
confirm "$S" && empty_dir "$LIB/Caches" && echo "    cleaned"

S=$(size_kb "$LIB/Logs");    item "User logs & crash reports" "$S"
confirm "$S" && empty_dir "$LIB/Logs" && echo "    cleaned"

SNAPS=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c 'com.apple.TimeMachine' || true)
printf "%s%-40s%s %10s   %s\n" "$B" "Time Machine local snapshots" "$R" "${SNAPS:-0} found" "external backups unaffected"
if confirm "${SNAPS:-0}"; then
  for date in $(tmutil listlocalsnapshots / | sed -n 's/.*TimeMachine\.\([0-9-]*\)\..*/\1/p'); do
    sudo tmutil deletelocalsnapshots "$date" >/dev/null && echo "    deleted snapshot $date"
  done
fi

XC="$LIB/Developer/Xcode"
S=$(size_kb "$XC/DerivedData");  item "Xcode DerivedData" "$S"
confirm "$S" && empty_dir "$XC/DerivedData" && echo "    cleaned"
S=$(size_kb "$XC/iOS DeviceSupport" "$XC/watchOS DeviceSupport"); item "Xcode device support" "$S"
confirm "$S" && empty_dir "$XC/iOS DeviceSupport" "$XC/watchOS DeviceSupport" && echo "    cleaned"
S=$(size_kb "$LIB/Developer/CoreSimulator"); item "iOS Simulators" "$S" "removes unavailable/unused runtimes"
if confirm "$S" && command -v xcrun >/dev/null; then
  xcrun simctl delete unavailable 2>/dev/null
  xcrun simctl runtime delete --notUsedSinceDays 30 2>/dev/null || true
  echo "    cleaned"
fi

if command -v brew >/dev/null; then
  S=$(size_kb "$(brew --cache 2>/dev/null)"); item "Homebrew cache" "$S"
  confirm "$S" && brew cleanup --prune=all -s >/dev/null 2>&1 && echo "    cleaned"
fi
S=$(size_kb "$HOME/.npm/_cacache" "$LIB/Caches/Yarn" "$HOME/.cache/pip" "$HOME/.gradle/caches")
item "npm / yarn / pip / gradle caches" "$S"
if confirm "$S"; then
  command -v npm  >/dev/null && npm cache clean --force >/dev/null 2>&1
  command -v yarn >/dev/null && yarn cache clean >/dev/null 2>&1
  command -v pip3 >/dev/null && pip3 cache purge >/dev/null 2>&1
  rm -rf "$HOME/.gradle/caches" 2>/dev/null
  echo "    cleaned"
fi

echo
echo "${B}=== Container runtimes ===${R}"
DD_KB=$(size_kb "$LIB/Containers/com.docker.docker")
OB_KB=$(size_kb "$LIB/Group Containers/"*.dev.orbstack)
item "Docker Desktop data" "$DD_KB"
item "OrbStack data" "$OB_KB"
if [[ "$DD_KB" -gt 0 && "$OB_KB" -gt 0 ]]; then
  echo "    You have BOTH installed. Uninstalling the one you don't use frees the most."
  echo "    (Docker Desktop: Troubleshoot > Uninstall. OrbStack: its menu > Uninstall.)"
fi
if command -v docker >/dev/null; then
  for ctx in desktop-linux orbstack; do
    docker context inspect "$ctx" >/dev/null 2>&1 || continue
    [[ "$ctx" == "desktop-linux" ]] && S=$DD_KB || S=$OB_KB
    [[ "$MODE" == "clean" && "$S" -gt 0 ]] || continue
    echo "    Prune unused images/containers/build cache in '$ctx' (volumes kept)?"
    if confirm "$S"; then
      if docker --context "$ctx" info >/dev/null 2>&1; then
        docker --context "$ctx" system prune -a -f
      else
        echo "    '$ctx' isn't running — start that app and re-run to prune it."
      fi
    fi
  done
fi

echo
echo "${B}=== Screen recordings / screenshots in progress ===${R}"
SC="$LIB/Group Containers/group.com.apple.screencapture"
S=$(size_kb "$SC"); item "screencapture temp storage" "$S" "unfinished/leftover recordings"
if [[ "$MODE" == "clean" && "$S" -gt 0 ]]; then
  echo "    Largest files:"
  find "$SC" -type f -size +100M -exec du -sk {} + 2>/dev/null | sort -rn | head -10 |
    while IFS=$'\t' read -r kb f; do printf "      %10s  %s\n" "$(human "$kb")" "${f#$SC/}"; done
  while :; do
    case "$(choose)" in
      t|T) for f in "$SC"/*; do [[ -e "$f" ]] && to_trash "$f" >/dev/null; done; echo "    contents moved to Trash"; break ;;
      o|O) open "$SC" ;;
      *) break ;;
    esac
  done
fi

echo
echo "${B}=== App data review (non-Apple folders over ${MIN_MB} MB) ===${R}"
[[ "$MODE" == "clean" ]] && echo "    Trashing a folder resets that app (logins, settings, downloaded content). Quit it first."
TMP=$(mktemp)
for d in "$LIB/Application Support" "$LIB/Containers" "$LIB/Group Containers"; do
  [[ -d "$d" ]] && du -sk "$d"/* 2>/dev/null >> "$TMP"
done
sort -rn "$TMP" -o "$TMP"
while IFS=$'\t' read -r kb path <&3; do
  [[ "$kb" -ge $((MIN_MB * 1024)) ]] || continue
  name=$(basename "$path")
  is_protected "$name" && continue
  item "$name" "$kb" "in $(basename "$(dirname "$path")")"
  [[ "$MODE" == "clean" ]] || continue
  while :; do
    case "$(choose)" in
      t|T) to_trash "$path"; break ;;
      o|O) open "$path" ;;
      *) break ;;
    esac
  done
done 3< "$TMP"
rm -f "$TMP"

echo
echo "${B}=== Report only (your data — manage manually) ===${R}"
item "iPhone/iPad backups" "$(size_kb "$LIB/Application Support/MobileSync/Backup")" "Finder > device > Manage Backups"
item "Messages attachments" "$(size_kb "$LIB/Messages/Attachments")" "Messages > Settings > keep messages"
item "Xcode Archives" "$(size_kb "$LIB/Developer/Xcode/Archives")" "needed for crash symbolication"

FREE_AFTER=$(df -k / | awk 'NR==2{print $4}')
echo
if [[ "$MODE" == "clean" ]]; then
  echo "${B}Freed now: $(human $((FREE_AFTER - FREE_BEFORE)))${R}"
  [[ "$TRASHED_KB" -gt 0 ]] && echo "${B}In Trash: $(human "$TRASHED_KB")${R} — check it, then empty Trash to reclaim."
  echo "Storage settings can lag; a restart helps it refresh."
else
  echo "Scan only; nothing deleted. Run with --clean to clean interactively."
fi
