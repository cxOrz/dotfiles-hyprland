#!/bin/bash
# Resolve icon names to file paths for all .desktop applications
# Output format: icon_name<TAB>file_path (one per line)
# Prefers PNG over SVG, larger sizes over smaller

ICON_DIRS=(
    "$HOME/.local/share/icons"
    "/usr/share/icons/hicolor"
    "/usr/share/icons/Adwaita"
    "/usr/share/icons/AdwaitaLegacy"
    "/usr/share/pixmaps"
)

# Build a lookup: icon_name -> best file path
# Strategy: find ALL matching files, then pick the best one (prefer PNG, larger size)
declare -A best_icon
declare -A best_score

score_path() {
    local path="$1"
    local score=0

    # Prefer PNG over SVG over XPM
    case "$path" in
        *.png|*.PNG) score=$((score + 1000)) ;;
        *.svg|*.SVG) score=$((score + 500)) ;;
        *.xpm)       score=$((score + 100)) ;;
    esac

    # Extract size from path (e.g., 256x256 -> 256)
    local size
    size=$(echo "$path" | grep -oP '\d+x\d+' | head -1 | cut -dx -f1)
    if [[ -n "$size" ]]; then
        score=$((score + size))
    fi

    # Prefer hicolor and local icons over Adwaita
    case "$path" in
        */hicolor/*)       score=$((score + 50)) ;;
        */.local/*)        score=$((score + 60)) ;;
        */AdwaitaLegacy/*) score=$((score + 10)) ;;
        */Adwaita/*)       score=$((score + 20)) ;;
    esac

    echo "$score"
}

resolve_icon() {
    local name="$1"

    # Already an absolute path
    if [[ "$name" == /* ]]; then
        if [[ -f "$name" ]]; then
            echo -e "${name}\t${name}"
        fi
        return
    fi

    best_icon=()
    best_score=()

    # Search all icon dirs using find for robustness
    for dir in "${ICON_DIRS[@]}"; do
        [ -d "$dir" ] || continue
        while IFS= read -r path; do
            local s
            s=$(score_path "$path")
            if [[ -z "${best_score[$name]}" ]] || (( s > best_score[$name] )); then
                best_icon[$name]="$path"
                best_score[$name]="$s"
            fi
        done < <(find "$dir" \( -type f -o -type l \) \( -name "$name.png" -o -name "$name.PNG" -o -name "$name.svg" -o -name "$name.SVG" -o -name "$name.xpm" \) 2>/dev/null)
    done

    if [[ -n "${best_icon[$name]}" ]]; then
        echo -e "${name}\t${best_icon[$name]}"
    fi
}

# Collect all unique icon names from .desktop files
declare -A icons_seen
for desktop_dir in /usr/share/applications "$HOME/.local/share/applications"; do
    [ -d "$desktop_dir" ] || continue
    for f in "$desktop_dir"/*.desktop; do
        [ -f "$f" ] || continue
        icon=$(grep -m1 "^Icon=" "$f" 2>/dev/null | cut -d= -f2)
        [ -z "$icon" ] && continue
        [ "${icons_seen[$icon]+_}" ] && continue
        icons_seen[$icon]=1
        resolve_icon "$icon"
    done
done
