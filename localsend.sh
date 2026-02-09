#!/bin/bash

# --- Configuration ---
FILE_PORT=9999
DISCOVERY_PORT=9998
VERSION="1.3"

# Colors & Icons
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

TICK="${GREEN}✔${NC}"
ARROW="${BLUE}➜${NC}"
FLASH="${YELLOW}⚡${NC}"
INFO="${CYAN}ℹ${NC}"

# --- Dependency Check ---
check_dependencies() {
    local missing=()
    local tools=("socat" "pv" "tar" "hostname")
    for cmd in "${tools[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then missing+=("$cmd"); fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}[!] Missing tools: ${missing[*]}${NC}"
        local pkg_mgr=""
        local install_cmd=""
        if command -v apt-get &>/dev/null; then pkg_mgr="apt"; install_cmd="sudo apt-get update && sudo apt-get install -y"
        elif command -v pacman &>/dev/null; then pkg_mgr="pacman"; install_cmd="sudo pacman -Sy --noconfirm"
        elif command -v dnf &>/dev/null; then pkg_mgr="dnf"; install_cmd="sudo dnf install -y"
        elif command -v brew &>/dev/null; then pkg_mgr="brew"; install_cmd="brew install"
        fi
        if [[ -n "$pkg_mgr" ]]; then
            echo -en "${BLUE}[?] Install missing tools via $pkg_mgr? (y/n): ${NC}"
            read -r choice
            [[ "$choice" =~ ^[Yy]$ ]] && eval "$install_cmd ${missing[*]}" || exit 1
        else
            echo -e "${RED}Install manually: ${missing[*]}${NC}"; exit 1
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

check_dependencies
MY_IP=$(get_ip)
MY_NAME=$(generate_name)

# --- Discovery Logic ---
start_discovery_responder() {
    while true; do
        data=$(socat -u UDP4-RECVFROM:$DISCOVERY_PORT,fork,reuseaddr - 2>/dev/null | head -n 1)
        if [[ "$data" == "LOCALSEND_SCAN" ]]; then
            echo "LOCALSEND_PEER|$MY_NAME|$MY_IP" | socat -u - UDP4-DATAGRAM:255.255.255.255:$DISCOVERY_PORT,broadcast 2>/dev/null
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
        echo "LOCALSEND_SCAN" | socat -u - UDP4-DATAGRAM:$brd:$DISCOVERY_PORT,broadcast 2>/dev/null
    done
    local raw_peers=()
    while read -r -t 1.5 line; do
        [[ "$line" == LOCALSEND_PEER* ]] && raw_peers+=("$line")
    done < <(socat -u UDP4-RECVFROM:$DISCOVERY_PORT,reuseaddr - 2>/dev/null)
    kill $spinner_pid 2>/dev/null; wait $spinner_pid 2>/dev/null
    printf "%s\n" "${raw_peers[@]}" | sort -u
}

# --- Modes ---
receive_mode() {
    MY_IP=$(get_ip)
    clear
    echo -e "${PURPLE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${PURPLE}┃${NC}  ${GREEN}⚡ LOCALSEND CLI RECEIVER (v$VERSION)${NC}           ${PURPLE}┃${NC}"
    echo -e "${PURPLE}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫${NC}"
    printf "${PURPLE}┃${NC}  ${INFO} Name : %-41s ${PURPLE}┃${NC}\n" "${YELLOW}$MY_NAME${NC}"
    printf "${PURPLE}┃${NC}  ${INFO} IP   : %-41s ${PURPLE}┃${NC}\n" "${YELLOW}$MY_IP${NC}"
    echo -e "${PURPLE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo -e "${YELLOW}Tip: Press Ctrl+C to return to Main Menu${NC}"
    
    start_discovery_responder &
    local disc_pid=$!
    trap "kill $disc_pid 2>/dev/null; interactive_menu; return" INT
    
    while true; do
        echo -e "\n${FLASH} Waiting for incoming files..."
        socat -u TCP4-LISTEN:$FILE_PORT,reuseaddr,rcvbuf=1048576 - | tar -xvB -b 128
        echo -e "\n${TICK} ${GREEN}Transfer Success!${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────────${NC}"
    done
}

send_mode() {
    local items=("$@")
    if [[ ${#items[@]} -eq 0 ]]; then
        trap "interactive_menu; return" INT
        clear
        echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
        echo -e "${BLUE}┃${NC}  ${GREEN}⚡ LOCALSEND CLI SENDER (v$VERSION)${NC}             ${BLUE}┃${NC}"
        echo -e "${BLUE}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫${NC}"
        printf "${BLUE}┃${NC}  ${INFO} Name : %-41s ${BLUE}┃${NC}\n" "${YELLOW}$MY_NAME${NC}"
        printf "${BLUE}┃${NC}  ${INFO} IP   : %-41s ${BLUE}┃${NC}\n" "${YELLOW}$MY_IP${NC}"
        echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
        echo -e "${YELLOW}Tip: Press Ctrl+C or type 'b' to go back${NC}"
        echo -e "\n${INFO} ${YELLOW}Drag and drop files here or type paths${NC}"
        echo -en "${ARROW} ${YELLOW}Path(s):${NC} "
        read -e -r input_paths
        [[ -z "$input_paths" || "$input_paths" == "b" ]] && { interactive_menu; return; }
        [[ "$input_paths" == "q" ]] && exit 0
        eval "items=($input_paths)"
    fi

    [[ ${#items[@]} -eq 0 ]] && { interactive_menu; return; }
    trap "interactive_menu; return" INT

    while true; do
        clear
        echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
        echo -e "${BLUE}┃${NC}  ${GREEN}⚡ LOCALSEND CLI SENDER (v$VERSION)${NC}             ${BLUE}┃${NC}"
        echo -e "${BLUE}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫${NC}"
        printf "${BLUE}┃${NC}  ${INFO} Name : %-41s ${BLUE}┃${NC}\n" "${YELLOW}$MY_NAME${NC}"
        printf "${BLUE}┃${NC}  ${INFO} IP   : %-41s ${BLUE}┃${NC}\n" "${YELLOW}$MY_IP${NC}"
        echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
        echo -e "${CYAN} Prepare to send:${NC} ${WHITE}${#items[@]} item(s)${NC}"
        echo -e "${CYAN} ──────────────────────────────────────────────────────${NC}"
        
        mapfile -t peers < <(scan_devices)
        if [[ ${#peers[@]} -eq 0 ]]; then
            echo -e "\n  ${RED}✖ No devices found in your network.${NC}"
            echo -e "  ${YELLOW}──────────────────────────────────────────────────────${NC}"
            echo -e "  ${CYAN}[r]${NC} Rescan | ${CYAN}[m]${NC} Manual | ${CYAN}[b]${NC} Back | ${CYAN}[q]${NC} Quit"
            echo -en "\n${ARROW} ${WHITE}Action:${NC} "; read -r r
            [[ "$r" == "r" ]] && continue
            [[ "$r" == "b" ]] && { interactive_menu; return; }
            [[ "$r" == "q" ]] && exit 0
            [[ "$r" == "m" ]] && choice="m" || { interactive_menu; return; }
        else
            echo -e "\n  ${YELLOW}ONLINE DEVICES:${NC}"
            echo -e "  ${WHITE}ID   DEVICE NAME              IP ADDRESS${NC}"
            echo -e "  ──   ───────────              ──────────"
            for i in "${!peers[@]}"; do
                IFS='|' read -r p n ip <<< "${peers[$i]}"
                printf "  ${CYAN}%-4s${NC} ${GREEN}%-24s${NC} ${BLUE}%-15s${NC}\n" "$((i+1)))" "$n" "$ip"
            done
            echo -e "\n  ${CYAN}r)${NC} Rescan | ${CYAN}m)${NC} Manual IP | ${CYAN}b)${NC} Back"
            echo -en "\n${ARROW} ${WHITE}Select target:${NC} "; read -r choice
        fi
        
        if [[ "$choice" == "r" ]]; then continue
        elif [[ "$choice" == "b" ]]; then interactive_menu; return
        elif [[ "$choice" == "m" ]]; then echo -en "\n${ARROW} ${YELLOW}Enter IP: "; read -r target_ip; [[ -n "$target_ip" ]] && break
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#peers[@]}" ]; then
            IFS='|' read -r p n target_ip <<< "${peers[$((choice-1))]}"; break
        fi
    done

    echo -e "\n${TICK} ${YELLOW}Initiating transfer to ${GREEN}$target_ip${NC}..."
    echo -e "${CYAN} ──────────────────────────────────────────────────────${NC}"
    tar -cv -b 128 "${items[@]}" | pv -p -b -r -a -N "Transfer" | socat -u - TCP4:$target_ip:$FILE_PORT,sndbuf=1048576,tcpnodelay
    echo -e "${CYAN} ──────────────────────────────────────────────────────${NC}"
    echo -e "${TICK} ${GREEN}Success! All items sent.${NC}"
    echo -en "\n${ARROW} Press Enter to return to menu..."; read -r; interactive_menu
}

install_global() {
    sudo ln -sf "$(realpath "$0")" "/usr/local/bin/localsend" && echo -e "${TICK} Installed! Use 'localsend' anywhere."
    sleep 2; interactive_menu
}

interactive_menu() {
    MY_IP=$(get_ip)
    clear
    echo -e "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${CYAN}┃${NC}          ${GREEN}🚀 WELCOME TO LOCALSEND CLI v$VERSION${NC}          ${CYAN}┃${NC}"
    echo -e "${CYAN}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫${NC}"
    echo -e "${CYAN}┃${NC}                                                      ${CYAN}┃${NC}"
    echo -e "${CYAN}┃${NC}  ${WHITE}1)${NC} ${GREEN}Receive Files${NC}  (Wait for incoming)           ${CYAN}┃${NC}"
    echo -e "${CYAN}┃${NC}  ${WHITE}2)${NC} ${BLUE}Send Files${NC}     (Scan & send to peer)         ${CYAN}┃${NC}"
    echo -e "${CYAN}┃${NC}  ${WHITE}i)${NC} ${YELLOW}Install Global${NC} (Access from anywhere)        ${CYAN}┃${NC}"
    echo -e "${CYAN}┃${NC}  ${WHITE}q)${NC} ${RED}Quit${NC}           (Exit application)            ${CYAN}┃${NC}"
    echo -e "${CYAN}┃${NC}                                                      ${CYAN}┃${NC}"
    echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo -en "\n${ARROW} ${WHITE}Select option:${NC} "; read -r c
    case "$c" in
        1) receive_mode ;;
        2) send_mode ;;
        i|I) install_global ;;
        q|Q) exit 0 ;;
        *) interactive_menu ;;
    esac
}

if [[ $# -eq 0 ]]; then interactive_menu; else
    case "$1" in
        -r|--receive) receive_mode ;;
        -s|--send) shift; send_mode "$@" ;;
        *) interactive_menu ;;
    esac
fi