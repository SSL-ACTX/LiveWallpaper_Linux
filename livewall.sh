# ============================================
# EFC Live Wallpaper Script (Flexible asf)
# Author: Seuriin (SSL-ACTX)
# ============================================

CONFIG_FILE="$HOME/.config/livewall.conf"
AUTOSTART_FILE="$HOME/.config/autostart/livewall.desktop"
SCRIPT_PATH="$(readlink -f "$0")"

# Default values
CHECK_INTERVAL=1
MPV_HWDEC="--hwdec=auto"
NICE_LEVEL=10

# Load config (if it exists)
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# -----------------------------
# Parse Arguments
# -----------------------------
function show_help() {
cat << EOF
🎥 EFC Live Wallpaper Script for Linux
          (SSL-ACTX - Seuriin)

Usage: $0 [options] [path_to_video_or_directory]

Options:
  -i <seconds>     Set focus check interval and save to config
  -h, --help       Show this help message
  path             Set video or folder and save it to config

Examples:
  $0 /path/to/video.mp4
  $0 /path/to/folder/
  $0 -i 2
EOF
exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -i)
            shift
            [[ "$1" =~ ^[0-9]+$ ]] || { echo "❌ Invalid interval."; exit 1; }
            CHECK_INTERVAL="$1"
            ;;
        *)
            if [[ -f "$1" || -d "$1" ]]; then
                VIDEO_PATH="$1"
            else
                echo "❌ Invalid file or directory: $1"
                exit 1
            fi
            ;;
    esac
    shift
done

# -----------------------------
# Save config (without duplicates)
# -----------------------------
mkdir -p "$(dirname "$CONFIG_FILE")"
{
    [[ -n "$VIDEO_PATH" ]] && echo "VIDEO_PATH=\"$VIDEO_PATH\""
    [[ -n "$CHECK_INTERVAL" ]] && echo "CHECK_INTERVAL=\"$CHECK_INTERVAL\""
} > "$CONFIG_FILE"

# -----------------------------
# Validate video path
# -----------------------------
if [[ -z "$VIDEO_PATH" ]]; then
    echo "⚠ No video path provided or saved in config!"
    echo "👉 Run: $0 /path/to/video or folder"
    exit 1
fi

# -----------------------------
# Detect Desktop Environment
# -----------------------------
DE=$(echo "${XDG_CURRENT_DESKTOP:-unknown}" | tr '[:upper:]' '[:lower:]')
WM=$(echo "${DESKTOP_SESSION:-unknown}" | tr '[:upper:]' '[:lower:]')
echo "🖥 Desktop Environment: $DE"
echo "🪟 Window Manager Session: $WM"

if [[ "$DE" == *gnome* ]]; then
    echo "⏳ Extra delay for GNOME..."
    sleep 6
fi

# -----------------------------
# Wait for desktop to settle
# -----------------------------
echo "⏳ Waiting for desktop session..."
while ! xprop -root _NET_DESKTOP_NAMES >/dev/null 2>&1; do sleep 1; done
sleep 2

# -----------------------------
# Check & install xwinwrap
# -----------------------------
if ! command -v xwinwrap >/dev/null 2>&1; then
    echo "⚙ xwinwrap not found — installing..."
    sudo apt-get update
    sudo apt-get install -y xorg-dev build-essential libx11-dev x11proto-xext-dev libxrender-dev libxext-dev git
    git clone https://github.com/takase1121/xwinwrap "$HOME/xwinwrap-src"
    cd "$HOME/xwinwrap-src" || exit 1
    make && sudo make install && make clean
    echo "✅ xwinwrap installed."
else
    echo "✔ xwinwrap already installed."
fi

# -----------------------------
# Check mpv HW decode support
# -----------------------------
echo "🔍 Checking mpv hardware decode support..."
if ! mpv --hwdec=auto --no-config --vo=null --ao=null --frames=1 2>&1 | grep -qi "using hardware decoding"; then
    echo "⚠ No hardware decode — fallback to software"
    MPV_HWDEC="--hwdec=no"
else
    echo "✅ Hardware decoding supported"
fi

MPV_OPTIONS="$MPV_HWDEC --panscan=1.0 --no-audio --no-osc --no-osd-bar --no-input-default-bindings --loop"

# -----------------------------
# Get resolution
# -----------------------------
read SCREEN_WIDTH SCREEN_HEIGHT < <(xdpyinfo | awk '/dimensions:/ {split($2,a,"x"); print a[1], a[2]}')
RESOLUTION="${SCREEN_WIDTH}x${SCREEN_HEIGHT}+0+0"

# -----------------------------
# Kill old instances
# -----------------------------
echo "🛑 Killing previous wallpaper instances..."
pkill -9 xwinwrap
pkill -9 mpv
sleep 1

# -----------------------------
# File/folder handling
# -----------------------------
if [[ -d "$VIDEO_PATH" ]]; then
    VIDEO_LIST=("$VIDEO_PATH"/*.mp4 "$VIDEO_PATH"/*.mkv "$VIDEO_PATH"/*.webm)
    if [[ ${#VIDEO_LIST[@]} -eq 0 ]]; then
        echo "❌ No videos found in: $VIDEO_PATH"
        exit 1
    fi
    SELECTED_VIDEO="${VIDEO_LIST[RANDOM % ${#VIDEO_LIST[@]}]}"
    echo "🎞 Shuffled: $SELECTED_VIDEO"
else
    if [[ ! -f "$VIDEO_PATH" ]]; then
        echo "❌ Video not found: $VIDEO_PATH"
        exit 1
    fi
    SELECTED_VIDEO="$VIDEO_PATH"
    echo "🎬 Playing: $SELECTED_VIDEO"
fi

# -----------------------------
# Launch video wallpaper
# -----------------------------
nice -n "$NICE_LEVEL" xwinwrap -ov -g "$RESOLUTION" -- mpv -wid %WID $MPV_OPTIONS "$SELECTED_VIDEO" &
sleep 1
MPV_PID=$(pgrep -n mpv)
[[ -z "$MPV_PID" ]] && echo "❌ mpv failed to start." && exit 1

# -----------------------------
# CPU-saving focus monitor
# -----------------------------
(
    echo "📡 Monitoring focus to save CPU..."
    IS_PAUSED=0
    while sleep "$CHECK_INTERVAL"; do
        ! kill -0 "$MPV_PID" 2>/dev/null && echo "🛑 mpv exited." && exit 0
        ! pgrep -x xwinwrap >/dev/null && echo "🛑 xwinwrap exited." && exit 0

        ACTIVE_WIN=$(xdotool getactivewindow getwindowname 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [[ -z "$ACTIVE_WIN" || "$ACTIVE_WIN" == *"desktop"* ]]; then
            if (( IS_PAUSED )); then
                kill -CONT "$MPV_PID" 2>/dev/null
                IS_PAUSED=0
                echo "▶ Resumed"
            fi
        else
            if (( ! IS_PAUSED )); then
                kill -STOP "$MPV_PID" 2>/dev/null
                IS_PAUSED=1
                echo "⏸ Paused"
            fi
        fi
    done
) & disown

# -----------------------------
# Autostart setup
# -----------------------------
if [[ ! -f "$AUTOSTART_FILE" ]]; then
    echo "⚙ Adding to autostart..."
    mkdir -p "$(dirname "$AUTOSTART_FILE")"
    cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Exec=$SCRIPT_PATH
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Live Wallpaper
Comment=EFC Live Wallpaper Script for Linux by Seuriin
X-KDE-autostart-after=panel
X-XFCE-Autostart-Phase=Application
EOF
    echo "✅ Autostart entry created"
else
    echo "✔ Autostart already exists"
fi
