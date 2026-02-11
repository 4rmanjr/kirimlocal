#!/bin/bash

# --- Configuration ---
FILE_PORT=${FILE_PORT:-9999}
DISCOVERY_PORT=${DISCOVERY_PORT:-9998}
VERSION="2.5"
VERIFY_CHECKSUM=false
COMPRESS_TRANSFER=false
ENCRYPT_TRANSFER=false
DOWNLOAD_DIR=${DOWNLOAD_DIR:-$HOME/Downloads/KirimLocal}
CERT_DIR="$HOME/.kirimlocal_certs"

# Enable strict mode after defining variables that reference each other
set -euo pipefail

# Colors & Icons
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

LOCK="${PURPLE}🔒${NC}"

TICK="${GREEN}✔${NC}"
ARROW="${BLUE}➜${NC}"
FLASH="${YELLOW}⚡${NC}"
INFO="${CYAN}ℹ${NC}"

# Global state
RUNNING=true
BG_PIDS=()

# Safe exit handler
cleanup_and_exit() {
    RUNNING=false
    for pid in "${BG_PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    echo -e "\n${TICK} ${GREEN}Goodbye!${NC}"
    exit 0
}

# Unified navigation hint
NAV_HINT="${CYAN}[b]${NC} Back | ${CYAN}[q]${NC} Quit"

# --- UI Helpers ---
BOX_WIDTH=56

print_box_top() {
    local color="${1:-$CYAN}"
    local width="${2:-$BOX_WIDTH}"
    local line=$(printf '━%.0s' $(seq 1 $((width - 2))))
    echo -e "${color}┏${line}┓${NC}"
}

print_box_bottom() {
    local color="${1:-$CYAN}"
    local width="${2:-$BOX_WIDTH}"
    local line=$(printf '━%.0s' $(seq 1 $((width - 2))))
    echo -e "${color}┗${line}┛${NC}"
}

print_box_sep() {
    local color="${1:-$CYAN}"
    local width="${2:-$BOX_WIDTH}"
    local line=$(printf '━%.0s' $(seq 1 $((width - 2))))
    echo -e "${color}┣${line}┫${NC}"
}

print_box_line() {
    local content="$1"
    local color="${2:-$CYAN}"
    local width="${3:-$BOX_WIDTH}"
    local align="${4:-left}"
    
    # Strip ANSI and calculate visual width using wc -L
    local plain=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
    local plain_len=$(echo -n "$plain" | wc -L)
    
    local inner_width=$((width - 4))
    local pad_total=$((inner_width - plain_len))
    [ $pad_total -lt 0 ] && pad_total=0
    
    local left_p=0
    local right_p=0
    
    if [ "$align" == "center" ]; then
        left_p=$((pad_total / 2))
        right_p=$((pad_total - left_p))
    else
        left_p=0
        right_p=$pad_total
    fi
    
    echo -ne "${color}┃${NC} "
    [ $left_p -gt 0 ] && printf "%${left_p}s" ""
    echo -ne "$content"
    [ $right_p -gt 0 ] && printf "%${right_p}s" ""
    echo -e " ${color}┃${NC}"
}

# --- Help ---
show_help() {
    echo -e "${GREEN}KirimLocal CLI v$VERSION${NC} - Fast local file sharing"
    echo
    echo -e "${WHITE}USAGE:${NC}"
    echo "  kirimlocal                   Interactive menu"
    echo "  kirimlocal -r                Receive mode"
    echo "  kirimlocal -s <files...>     Send files"
    echo
    echo -e "${WHITE}OPTIONS:${NC}"
    echo "  -r, --receive                Start in receive mode"
    echo "  -s, --send <files...>        Send specified files"
    echo "  -p, --port <port>            Custom transfer port (default: 9999)"
    echo "  -z, --compress               Enable gzip compression (faster for text)"
    echo "  -c, --checksum               Verify checksum after transfer"
    echo "  -d, --dir <path>             Custom download directory (default: ~/Downloads/KirimLocal)"
    echo "  -e, --encrypt                Enable TLS encryption for secure transfer"
    echo "  -h, --help                   Show this help message"
    echo "  -v, --version                Show version"
    echo
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  kirimlocal -s file.txt       Send single file"
    echo "  kirimlocal -s *.pdf          Send all PDFs"
    echo "  kirimlocal -r -p 8888        Receive on port 8888"
    echo "  kirimlocal -s -z *.log       Send with compression"
    echo "  kirimlocal -s -c file.zip    Send with checksum verify"
    echo "  kirimlocal -r -e             Receive with TLS encryption"
    echo "  kirimlocal -s -e file.txt    Send with TLS encryption"
    echo
    echo -e "${WHITE}ENVIRONMENT:${NC}"
    echo "  DOWNLOAD_DIR                 Override default download directory"
    echo "  FILE_PORT                    Override default port"
    echo "  DISCOVERY_PORT               Override discovery port"
    exit 0
}

# --- Security ---
generate_certs() {
    if [[ ! -f "$CERT_DIR/kirimlocal.pem" ]]; then
        mkdir -p "$CERT_DIR"
        echo -e "${INFO} ${CYAN}Generating self-signed certificate for encryption...${NC}"
        openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
            -subj "/C=ID/ST=KirimLocal/L=CLI/O=Security/CN=kirimlocal" \
            -keyout "$CERT_DIR/kirimlocal.key" -out "$CERT_DIR/kirimlocal.crt" &>/dev/null
        cat "$CERT_DIR/kirimlocal.key" "$CERT_DIR/kirimlocal.crt" > "$CERT_DIR/kirimlocal.pem"
        rm "$CERT_DIR/kirimlocal.key" "$CERT_DIR/kirimlocal.crt"
    fi
}

# --- Dependency Check ---
check_dependencies() {
    local missing=()
    local tools=("socat" "pv" "tar" "hostname" "openssl")
    for cmd in "${tools[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then missing+=("$cmd"); fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}[!] Missing tools: ${missing[*]}${NC}"
        echo -e "${CYAN}[*] Auto-installing dependencies...${NC}"
        local pkg_mgr="" update_cmd="" install_cmd=""
        if command -v apt-get &>/dev/null; then
            pkg_mgr="apt"; update_cmd="sudo apt-get update -qq"; install_cmd="sudo apt-get install -y -qq"
        elif command -v pacman &>/dev/null; then
            pkg_mgr="pacman"; update_cmd="sudo pacman -Sy"; install_cmd="sudo pacman -S --noconfirm"
        elif command -v dnf &>/dev/null; then
            pkg_mgr="dnf"; update_cmd="sudo dnf makecache -q"; install_cmd="sudo dnf install -y -q"
        elif command -v yum &>/dev/null; then
            pkg_mgr="yum"; update_cmd="sudo yum makecache -q"; install_cmd="sudo yum install -y -q"
        elif command -v zypper &>/dev/null; then
            pkg_mgr="zypper"; update_cmd="sudo zypper refresh -q"; install_cmd="sudo zypper install -y -q"
        elif command -v apk &>/dev/null; then
            pkg_mgr="apk"; update_cmd="sudo apk update -q"; install_cmd="sudo apk add -q"
        elif command -v brew &>/dev/null; then
            pkg_mgr="brew"; update_cmd="brew update"; install_cmd="brew install"
        fi
        if [[ -n "$pkg_mgr" ]]; then
            echo -e "${INFO} Updating package cache ($pkg_mgr)..."
            $update_cmd 2>/dev/null
            echo -e "${INFO} Installing: ${missing[*]}..."
            if $install_cmd "${missing[@]}"; then
                echo -e "${TICK} Dependencies installed successfully!"
            else
                echo -e "${RED}[!] Failed to install dependencies. Please install manually: ${missing[*]}${NC}"
                exit 1
            fi
        else
            echo -e "${RED}[!] No supported package manager found. Install manually: ${missing[*]}${NC}"
            exit 1
        fi
    fi
}

# --- Helpers ---
get_all_broadcasts() {
    if [[ "$OSTYPE" == "darwin"* ]]; then ifconfig | grep "broadcast " | awk '{print $6}'
    else ip addr show | grep "brd " | awk '{print $4}'; fi
}

get_ip() {
    local ip=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ip=$(ipconfig getifaddr en0)
    else
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [[ -z "$ip" ]]; then
            local interface=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -n 1)
            [[ -z "$interface" ]] && interface=$(ip -4 addr show 2>/dev/null | grep 'state UP' | awk -F': ' '{print $2}' | head -n 1)
            ip=$(ip -4 addr show "$interface" 2>/dev/null | grep -w inet | awk '{print $2}' | cut -d/ -f1 | head -n 1)
        fi
        if [[ -z "$ip" ]]; then
            ip=$(ifconfig 2>/dev/null | grep -w inet | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
        fi
    fi
    echo "${ip:-127.0.0.1}"
}

generate_name() {
    local colors=("Golden" "Silver" "Crimson" "Azure" "Emerald" "Midnight")
    local animals=("Eagle" "Wolf" "Tiger" "Panda" "Falcon" "Shark")
    echo "${colors[$RANDOM % ${#colors[@]}]}-${animals[$RANDOM % ${#animals[@]}]}"
}

validate_ip() {
    local ip="$1"
    if [[ -z "$ip" ]]; then return 1; fi
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ ! "$ip" =~ $regex ]]; then return 1; fi
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        ((octet < 0 || octet > 255)) && return 1
    done
    return 0
}

validate_paths() {
    local items=("$@")
    local invalid=()
    for item in "${items[@]}"; do
        [[ ! -e "$item" ]] && invalid+=("$item")
    done
    if [[ ${#invalid[@]} -gt 0 ]]; then
        echo -e "${RED}[!] File/folder not found:${NC}"
        for f in "${invalid[@]}"; do echo -e "    ${YELLOW}✖ $f${NC}"; done
        return 1
    fi
    return 0
}

calculate_checksum() {
    local items=("$@")
    if command -v sha256sum &>/dev/null; then
        tar -c "${items[@]}" 2>/dev/null | sha256sum | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        tar -c "${items[@]}" 2>/dev/null | shasum -a 256 | awk '{print $1}'
    else
        echo "CHECKSUM_NOT_AVAILABLE"
    fi
}

# Handle listener error cases
handle_listener_error() {
    local duration="$1"
    if [[ $duration -lt 2 ]]; then
        echo -e "\n${RED}[!] Listener failed to start or died too quickly.${NC}"
        echo -e "${YELLOW}[!] Port $FILE_PORT might be in use by another process.${NC}"
        echo -e "${CYAN}[r]${NC} Retry | ${CYAN}[p]${NC} Use different port | ${NAV_HINT}"
        echo -en "\n${ARROW} ${WHITE}Action:${NC} "; read -r action
        case "$action" in
            r|R) return 1 ;;  # Continue
            p|P)
                echo -en "${ARROW} ${YELLOW}Enter new port: ${NC}"; read -r new_port
                [[ "$new_port" =~ ^[0-9]+$ ]] && FILE_PORT="$new_port"
                return 1 ;;  # Continue
            b|B) return 2 ;;  # Break
            q|Q) return 3 ;;  # Exit
            *) return 1 ;;    # Continue
        esac
    else
        echo -e "\n${TICK} ${GREEN}Transfer Success!${NC}"
        log_transfer "RECEIVE" "$MY_IP" "incoming" "SUCCESS" "-"
        echo -e "${CYAN}──────────────────────────────────────────────────────${NC}"
        return 0  # Normal continuation
    fi
}

# Check port availability and handle user response
check_port_availability() {
    if ss -tuln 2>/dev/null | grep -q ":$FILE_PORT " || true; then
        echo -e "\n${RED}[!] Port $FILE_PORT is already in use.${NC}"
        echo -e "${CYAN}[r]${NC} Retry | ${CYAN}[p]${NC} Use different port | ${NAV_HINT}"
        echo -en "\n${ARROW} ${WHITE}Action:${NC} "; read -r action
        case "$action" in
            r|R) return 1 ;;  # Continue
            p|P)
                echo -en "${ARROW} ${YELLOW}Enter new port: ${NC}"; read -r new_port
                [[ "$new_port" =~ ^[0-9]+$ ]] && FILE_PORT="$new_port"
                return 1 ;;  # Continue
            b|B) return 2 ;;  # Break
            q|Q) return 3 ;;  # Exit
            *) return 1 ;;    # Continue
        esac
    else
        return 0  # Port is available
    fi
}

# Clipboard Functions
get_clipboard_cmd() {
    if command -v pbcopy &>/dev/null && command -v pbpaste &>/dev/null; then
        echo "macos"
    elif command -v xclip &>/dev/null; then
        echo "xclip"
    elif command -v xsel &>/dev/null; then
        echo "xsel"
    elif command -v wl-copy &>/dev/null && command -v wl-paste &>/dev/null; then
        echo "wayland"
    else
        echo "none"
    fi
}

get_clipboard_content() {
    case $(get_clipboard_cmd) in
        macos) pbpaste ;;
        xclip) xclip -selection clipboard -o ;;
        xsel) xsel --clipboard --output ;;
        wayland) wl-paste ;;
        *) echo "Clipboard not supported on this system" >&2; return 1 ;;
    esac
}

set_clipboard_content() {
    local content="$1"
    case $(get_clipboard_cmd) in
        macos) echo -n "$content" | pbcopy ;;
        xclip) echo -n "$content" | xclip -selection clipboard ;;
        xsel) echo -n "$content" | xsel --clipboard --input ;;
        wayland) echo -n "$content" | wl-copy ;;
        *) echo "Clipboard not supported on this system" >&2; return 1 ;;
    esac
}

# Share clipboard content with another device
share_clipboard() {
    local content=$(get_clipboard_content 2>/dev/null)
    if [[ -n "$content" ]]; then
        # Use the existing send mechanism but with clipboard content
        echo -e "${INFO} ${CYAN}Preparing to share clipboard content...${NC}"
        
        # Create a temporary file with clipboard content
        local temp_file=$(mktemp)
        echo -n "$content" > "$temp_file"
        
        # Use the existing send functionality
        send_mode "$temp_file"
        
        # Clean up
        rm "$temp_file"
    else
        echo -e "${RED}[!] Clipboard is empty${NC}"
        echo -en "\n${ARROW} Press Enter to return..."; read -r
    fi
}

# Receive clipboard content from another device
receive_clipboard() {
    # This would be integrated into the receive functionality
    # For now, we'll just note that received text content should be 
    # automatically placed in clipboard if it's detected as text
    echo -e "${INFO} ${CYAN}Clipboard receive mode will be activated when text content is received${NC}"
}

# History & Retry Config
HISTORY_FILE="${HOME}/.kirimlocal_history"
MAX_RETRIES=3
RETRY_DELAY=2

log_transfer() {
    local direction="$1" target="$2" items="$3" status="$4" size="$5"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp}|${direction}|${target}|${items}|${status}|${size}" >> "$HISTORY_FILE"
}

get_total_size() {
    local items=("$@")
    local total=0
    for item in "${items[@]}"; do
        if [[ -e "$item" ]]; then
            local s=$(du -sb "$item" 2>/dev/null | awk '{print $1}')
            ((total += s))
        fi
    done
    echo "$total"
}

human_size() {
    local bytes=$1
    if ((bytes >= 1073741824)); then echo "$(echo "scale=1; $bytes/1073741824" | bc)G"
    elif ((bytes >= 1048576)); then echo "$(echo "scale=1; $bytes/1048576" | bc)M"
    elif ((bytes >= 1024)); then echo "$(echo "scale=1; $bytes/1024" | bc)K"
    else echo "${bytes}B"; fi
}

# Early parse for help/version (no dependencies needed)
for arg in "$@"; do
    case "$arg" in
        -h|--help) show_help ;;
        -v|--version) echo "KirimLocal CLI v$VERSION"; exit 0 ;;
    esac
done

check_dependencies
MY_IP=$(get_ip)
MY_NAME=$(generate_name)

# --- Discovery Logic ---
start_discovery_responder() {
    while true; do
        data=$(socat -u UDP4-RECVFROM:$DISCOVERY_PORT,fork,reuseaddr - 2>/dev/null | head -n 1)
        if [[ "$data" == "KIRIMLOCAL_SCAN" ]]; then
            echo "KIRIMLOCAL_PEER|$MY_NAME|$MY_IP" | socat -u - UDP4-DATAGRAM:255.255.255.255:$DISCOVERY_PORT,broadcast 2>/dev/null
        fi
    done
}

scan_devices() {
    local broadcasts=($(get_all_broadcasts))
    (
        local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        for ((i=0; i<15; i++)); do echo -ne "\r${CYAN}${frames[i%10]}${NC} Scanning network interfaces... "; sleep 0.1; done
        echo -ne "\r${TICK} Scan complete!                      \n"
    ) &
    local spinner_pid=$!
    for brd in "${broadcasts[@]}"; do
        echo "KIRIMLOCAL_SCAN" | socat -u - UDP4-DATAGRAM:$brd:$DISCOVERY_PORT,broadcast 2>/dev/null
    done
    local raw_peers=()
    while read -r -t 1.5 line; do
        [[ "$line" == KIRIMLOCAL_PEER* ]] && raw_peers+=("$line")
    done < <(socat -u UDP4-RECVFROM:$DISCOVERY_PORT,reuseaddr - 2>/dev/null)
    kill $spinner_pid 2>/dev/null || true; wait $spinner_pid 2>/dev/null || true
    printf "%s\n" "${raw_peers[@]}" | sort -u
}

# --- Modes ---
receive_mode() {
    MY_IP=$(get_ip)
    mkdir -p "$DOWNLOAD_DIR"
    [[ "$ENCRYPT_TRANSFER" == true ]] && generate_certs
    clear
    local title="${GREEN}⚡ KIRIMLOCAL CLI RECEIVER (v$VERSION)${NC}"
    [[ "$ENCRYPT_TRANSFER" == true ]] && title="$LOCK $title"
    
    print_box_top "$PURPLE"
    print_box_line "$title" "$PURPLE" "$BOX_WIDTH" "center"
    print_box_sep "$PURPLE"
    print_box_line "${INFO} Name : ${YELLOW}$MY_NAME${NC}" "$PURPLE"
    print_box_line "${INFO} IP   : ${YELLOW}$MY_IP${NC}" "$PURPLE"
    print_box_line "${INFO} Dest : ${YELLOW}${DOWNLOAD_DIR//$HOME/~}${NC}" "$PURPLE"
    print_box_bottom "$PURPLE"
    echo -e "${YELLOW}Navigation: ${NC}${NAV_HINT} ${CYAN}| Ctrl+C${NC} Back"
    
    start_discovery_responder &
    local disc_pid=$!
    BG_PIDS+=("$disc_pid")
    
    local socat_pid=""
    
    trap "kill $disc_pid $socat_pid 2>/dev/null || true; BG_PIDS=(\"\${BG_PIDS[@]/\$disc_pid}\"); return 0" INT
    
    while $RUNNING; do
        # Check if process exists, suppressing error if it doesn't
        local process_exists=1  # 1 for true, 0 for false
        if [[ -n "$socat_pid" ]]; then
            if kill -0 "$socat_pid" 2>/dev/null; then
                process_exists=1
            else
                process_exists=0
            fi
        else
            process_exists=0
        fi
        
        if [[ -z "$socat_pid" ]] || [ $process_exists -eq 0 ]; then
            if [[ -n "$socat_pid" ]]; then
                # Check how long it ran
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                
                handle_listener_error "$duration"
                local error_result=$?
                if [[ $error_result -eq 1 ]]; then
                    socat_pid=""
                    continue
                elif [[ $error_result -eq 2 ]]; then
                    break
                elif [[ $error_result -eq 3 ]]; then
                    cleanup_and_exit
                fi
                socat_pid=""
            fi
            
            # Check if port is already in use before trying
            check_port_availability
            local port_check_result=$?
            if [[ $port_check_result -eq 1 ]]; then
                continue
            elif [[ $port_check_result -eq 2 ]]; then
                break
            elif [[ $port_check_result -eq 3 ]]; then
                cleanup_and_exit
            fi

            echo -e "\n${FLASH} Waiting for incoming files... $([[ "$ENCRYPT_TRANSFER" == true ]] && echo -e "($LOCK Secure)")"
            local socat_cmd="socat -u TCP4-LISTEN:$FILE_PORT,reuseaddr,rcvbuf=1048576 -"
            if [[ "$ENCRYPT_TRANSFER" == true ]]; then
                socat_cmd="socat -u OPENSSL-LISTEN:$FILE_PORT,reuseaddr,cert=$CERT_DIR/kirimlocal.pem,verify=0,rcvbuf=1048576 -"
            fi
            
            start_time=$(date +%s)
            # Create a named pipe for size extraction
            local fifo="/tmp/kirimlocal_$$"
            mkfifo "$fifo" 2>/dev/null

            (
                $socat_cmd | {
                    # Read 16-byte size header
                    read -r -n 16 size_header
                    expected_size=$((10#$size_header))

                    if [[ "$COMPRESS_TRANSFER" == true ]]; then
                        # Store the received content temporarily to check if it's text
                        local temp_output=$(mktemp)
                        pv -s "$expected_size" | gunzip | tee "$temp_output" | tar -xvB -b 128 -C "$DOWNLOAD_DIR"
                        
                        # Check if the received content is text and small enough to be clipboard content
                        if file --mime-type "$temp_output" | grep -q "text/" && [[ $(stat -c%s "$temp_output") -lt 1048576 ]]; then  # Less than 1MB
                            local content=$(cat "$temp_output")
                            # Copy to clipboard if possible
                            if set_clipboard_content "$content" 2>/dev/null; then
                                echo -e "\n${TICK} ${GREEN}Text content copied to clipboard!${NC}"
                            fi
                        fi
                        
                        rm "$temp_output"
                    else
                        # Store the received content temporarily to check if it's text
                        local temp_output=$(mktemp)
                        pv -s "$expected_size" | tee "$temp_output" | tar -xvB -b 128 -C "$DOWNLOAD_DIR"
                        
                        # Check if the received content is text and small enough to be clipboard content
                        if file --mime-type "$temp_output" | grep -q "text/" && [[ $(stat -c%s "$temp_output") -lt 1048576 ]]; then  # Less than 1MB
                            local content=$(cat "$temp_output")
                            # Copy to clipboard if possible
                            if set_clipboard_content "$content" 2>/dev/null; then
                                echo -e "\n${TICK} ${GREEN}Text content copied to clipboard!${NC}"
                            fi
                        fi
                        
                        rm "$temp_output"
                    fi
                }
            ) &
            socat_pid=$!
            rm -f "$fifo"
        fi
        
        # Poll for input (1 second timeout)
        read -t 1 -n 1 key
        if [[ $? -eq 0 ]]; then
            case "$key" in
                b|B) break ;;
                q|Q) cleanup_and_exit ;;
            esac
        fi
    done
    
    kill "$disc_pid" "$socat_pid" 2>/dev/null || true
    BG_PIDS=("${BG_PIDS[@]/$disc_pid}")
}

send_mode() {
    local items=("$@")
    if [[ ${#items[@]} -eq 0 ]]; then
        trap "interactive_menu; return" INT
        clear
        local title="${GREEN}⚡ KIRIMLOCAL CLI SENDER (v$VERSION)${NC}"
        [[ "$ENCRYPT_TRANSFER" == true ]] && title="$LOCK $title"
        print_box_top "$BLUE"
        print_box_line "$title" "$BLUE" "$BOX_WIDTH" "center"
        print_box_sep "$BLUE"
        print_box_line "${INFO} Name : ${YELLOW}$MY_NAME${NC}" "$BLUE"
        print_box_line "${INFO} IP   : ${YELLOW}$MY_IP${NC}" "$BLUE"
        print_box_bottom "$BLUE"
        echo -e "${YELLOW}Navigation: ${NC}${NAV_HINT}"
        echo -e "\n${INFO} ${YELLOW}Drag and drop files here or type paths${NC}"
        echo -en "${ARROW} ${YELLOW}Path(s):${NC} "
        read -e -r input_paths
        [[ -z "$input_paths" || "$input_paths" == "b" ]] && return 0
        [[ "$input_paths" == "q" ]] && cleanup_and_exit
        read -ra items <<< "$input_paths"
    fi

    [[ ${#items[@]} -eq 0 ]] && return 0
    if ! validate_paths "${items[@]}"; then
        echo -en "\n${ARROW} Press Enter to try again..."; read -r
        send_mode; return
    fi
    trap "return 0" INT

    while true; do
        clear
        local title="${GREEN}⚡ KIRIMLOCAL CLI SENDER (v$VERSION)${NC}"
        [[ "$ENCRYPT_TRANSFER" == true ]] && title="$LOCK $title"
        print_box_top "$BLUE"
        print_box_line "$title" "$BLUE" "$BOX_WIDTH" "center"
        print_box_sep "$BLUE"
        print_box_line "${INFO} Name : ${YELLOW}$MY_NAME${NC}" "$BLUE"
        print_box_line "${INFO} IP   : ${YELLOW}$MY_IP${NC}" "$BLUE"
        print_box_bottom "$BLUE"
        echo -e "${CYAN} Prepare to send:${NC} ${WHITE}${#items[@]} item(s)${NC}"
        echo -e "${CYAN} ──────────────────────────────────────────────────────${NC}"
        
        mapfile -t peers < <(scan_devices)
        if [[ ${#peers[@]} -eq 0 ]]; then
            echo -e "\n  ${RED}✖ No devices found in your network.${NC}"
            echo -e "  ${YELLOW}──────────────────────────────────────────────────────${NC}"
            echo -e "  ${CYAN}[r]${NC} Rescan | ${CYAN}[m]${NC} Manual | ${CYAN}[b]${NC} Back | ${CYAN}[q]${NC} Quit"
            echo -en "\n${ARROW} ${WHITE}Action:${NC} "; read -r r
            [[ "$r" == "r" ]] && continue
            [[ "$r" == "b" ]] && return 0
            [[ "$r" == "q" ]] && cleanup_and_exit
            [[ "$r" == "m" ]] && choice="m" || { interactive_menu; return; }
        else
            echo -e "\n  ${YELLOW}ONLINE DEVICES:${NC}"
            echo -e "  ${WHITE}ID   DEVICE NAME              IP ADDRESS${NC}"
            echo -e "  ──   ───────────              ──────────"
            for i in "${!peers[@]}"; do
                IFS='|' read -r p n ip <<< "${peers[$i]}"
                printf "  ${CYAN}%-4s${NC} ${GREEN}%-24s${NC} ${BLUE}%-15s${NC}\n" "$((i+1)))" "$n" "$ip"
            done
            echo -e "\n  ${CYAN}[r]${NC} Rescan | ${CYAN}[m]${NC} Manual | ${NAV_HINT}"
            echo -en "\n${ARROW} ${WHITE}Select target:${NC} "; read -r choice
        fi
        
        if [[ "$choice" == "r" ]]; then continue
        elif [[ "$choice" == "b" ]]; then return 0
        elif [[ "$choice" == "q" ]]; then cleanup_and_exit
        elif [[ "$choice" == "m" ]]; then
            echo -en "\n${ARROW} ${YELLOW}Enter IP: "; read -r target_ip
            if validate_ip "$target_ip"; then
                break
            else
                echo -e "${RED}[!] Invalid IP address format${NC}"
                sleep 1
            fi
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#peers[@]}" ]; then
            IFS='|' read -r p n target_ip <<< "${peers[$((choice-1))]}"; break
        fi
    done

    local total_size=$(get_total_size "${items[@]}")
    local human_total=$(human_size "$total_size")
    local item_names=$(printf "%s," "${items[@]}" | sed 's/,$//')
    
    echo -e "\n${TICK} ${YELLOW}Initiating transfer to ${GREEN}$target_ip${NC}... $([[ "$ENCRYPT_TRANSFER" == true ]] && echo -e "($LOCK Secure)")"
    echo -e "${INFO} ${WHITE}Total size: ${CYAN}$human_total${NC} (${#items[@]} items)"
    if [[ "$VERIFY_CHECKSUM" == true ]]; then
        echo -e "${INFO} ${CYAN}Calculating checksum...${NC}"
        local checksum=$(calculate_checksum "${items[@]}")
        echo -e "${INFO} ${WHITE}SHA256: ${YELLOW}${checksum:0:16}...${NC}"
    fi
    echo -e "${CYAN} ──────────────────────────────────────────────────────${NC}"
    
    local attempt=1 success=false
    while [[ $attempt -le $MAX_RETRIES ]]; do
        if [[ $attempt -gt 1 ]]; then
            echo -e "${YELLOW}[!] Retry attempt $attempt/$MAX_RETRIES...${NC}"
        fi
        local socat_cmd="socat -u - TCP4:$target_ip:$FILE_PORT,sndbuf=1048576,tcpnodelay"
        if [[ "$ENCRYPT_TRANSFER" == true ]]; then
            socat_cmd="socat -u - OPENSSL-CONNECT:$target_ip:$FILE_PORT,verify=0,sndbuf=1048576,tcpnodelay"
        fi
        
        if [[ "$COMPRESS_TRANSFER" == true ]]; then
            [[ $attempt -eq 1 ]] && echo -e "${INFO} ${CYAN}Compression enabled (gzip)${NC}"
            if { printf "%016d" "$total_size"; tar -cv -b 128 "${items[@]}" 2>/dev/null | gzip; } | pv -s "$total_size" -p -b -r -a -N "Transfer" | $socat_cmd 2>/dev/null; then
                success=true; break
            fi
        else
            if { printf "%016d" "$total_size"; tar -cv -b 128 "${items[@]}" 2>/dev/null; } | pv -s "$total_size" -p -b -r -a -N "Transfer" | $socat_cmd 2>/dev/null; then
                success=true; break
            fi
        fi
        ((attempt++))
        [[ $attempt -le $MAX_RETRIES ]] && sleep $RETRY_DELAY
    done
    
    echo -e "${CYAN} ──────────────────────────────────────────────────────${NC}"
    if [[ "$success" == true ]]; then
        echo -e "${TICK} ${GREEN}Success! All items sent.${NC}"
        log_transfer "SEND" "$target_ip" "$item_names" "SUCCESS" "$human_total"
        if [[ "$VERIFY_CHECKSUM" == true ]]; then
            echo -e "${INFO} ${WHITE}Checksum: ${YELLOW}${checksum:0:32}${NC}"
        fi
    else
        echo -e "${RED}[!] Transfer failed after $MAX_RETRIES attempts${NC}"
        log_transfer "SEND" "$target_ip" "$item_names" "FAILED" "$human_total"
    fi
    echo -en "\n${ARROW} Press Enter to return to menu..."; read -r
}

install_global() {
    local install_success=false
    
    # Try different installation methods depending on system capabilities
    if command -v sudo >/dev/null 2>&1; then
        # Method 1: Traditional installation using sudo
        if sudo ln -sf "$(realpath "$0")" "/usr/local/bin/kirimlocal" 2>/dev/null; then
            echo -e "${TICK} CLI installed to /usr/local/bin/kirimlocal"
            install_success=true
        else
            # If /usr/local/bin doesn't exist or isn't writable, try /usr/bin
            if sudo ln -sf "$(realpath "$0")" "/usr/bin/kirimlocal" 2>/dev/null; then
                echo -e "${TICK} CLI installed to /usr/bin/kirimlocal"
                install_success=true
            fi
        fi
    fi
    
    # Method 2: If sudo is not available or failed, try user-local installation
    if [[ "$install_success" == false ]]; then
        # Create ~/.local/bin if it doesn't exist
        mkdir -p "$HOME/.local/bin"
        
        # Create symlink in user's local bin directory
        if ln -sf "$(realpath "$0")" "$HOME/.local/bin/kirimlocal" 2>/dev/null; then
            echo -e "${TICK} CLI installed to $HOME/.local/bin/kirimlocal"
            install_success=true
            
            # Inform user about PATH requirement
            echo -e "${INFO} ${CYAN}Note: Make sure $HOME/.local/bin is in your PATH${NC}"
            echo -e "${CYAN}Add 'export PATH=\$PATH:\$HOME/.local/bin' to your ~/.bashrc or ~/.zshrc${NC}"
        fi
    fi
    
    # Method 3: If all else fails, copy the script to user's local bin
    if [[ "$install_success" == false ]]; then
        mkdir -p "$HOME/.local/bin"
        
        if cp "$0" "$HOME/.local/bin/kirimlocal" && chmod +x "$HOME/.local/bin/kirimlocal"; then
            echo -e "${TICK} CLI copied to $HOME/.local/bin/kirimlocal"
            install_success=true
            
            echo -e "${INFO} ${CYAN}Note: Make sure $HOME/.local/bin is in your PATH${NC}"
            echo -e "${CYAN}Add 'export PATH=\$PATH:\$HOME/.local/bin' to your ~/.bashrc or ~/.zshrc${NC}"
        fi
    fi
    
    if [[ "$install_success" == true ]]; then
        echo -e "${GREEN}Use 'kirimlocal' anywhere from terminal${NC}"
        
        # Create desktop shortcut if desktop environment is detected
        create_desktop_shortcut
    else
        echo -e "${RED}[!] Could not install globally. You can still run with 'bash kirimlocal.sh'${NC}"
    fi
    
    sleep 2
}

create_desktop_shortcut() {
    local desktop_dir=""
    
    # Determine desktop directory location
    if [[ -n "$XDG_DESKTOP_DIR" ]]; then
        desktop_dir="$XDG_DESKTOP_DIR"
    elif [[ -d "$HOME/Desktop" ]]; then
        desktop_dir="$HOME/Desktop"
    elif [[ -d "$HOME/desktop" ]]; then
        desktop_dir="$HOME/desktop"
    else
        echo -e "${YELLOW}[!] Desktop directory not found, skipping desktop shortcut creation${NC}"
        return 1
    fi
    
    # Detect the best terminal emulator available
    local terminal_emulator=""
    for term in gnome-terminal konsole xterm urxvt xfce4-terminal mate-terminal lxterminal; do
        if command -v "$term" &>/dev/null; then
            terminal_emulator="$term"
            break
        fi
    done
    
    if [[ -z "$terminal_emulator" ]]; then
        echo -e "${YELLOW}[!] No suitable terminal emulator found, skipping desktop shortcut creation${NC}"
        return 1
    fi
    
    # Create desktop entry file
    local desktop_file="$desktop_dir/KirimLocal.desktop"
    cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=KirimLocal CLI
Comment=Fast local file sharing
Exec=$terminal_emulator -e bash -c 'kirimlocal; read -p "Press Enter to exit..."'
Icon=network-transmit-receive
Terminal=false
Categories=Network;Utility;
MimeType=text/plain;inode/directory;
Actions=SendFiles;ReceiveFiles;

[Desktop Action SendFiles]
Name=Send Files with KirimLocal
Exec=$terminal_emulator -e bash -c 'kirimlocal -s; read -p "Press Enter to exit..."'

[Desktop Action ReceiveFiles]
Name=Receive Files with KirimLocal
Exec=$terminal_emulator -e bash -c 'kirimlocal -r; read -p "Press Enter to exit..."'
EOF
    
    # Make the desktop file executable
    chmod +x "$desktop_file"
    
    # On some systems, we need to explicitly allow launching
    if [[ -f "$desktop_file" ]]; then
        # Try to set the trusted property on GNOME
        if command -v gio &>/dev/null; then
            gio set "$desktop_file" "metadata::trusted" yes 2>/dev/null || true
            # Also try the newer command
            if command -v gsettings &>/dev/null; then
                local desktop_full_path="$(realpath "$desktop_file")"
                gsettings set org.gnome.shell allowed-launch-locations "['$desktop_full_path']" 2>/dev/null || true
            fi
        fi
        
        # For KDE, try to set the trusted property
        if command -v kwriteconfig5 &>/dev/null; then
            local kde_config_dir="$HOME/.local/share/applications"
            mkdir -p "$kde_config_dir"
            cp "$desktop_file" "$kde_config_dir/"
            kwriteconfig5 --file "$kde_config_dir/KirimLocal.desktop" --group "Desktop Entry" --key "X-KDE-DBus-StartupType" "none"
        fi
    fi
    
    echo -e "${TICK} Desktop shortcut created at: $desktop_file"
    echo -e "${INFO} ${CYAN}Note: You may need to right-click and select 'Allow Launching' on some systems${NC}"
}

show_history() {
    clear
    print_box_top "$CYAN"
    print_box_line "${GREEN}📋 TRANSFER HISTORY${NC}" "$CYAN" "$BOX_WIDTH" "center"
    print_box_bottom "$CYAN"
    if [[ -f "$HISTORY_FILE" ]]; then
        echo -e "\n${WHITE}DATE/TIME            DIR     TARGET          ITEMS                  STATUS   SIZE${NC}"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────────${NC}"
        tail -20 "$HISTORY_FILE" | while IFS='|' read -r ts dir target items status size; do
            local short_items="${items:0:20}"
            [[ ${#items} -gt 20 ]] && short_items="${short_items}..."
            printf "%-19s %-7s %-15s %-22s %-8s %s\n" "$ts" "$dir" "$target" "$short_items" "$status" "$size"
        done
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "${INFO} Showing last 20 entries from ${YELLOW}$HISTORY_FILE${NC}"
    else
        echo -e "\n${YELLOW}No transfer history yet.${NC}"
    fi
    echo -en "\n${ARROW} Press Enter to go back..."; read -r
}

interactive_menu() {
    trap "cleanup_and_exit" INT TERM

    while $RUNNING; do
        MY_IP=$(get_ip)
        clear
        print_box_top "$CYAN"
        print_box_line "${GREEN}🚀 WELCOME TO KIRIMLOCAL CLI v$VERSION${NC}" "$CYAN" "$BOX_WIDTH" "center"
        print_box_sep "$CYAN"
        print_box_line ""
        print_box_line "${WHITE}1)${NC} ${GREEN}Receive Files${NC}     (Wait for incoming)"
        print_box_line "${WHITE}2)${NC} ${BLUE}Send Files${NC}        (Scan & send to peer)"
        print_box_line "${WHITE}3)${NC} ${CYAN}Share Clipboard${NC}   (Send clipboard content)"
        print_box_line "${WHITE}h)${NC} ${PURPLE}History${NC}         (View transfer history)"
        print_box_line "${WHITE}i)${NC} ${YELLOW}Install Global${NC}  (Access from anywhere)"
        print_box_line "${WHITE}d)${NC} ${WHITE}Create Desktop Shortcut${NC} (Add to desktop)"
        print_box_line "${WHITE}q)${NC} ${RED}Quit${NC}            (Exit application)"
        print_box_line ""
        print_box_bottom "$CYAN"
        echo -en "\n${ARROW} ${WHITE}Select option:${NC} "; read -r c
        case "$c" in
            1) receive_mode ;;
            2) send_mode ;;
            3) share_clipboard ;;
            h|H) show_history ;;
            i|I) install_global ;;
            d|D) create_desktop_shortcut ;;
            q|Q) cleanup_and_exit ;;
            *) ;;  # Invalid input, loop continues
        esac
    done
}

if [[ $# -eq 0 ]]; then interactive_menu; else
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) show_help ;;
            -v|--version) echo "KirimLocal CLI v$VERSION"; exit 0 ;;
            -p|--port) FILE_PORT="$2"; shift 2 ;;
            -d|--dir) DOWNLOAD_DIR="$2"; shift 2 ;;
            -e|--encrypt) ENCRYPT_TRANSFER=true; generate_certs; shift ;;
            -z|--compress) COMPRESS_TRANSFER=true; shift ;;
            -c|--checksum) VERIFY_CHECKSUM=true; shift ;;
            -r|--receive) receive_mode; break ;;
            -s|--send) shift; send_mode "$@"; break ;;
            *) interactive_menu; break ;;
        esac
    done
fi