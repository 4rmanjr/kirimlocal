# KirimLocal CLI - Desktop Shortcut Feature

## Overview
KirimLocal CLI now includes enhanced installation capabilities with the ability to create desktop shortcuts for easier access. This improvement adds a new menu option and functionality to create desktop entries that integrate with your desktop environment.

## New Features

### 1. Enhanced Install Global Function
- The `install_global` function now creates both CLI access and desktop shortcuts
- Automatically detects the best terminal emulator available on the system
- Creates a proper desktop entry file following freedesktop.org standards

### 2. Dedicated Desktop Shortcut Creation
- Added a new menu option 'd' for creating desktop shortcuts independently
- Option appears in the main interactive menu as "Create Desktop Shortcut"
- Works even if global installation hasn't been performed

### 3. Desktop Entry Specifications
The created desktop file includes:
- Proper application metadata (name, comment, icon)
- Dynamic terminal detection (supports gnome-terminal, konsole, xterm, etc.)
- Additional actions for sending and receiving files directly
- Compatibility with GNOME, KDE, and other desktop environments
- Security considerations for trusted execution

## Technical Implementation

### Terminal Detection
The system intelligently detects available terminal emulators in this order:
1. gnome-terminal
2. konsole
3. xterm
4. urxvt
5. xfce4-terminal
6. mate-terminal
7. lxterminal

### Desktop Entry Features
- Main action opens the full LocalSend CLI interface
- Secondary actions for quick send/receive operations
- Proper category classification (Network;Utility;)
- MIME type associations for file operations

### Security Considerations
- Sets proper trust flags on GNOME and KDE systems
- Includes instructions for manual trust activation if needed
- Uses proper quoting and escaping for command execution

## Usage

### From Interactive Menu
1. Run `localsend` or `bash localsend.sh`
2. Select option 'i' to install globally (includes desktop shortcut)
3. OR select option 'd' to create desktop shortcut only

### Manual Creation
If you only want the desktop shortcut without global installation:
1. Run the interactive menu
2. Select option 'd' for "Create Desktop Shortcut"

## Compatibility
- Works on Linux systems with XDG-compliant desktop environments
- Supports GNOME, KDE, XFCE, MATE, LXDE, and similar environments
- Requires a compatible terminal emulator to be installed
- Creates shortcuts in the user's Desktop directory or XDG_DESKTOP_DIR

## Distribution Compatibility
The installation system is designed to work across popular Linux distributions:

### Debian/Ubuntu-based Systems
- Uses `/usr/local/bin` or `/usr/bin` with sudo
- Falls back to `~/.local/bin` if needed
- Compatible with APT package management

### Red Hat/Fedora-based Systems
- Works with both traditional and user-local installation methods
- Compatible with DNF/YUM package management
- Follows Fedora packaging guidelines

### Arch Linux-based Systems
- Compatible with Pacman package management
- Works with systemd-based environments
- Follows Arch Linux best practices

### SUSE/openSUSE-based Systems
- Compatible with Zypper package management
- Works with YaST configurations
- Follows SUSE guidelines

### Alpine Linux-based Systems
- Works with APK package management
- Compatible with musl libc systems
- Lightweight installation methods

### Generic POSIX Systems
- Falls back to user-local installation when system-wide access isn't available
- Works with most bash-compatible shells
- Minimal system dependencies

## Notes
- On some systems, you may need to right-click the desktop entry and select "Allow Launching" or "Trust and Launch"
- The desktop shortcut will open LocalSend in a terminal window
- Quick action shortcuts for send/receive are available via right-click context menu on the desktop entry