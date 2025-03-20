# 🎥 EFC Live Wallpaper Script (Linux)

A lightweight and flexible script to set animated video wallpapers on Linux desktops.

## 🚀 Features
- Supports individual videos or directories with multiple files.
- Auto-detects desktop environment and optimizes accordingly.
- Uses `xwinwrap` and `mpv` for smooth playback.
- Smart CPU-saving by pausing when a window is focused.
- Automatic startup integration.

## 📦 Installation
Ensure you have the required dependencies:
```bash
sudo apt-get install -y xdotool mpv x11-utils
```
If `xwinwrap` is missing, the script will install it automatically.

## 📜 Usage
```bash
./livewall.sh [options] [video_or_directory]
```
### Options:
- `-i <seconds>` → Set CPU-saving focus check interval.
- `-h` or `--help` → Show help message.

### Examples:
```bash
./livewall.sh /path/to/video.mp4
./livewall.sh /path/to/folder/
./livewall.sh -i 2
```

## 🔄 Auto-start
The script automatically adds itself to startup on first run.

## ❌ Uninstall
To remove auto-start:
```bash
rm ~/.config/autostart/livewall.desktop
```

## 📄 License
Licensed under [MIT License](LICENSE)

Developed by **Seuriin (SSL-ACTX)**
