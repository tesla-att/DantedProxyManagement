#!/bin/bash

# Danted SOCKS5 Proxy Manager v1.0
# Professional script for managing SOCKS5 proxy server on Ubuntu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Configuration variables
DANTED_CONFIG="/etc/danted.conf"
CONFIG_DIR="configFiles"
DANTED_SERVICE="danted"
SELECTED_IP=""
SELECTED_PORT=""

# Create config directory if not exists
if [[ ! -d "$CONFIG_DIR" ]]; then
    mkdir -p "$CONFIG_DIR" 2>/dev/null || {
        echo -e "${RED}Failed to create config directory: $CONFIG_DIR${NC}"
        echo -e "${RED}Please check if you have the necessary permissions to create directories.${NC}"
        exit 1
    }
fi

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print fancy header
print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}                        DANTED SOCKS5 PROXY MANAGER v1.0                      ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Function to print section header
print_section_header() {
    local title=$1
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE}${BOLD} $title${NC}${BLUE}$(printf "%*s" $((77 - ${#title})) "")│${NC}"
    echo -e "${BLUE}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

# Function to print info box
print_info_box() {
    local message=$1
    local color=${2:-$CYAN}
    echo -e "${color}┌─ INFO ───────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${color}${NC} $message"
    echo -e "${color}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

# Function to print success message
print_success() {
    local message=$1
    echo -e "${GREEN}✓${NC} ${GREEN}$message${NC}"
}

# Function to print error message
print_error() {
    local message=$1
    echo -e "${RED}✗${NC} ${RED}$message${NC}"
}

# Function to print warning message
print_warning() {
    local message=$1
    echo -e "${YELLOW}⚠${NC} ${YELLOW}$message${NC}"
}

# Function to read multiline input with paste support
read_multiline_input() {
    local prompt=$1
    local items=()
    local line_count=0
    
    print_color $YELLOW "$prompt"
    echo -e "${GRAY}Enter data (empty line twice to finish):${NC}"
    
    local empty_count=0
    local seen_lines=()
    
    while true; do
        read -r line
        
        if [[ -z "$line" ]]; then
            ((empty_count++))
            if [[ $empty_count -ge 2 ]]; then
                break
            fi
        else
            empty_count=0
            if [[ -n "$line" ]]; then
                # Trim whitespace
                line=$(echo "$line" | xargs)
                
                # Check for duplicates
                local is_duplicate=false
                for seen_line in "${seen_lines[@]}"; do
                    if [[ "$seen_line" == "$line" ]]; then
                        is_duplicate=true
                        break
                    fi
                done
                
                if [[ "$is_duplicate" == false ]]; then
                    items+=("$line")
                    seen_lines+=("$line")
                    ((line_count++))
                    # Print feedback to stderr so it doesn't get captured in return value
                    echo -e "  ✓ [$line_count] $line" >&2
                else
                    echo -e "  ⚠ Duplicate skipped: $line" >&2
                fi
            fi
        fi
    done
    
    # Return only the pure data - output to stdout
    for item in "${items[@]}"; do
        echo "$item"
    done
}

# Function to get network interfaces with IPs
get_network_interfaces() {
    print_section_header "Network Interface Selection"

    
    local interfaces=()
    local ips=()
    local counter=1
    
    echo -e "${CYAN}╭─ Available Network Interfaces ───────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}${NC} ${WHITE}No.${NC} ${WHITE}Interface Name          ${WHITE}IP Address${NC}"
    while IFS= read -r line; do
        interface=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | awk '{print $2}')
        if [[ "$interface" != "lo" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            interfaces+=("$interface")
            ips+=("$ip")
            printf "${CYAN}${NC} %2d. %-20s ${GREEN}%s${NC}%*s${CYAN}${NC}\n" $counter "$interface" "$ip" $((50 - ${#interface} - ${#ip})) ""
            ((counter++))
        fi
    done < <(ip -4 addr show | grep -oP '^\d+: \K\w+|inet \K[^/]+' | paste - -)
    
    echo -e "${CYAN}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        print_error "No network interfaces found!"
        return 1
    fi
    
    while true; do
        read -p "$(echo -e "${YELLOW}❯${NC} Select interface number: ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#interfaces[@]} ]]; then
            SELECTED_IP="${ips[$((choice-1))]}"
            print_success "Selected: ${interfaces[$((choice-1))]} - $SELECTED_IP"
            break
        else
            print_error "Invalid selection. Please try again."
        fi
    done
    return 0
}

# Function to get system info
get_system_info() {
    # Get system metrics
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
    local memory_info=$(free -h | grep "Mem:" 2>/dev/null || echo "N/A N/A N/A")
    local memory_used=$(echo $memory_info | awk '{print $3}' 2>/dev/null || echo "N/A")
    local memory_total=$(echo $memory_info | awk '{print $2}' 2>/dev/null || echo "N/A")
    local disk_usage=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' 2>/dev/null || echo "N/A")
    local uptime_info=$(uptime -p 2>/dev/null || echo "N/A")
    
    # Truncate long uptime for consistent display
    if [[ ${#uptime_info} -gt 35 ]]; then
        uptime_info="${uptime_info:0:32}..."
    fi
    
    # Fixed width box - 77 characters total width
    echo -e "${CYAN}╭─ System Information ─────────────────────────────────────────────────────────╮${NC}"

    # CPU Usage - fixed width formatting
    printf "${CYAN}${NC} CPU Usage:    ${GREEN}%-15s${NC}%*s${CYAN}${NC}\n" "${cpu_usage}%" $((58 - ${#cpu_usage})) ""
    
    # Memory - fixed width formatting  
    local memory_display="${memory_used} / ${memory_total}"
    if [[ ${#memory_display} -gt 25 ]]; then
        memory_display="${memory_used}/${memory_total}"
    fi
    printf "${CYAN}${NC} Memory:       ${GREEN}%-25s${NC}%*s${CYAN}${NC}\n" "$memory_display" $((48 - ${#memory_display})) ""
    
    # Disk Usage - fixed width formatting
    printf "${CYAN}${NC} Disk Usage:   ${GREEN}%-15s${NC}%*s${CYAN}${NC}\n" "$disk_usage" $((58 - ${#disk_usage})) ""
    
    # Uptime - fixed width formatting
    printf "${CYAN}${NC} Uptime:       ${GREEN}%-35s${NC}%*s${CYAN}${NC}\n" "$uptime_info" $((38 - ${#uptime_info})) ""
    
    echo -e "${CYAN}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
}

# Function to check service status
check_service_status() {
    print_header
    print_section_header "Service Status & System Monitoring"
    
    # Service status - Fixed width box
    echo -e "${CYAN}╭─ Danted Service Status ──────────────────────────────────────────────────────╮${NC}"
    if ! systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        print_warning "Danted service is not running. Please start it first."
        echo
        read -p "Press Enter to continue..."
        return
    fi
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        local status="RUNNING"
        local color=$GREEN
        local status_icon="●"
    else
        local status="STOPPED"
        local color=$RED
        local status_icon="●"
    fi
    
    # Fixed width formatting for service status
    printf "${CYAN}${NC} Service:      ${color}${status_icon} %-15s${NC}%*s${CYAN}${NC}\n" "$status" $((56 - ${#status})) ""
    
    if systemctl is-enabled --quiet $DANTED_SERVICE 2>/dev/null; then
        printf "${CYAN}${NC} Auto-start:   ${GREEN}● %-15s${NC}%*s${CYAN}${NC}\n" "ENABLED" 54 ""
    else
        printf "${CYAN}${NC} Auto-start:   ${RED}● %-15s${NC}%*s${CYAN}${NC}\n" "DISABLED" 53 ""
    fi
    
    # Get port and IP if config exists
    if [[ -f "$DANTED_CONFIG" ]]; then
        local config_ip=$(grep "internal:" "$DANTED_CONFIG" | awk '{print $2}' 2>/dev/null || echo "N/A")
        local config_port=$(grep "internal:" "$DANTED_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ' 2>/dev/null || echo "N/A")
        local listen_address="${config_ip}:${config_port}"
        
        # Truncate if too long
        if [[ ${#listen_address} -gt 25 ]]; then
            listen_address="${listen_address:0:22}..."
        fi
        
        printf "${CYAN}${NC} Listen on:    ${YELLOW}%-25s${NC}%*s${CYAN}${NC}\n" "$listen_address" $((48 - ${#listen_address})) ""
    else
        printf "${CYAN}${NC} Listen on:    ${GRAY}%-25s${NC}%*s${CYAN}${NC}\n" "Not configured" 48 ""
    fi
    
    # Active connections
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null && [[ -f "$DANTED_CONFIG" ]]; then
        local config_port=$(grep "internal:" "$DANTED_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ' 2>/dev/null)
        local connections=$(netstat -tn 2>/dev/null | grep ":$config_port " | wc -l 2>/dev/null || echo "0")
        printf "${CYAN}${NC} Connections:  ${BLUE}%-15s${NC}%*s${CYAN}${NC}\n" "$connections active" $((56 - ${#connections})) ""
    else
        printf "${CYAN}${NC} Connections:  ${GRAY}%-15s${NC}%*s${CYAN}${NC}\n" "N/A" 56 ""
    fi
    
    echo -e "${CYAN}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo
    
    # System information
    get_system_info
    echo
    
    # Recent logs - Fixed width
    echo -e "${CYAN}╭─ Recent Service Logs ────────────────────────────────────────────────────────╮${NC}"
    if ! systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        print_warning "Danted service is not running. No logs available."
        echo
        read -p "Press Enter to continue..."
        return
    fi
    echo -e "${CYAN}${NC} ${GRAY}Last 3 logs from the last hour:${NC}${CYAN}${NC}"
    if journalctl -u $DANTED_SERVICE --no-pager -n 3 --since "1 hour ago" 2>/dev/null | grep -q "."; then
        journalctl -u $DANTED_SERVICE --no-pager -n 3 --since "1 hour ago" 2>/dev/null | while read -r line; do
            # Truncate long log lines to fit in box
            if [[ ${#line} -gt 75 ]]; then
                line="${line:0:72}..."
            fi
            printf "${CYAN}${NC} ${GRAY}%-75s${NC}${CYAN}${NC}\n" "$line"
        done
    else
        printf "${CYAN}${NC} ${GRAY}%-75s${NC}${CYAN}${NC}\n" "No recent logs found"
    fi
    echo -e "${CYAN}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    echo
    
    # Control options
    echo -e "${YELLOW}Control Options:${NC}"
    echo -e "${CYAN}1.${NC} Restart Service"
    echo -e "${CYAN}2.${NC} Stop Service"
    echo -e "${CYAN}3.${NC} Start Service"
    echo -e "${CYAN}4.${NC} View Full Logs"
    echo -e "${CYAN}5.${NC} Test Internet Bandwidth"
    echo -e "${CYAN}6.${NC} Back to Main Menu"
    echo
    
    while true; do
        read -p "$(echo -e "${YELLOW}❯${NC} Select option [1-6]: ")" choice
        
        case $choice in
            1)
                print_color $YELLOW "Restarting Danted service..."
                if systemctl restart $DANTED_SERVICE; then
                    print_success "Service restarted successfully!"
                else
                    print_error "Failed to restart service!"
                fi
                sleep 2
                check_service_status
                return
                ;;
            2)
                print_color $YELLOW "Stopping Danted service..."
                if systemctl stop $DANTED_SERVICE; then
                    print_success "Service stopped successfully!"
                else
                    print_error "Failed to stop service!"
                fi
                sleep 2
                check_service_status
                return
                ;;
            3)
                print_color $YELLOW "Starting Danted service..."
                if systemctl start $DANTED_SERVICE; then
                    print_success "Service started successfully!"
                else
                    print_error "Failed to start service!"
                fi
                sleep 2
                check_service_status
                return
                ;;
            4)
                print_section_header "Full Service Logs"
                journalctl -u $DANTED_SERVICE --no-pager -n 50
                echo
                read -p "Press Enter to continue..."
                check_service_status
                return
                ;;
            5)
                test_bandwidth
                check_service_status
                return
                ;;
            6)
                break
                ;;
            *)
                print_error "Invalid option!"
                ;;
        esac
    done
}

# Function to test bandwidth
test_bandwidth() {
    print_section_header "Internet Bandwidth Test"
    
    print_color $YELLOW "Testing download speed..."
    
    # Test with curl
    local test_file="http://speedtest.ftp.otenet.gr/files/test1Mb.db"
    local start_time=$(date +%s.%N)
    
    if curl -s -w "%{speed_download}" -o /dev/null "$test_file" 2>/dev/null | grep -q "[0-9]"; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1")
        local speed=$(curl -s -w "%{speed_download}" -o /dev/null "$test_file" 2>/dev/null)
        local speed_mbps=$(echo "scale=2; $speed / 1024 / 1024 * 8" | bc 2>/dev/null || echo "0")
        
        print_success "Download speed: ${speed_mbps} Mbps"
        print_info_box "Test completed in ${duration}s"

    else
        print_error "Bandwidth test failed!"
        print_warning "Please check your internet connection."
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to install Danted
install_danted() {
    print_header
    print_section_header "Install Danted SOCKS5 Proxy Server"    
    
    # Check if already installed
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        print_warning "Danted is already installed and running."
        echo -e "${YELLOW}You can reinstall it, but this will stop the current service.${NC}"
        read -p "$(echo -e "${YELLOW}❯${NC} Do you want to reinstall? (y/N): ")" reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return
        fi
        systemctl stop $DANTED_SERVICE 2>/dev/null
        print_color $YELLOW "Stopping existing Danted service..."
    fi
    
    # Get network interface
    if ! get_network_interfaces; then
        read -p "Press Enter to continue..."
        return
    fi
    
    # Get port
    echo
    while true; do
        read -p "$(echo -e "${YELLOW}❯${NC} Enter SOCKS5 port (default: 1080): ")" port
        port=${port:-1080}
        if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
            if ! netstat -tuln 2>/dev/null | grep -q ":$port "; then
                SELECTED_PORT="$port"
                break
            else
                print_error "Port $port is already in use. Please choose another port."
                
            fi
        else
            print_error "Invalid port number. Please enter a number between 1-65535."
        fi
    done
    
    echo
    print_info_box "Installing Danted SOCKS5 Proxy Server..."
    
    # Update package list
    echo -e "${GRAY}Updating package list...${NC}"
    apt update -qq
    
    # Install Danted
    echo -e "${GRAY}Installing dante-server...${NC}"
    if ! apt install -y dante-server >/dev/null 2>&1; then
        print_error "Failed to install Danted!"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Create Danted configuration
    echo -e "${GRAY}Creating configuration...${NC}"
    cat > "$DANTED_CONFIG" << 'EOF'
# Danted SOCKS5 Proxy Configuration
logoutput: /var/log/danted.log
internal: SELECTED_IP_PLACEHOLDER port = SELECTED_PORT_PLACEHOLDER
external: SELECTED_IP_PLACEHOLDER

# Authentication methods
socksmethod: username

# Client rules
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
}

# SOCKS rules
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
    socksmethod: username
}
EOF
    
    # Replace placeholders
    sed -i "s/SELECTED_IP_PLACEHOLDER/$SELECTED_IP/g" "$DANTED_CONFIG"
    sed -i "s/SELECTED_PORT_PLACEHOLDER/$SELECTED_PORT/g" "$DANTED_CONFIG"
    
    # Enable and start service
    echo -e "${GRAY}Starting service...${NC}"
    systemctl enable $DANTED_SERVICE >/dev/null 2>&1
    systemctl restart $DANTED_SERVICE
    
    # Check status
    sleep 2
    echo
    if systemctl is-active --quiet $DANTED_SERVICE; then
        print_success "Danted installed and started successfully!"
        print_success "Listening on: $SELECTED_IP:$SELECTED_PORT"
        print_success "Service status: Active"
    else
        print_error "Failed to start Danted service!"
        print_warning "Checking logs..."
        journalctl -u $DANTED_SERVICE --no-pager -n 10
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to show users
show_users() {
    print_header
    print_section_header "SOCKS5 Proxy Users"
    
    local users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            users+=("$user")
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1 | sort)
    
    if [[ ${#users[@]} -eq 0 ]]; then
        print_warning "No SOCKS5 users found."
    else
        echo -e "${CYAN}╭─ Users List (${#users[@]} users) ───────────────────────────────────────────────────────╮${NC}"
        for i in "${!users[@]}"; do
            printf "${CYAN}${NC} %3d. %-20s%*s${CYAN}${NC}\n" $((i+1)) "${users[i]}" $((50 - ${#users[i]})) ""
        done
        echo -e "${CYAN}╰───────────────────────────────────────────────────────────────────────────────╯${NC}"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to create config file for user
create_user_config() {
    local username=$1
    local password=$2
    
    # Ensure config directory exists
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
        if [[ $? -ne 0 ]]; then
            print_error "Failed to create config directory: $CONFIG_DIR"
            return 1
        fi
    fi
    
    if [[ -z "$SELECTED_IP" || -z "$SELECTED_PORT" ]]; then
        # Try to get from existing config
        if [[ -f "$DANTED_CONFIG" ]]; then
            SELECTED_IP=$(grep "internal:" "$DANTED_CONFIG" | awk '{print $2}')
            SELECTED_PORT=$(grep "internal:" "$DANTED_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ')
        fi
    fi
    
    if [[ -z "$SELECTED_IP" || -z "$SELECTED_PORT" ]]; then
        print_error "Server IP and port not configured. Please install Danted first."
        return 1
    fi
    
    # Create config content
    cat > "$CONFIG_DIR/$username" << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "dns": {
    "hosts": {
      "dns.google": "8.8.8.8",
      "proxy.example.com": "127.0.0.1"
    },
    "servers": [
      {
        "address": "1.1.1.1",
        "skipFallback": true,
        "domains": [
          "domain:googleapis.cn",
          "domain:gstatic.com"
        ]
      },
      {
        "address": "223.5.5.5",
        "skipFallback": true,
        "domains": [
          "geosite:cn"
        ],
        "expectIPs": [
          "geoip:cn"
        ]
      },
      "1.1.1.1",
      "8.8.8.8",
      "https://dns.google/dns-query"
    ]
  },
  "inbounds": [
    {
      "tag": "socks",
      "port": 10808,
      "listen": "127.0.0.1",
      "protocol": "mixed",
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ],
        "routeOnly": false
      },
      "settings": {
        "auth": "noauth",
        "udp": true,
        "allowTransparent": false
      }
    }
  ],
  "outbounds": [
    {
      "tag": "proxy-1",
      "protocol": "socks",
      "settings": {
        "servers": [
          {
            "address": "$SELECTED_IP",
            "ota": false,
            "port": $SELECTED_PORT,
            "level": 1,
            "users": [
              {
                "user": "$username",
                "pass": "$password",
                "level": 1
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp"
      },
      "mux": {
        "enabled": false,
        "concurrency": -1
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api"
      },
      {
        "type": "field",
        "balancerTag": "proxy-round",
        "domain": [
          "domain:googleapis.cn",
          "domain:gstatic.com",
          "*.telegram.org",
          "*.t.me",
          "*.telegram.me"
        ]
      },
      {
        "type": "field",
        "port": "443",
        "network": "udp",
        "outboundTag": "block"
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "ip": [
          "geoip:private"
        ]
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "domain": [
          "geosite:private"
        ]
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "ip": [
          "223.5.5.5",
          "223.6.6.6",
          "2400:3200::1",
          "2400:3200:baba::1",
          "119.29.29.29",
          "1.12.12.12",
          "120.53.53.53",
          "2402:4e00::",
          "2402:4e00:1::",
          "180.76.76.76",
          "2400:da00::6666",
          "114.114.114.114",
          "114.114.115.115",
          "114.114.114.119",
          "114.114.115.119",
          "114.114.114.110",
          "114.114.115.110",
          "180.184.1.1",
          "180.184.2.2",
          "101.226.4.6",
          "218.30.118.6",
          "123.125.81.6",
          "140.207.198.6",
          "1.2.4.8",
          "210.2.4.8",
          "52.80.60.30"
        ]
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "domain": [
          "domain:alidns.com",
          "domain:doh.pub",
          "domain:dot.pub",
          "domain:360.cn",
          "domain:onedns.net"
        ]
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "ip": [
          "geoip:cn"
        ]
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "domain": [
          "geosite:cn"
        ]
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "balancerTag": "proxy-round"
      }
    ],
    "balancers": [
      {
        "selector": [
          "proxy"
        ],
        "strategy": {
          "type": "random"
        },
        "tag": "proxy-round"
      }
    ]
  }
}
EOF
    
    if [[ $? -eq 0 ]]; then
        return 0
    else
        print_error "Failed to create config file for user: $username"
        return 1
    fi
}

# Function to add single user
add_single_user() {
    print_header
    print_section_header "Add Single User"
    
    while true; do
        read -p "$(echo -e "${YELLOW}❯${NC} Enter username: ")" username
        if [[ -n "$username" && "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            if id "$username" &>/dev/null; then
                print_error "User '$username' already exists!"
            else
                break
            fi
        else
            print_error "Invalid username. Use only letters, numbers, underscore and dash."
        fi
    done
    
    while true; do
        read -s -p "$(echo -e "${YELLOW}❯${NC} Enter password: ")" password
        echo
        if [[ ${#password} -ge 4 ]]; then
            read -s -p "$(echo -e "${YELLOW}❯${NC} Confirm password: ")" password2
            echo
            if [[ "$password" == "$password2" ]]; then
                break
            else
                print_error "Passwords don't match!"
            fi
        else
            print_error "Password must be at least 4 characters long!"
        fi
    done
    
    echo
    print_color $YELLOW "Creating user..."
    
    # Create user
    if useradd -r -s /bin/false "$username"; then
        echo "$username:$password" | chpasswd
        create_user_config "$username" "$password"
        print_success "User '$username' created successfully!"
        print_success "Config file created: $CONFIG_DIR/$username"
    else
        print_error "Failed to create user '$username'!"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to add multiple users
add_multi_users() {
    print_header
    print_section_header "Add Multiple Users"

    echo -e "${GRAY}Enter data (empty line twice to finish):${NC}"
    # Read usernames using multiline input
    local usernames_input
    usernames_input=$(read_multiline_input "Enter usernames (one per line):")
    if [[ -z "$usernames_input" ]]; then
        print_error "No usernames provided!"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Parse usernames - SILENT VALIDATION (NO ERROR MESSAGES)
    local usernames=()
    local line_num=0
    while IFS= read -r username; do
        ((line_num++))
        # Skip empty lines
        [[ -z "$username" ]] && continue
        
        # Trim whitespace
        username=$(echo "$username" | xargs)
        
        if [[ -n "$username" ]]; then
            if [[ "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                if ! id "$username" &>/dev/null; then
                    usernames+=("$username")
                fi
                # Removed error messages for existing users and invalid usernames
            fi
        fi
    done <<< "$usernames_input"
    
    if [[ ${#usernames[@]} -eq 0 ]]; then
        print_error "No valid usernames provided!"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    print_info_box "Creating ${#usernames[@]} users..."
    echo
    
    # Create users and set passwords
    local created_users=()
    for username in "${usernames[@]}"; do
        echo -e "${CYAN}Setting up user: ${WHITE}$username${NC}"
        
        while true; do
            read -s -p "$(echo -e "${YELLOW}❯${NC} Set password for '$username': ")" password
            echo
            if [[ ${#password} -ge 4 ]]; then
                read -s -p "$(echo -e "${YELLOW}❯${NC} Confirm password for '$username': ")" password2
                echo
                if [[ "$password" == "$password2" ]]; then
                    if useradd -r -s /bin/false "$username" 2>/dev/null; then
                        if echo "$username:$password" | chpasswd 2>/dev/null; then
                            if create_user_config "$username" "$password"; then
                                created_users+=("$username")
                                print_success "User '$username' created successfully!"
                            else
                                print_warning "User '$username' created but config file failed!"
                                created_users+=("$username")
                            fi
                        else
                            print_error "Failed to set password for user '$username'!"
                            userdel "$username" 2>/dev/null
                        fi
                    else
                        print_error "Failed to create user '$username'!"
                    fi
                    break
                else
                    print_error "Passwords don't match for '$username'!"
                fi
            else
                print_error "Password for '$username' must be at least 4 characters long!"
            fi
        done
        echo
    done
    
    echo
    print_success "Successfully created ${#created_users[@]} users!"
    print_success "Config files created in: $CONFIG_DIR/"
    
    echo
    read -p "Press Enter to continue..."
}

# Function to manage user addition
manage_add_users() {
    while true; do
        print_header
        print_section_header "Add Users Menu"
        
        echo -e "${CYAN}1.${NC} Add single user"
        echo -e "${CYAN}2.${NC} Add multiple users"
        echo -e "${CYAN}3.${NC} Back to main menu"
        echo
        
        read -p "$(echo -e "${YELLOW}❯${NC} Select option [1-3]: ")" choice
        
        case $choice in
            1) add_single_user ;;
            2) add_multi_users ;;
            3) break ;;
            *) print_error "Invalid option!" ;;
        esac
    done
}

# Function to delete users
delete_users() {
    print_header
    print_section_header "Delete Users"
    
    local users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            users+=("$user")
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1 | sort)
    
    if [[ ${#users[@]} -eq 0 ]]; then
        print_warning "No SOCKS5 users found to delete."
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${CYAN}╭─ Available Users to Delete ──────────────────────────────────────────────────╮${NC}"
    for i in "${!users[@]}"; do
        printf "${CYAN}${NC} %3d. %-20s%*s${CYAN}${NC}\n" $((i+1)) "${users[i]}" $((50 - ${#users[i]})) ""
    done
    echo -e "${CYAN}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    
    echo
    print_info_box "Enter user numbers to delete (space-separated, e.g., '1 3 5'):"
    read -p "$(echo -e "${YELLOW}❯${NC} Selection: ")" selections
    
    if [[ -z "$selections" ]]; then
        print_warning "No selection made."
        read -p "Press Enter to continue..."
        return
    fi
    
    local to_delete=()
    for selection in $selections; do
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#users[@]} ]]; then
            to_delete+=("${users[$((selection-1))]}")
        else
            print_error "Invalid selection: $selection"
        fi
    done
    
    if [[ ${#to_delete[@]} -eq 0 ]]; then
        print_error "No valid users selected!"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    print_warning "Users to be deleted:"
    for user in "${to_delete[@]}"; do
        echo -e "  ${RED}•${NC} $user"
    done
    
    echo
    read -p "$(echo -e "${RED}❯${NC} Are you sure you want to delete these users? (y/N): ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    print_color $YELLOW "Deleting users..."
    
    # Delete users
    local deleted_count=0
    for user in "${to_delete[@]}"; do
        if userdel "$user" 2>/dev/null; then
            # Remove config file
            rm -f "$CONFIG_DIR/$user"
            print_success "Deleted user: $user"
            ((deleted_count++))
        else
            print_error "Failed to delete user: $user"
        fi
    done
    
    echo
    print_success "Successfully deleted $deleted_count users!"
    
    echo
    read -p "Press Enter to continue..."
}

# Function to test proxies
test_proxies() {
    print_header
    print_section_header "Test Proxies"
    
    # Show format example clearly
    echo -e "${YELLOW}Format: ${WHITE}IP:PORT:USERNAME:PASSWORD${NC}"
    echo -e "${GRAY}Example:${NC}"
    echo -e "  ${CYAN}103.195.238.251:30202:user1:pass123${NC}"
    echo -e "  ${CYAN}192.168.1.100:1080:alice:secret456${NC}"
    echo -e "${GRAY}Enter one proxy per line, leave empty line to finish.${NC}"
    echo
    
    # Read proxy list using multiline input
    local proxies_input
    # Redirect stderr to display feedback, capture only stdout (pure data)
    exec 3>&1 4>&2
    proxies_input=$(read_multiline_input "Enter proxy list:" 2>&4)
    exec 3>&- 4>&-
    
    if [[ -z "$proxies_input" ]]; then
        print_error "No proxies provided!"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    
    # Parse proxies with silent validation (no error messages)
    local proxies=()
    local line_num=0
    local valid_count=0
    local invalid_count=0
    
    # Process each line from input
    while IFS= read -r proxy_line; do
        ((line_num++))
        
        # Skip empty lines
        if [[ -z "$proxy_line" ]]; then
            continue
        fi
        
        # Trim whitespace
        proxy_line=$(echo "$proxy_line" | xargs)
        
        # Skip if still empty after trim
        if [[ -z "$proxy_line" ]]; then
            continue
        fi
        
        # Simple validation: count colons and check basic format
        local colon_count=$(echo "$proxy_line" | tr -cd ':' | wc -c)
        
        if [[ $colon_count -eq 3 ]]; then
            # Split and validate components
            IFS=':' read -r ip port user pass <<< "$proxy_line"
            
            # Check if all components exist and port is numeric
            if [[ -n "$ip" && -n "$port" && -n "$user" && -n "$pass" ]]; then
                if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
                    # Check for duplicates in proxies array
                    local is_duplicate=false
                    for existing_proxy in "${proxies[@]}"; do
                        if [[ "$existing_proxy" == "$proxy_line" ]]; then
                            is_duplicate=true
                            break
                        fi
                    done
                    
                    if [[ "$is_duplicate" == false ]]; then
                        proxies+=("$proxy_line")
                        ((valid_count++))
                        print_color $GREEN "  ✓ Valid: $proxy_line"
                    fi
                else
                    ((invalid_count++))
                fi
            else
                ((invalid_count++))
            fi
        else
            ((invalid_count++))
        fi
        
    done <<< "$proxies_input"
    
    # Show summary instead of detailed errors
    if [[ $invalid_count -gt 0 ]]; then
        print_warning "Skipped $invalid_count invalid proxy entries"
    fi
    
    if [[ ${#proxies[@]} -eq 0 ]]; then
        print_error "No valid proxies provided!"
        if [[ $invalid_count -gt 0 ]]; then
            echo -e "${GRAY}Check proxy format: IP:PORT:USERNAME:PASSWORD${NC}"
        fi
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    print_color $CYAN "Testing ${#proxies[@]} proxies..."
    echo
    
    local success_count=0
    local total_count=${#proxies[@]}
    
    # Simple progress display without complex borders
    echo -e "${CYAN}Proxy Test Results:${NC}"
    echo "───────────────────────────────────────────────────────────────────────────────"
    
    for i in "${!proxies[@]}"; do
        local proxy="${proxies[i]}"
        
        # Parse proxy components
        IFS=':' read -r ip port user pass <<< "$proxy"
        
        local curl_proxy="socks5://$user:$pass@$ip:$port"
        
        # Test with timeout
        local display_proxy="${ip}:${port}@${user}"
        if [[ ${#display_proxy} -gt 35 ]]; then
            display_proxy="${display_proxy:0:32}..."
        fi
        
        printf "[%2d/%2d] %-35s " $((i+1)) $total_count "$display_proxy"
        
        if timeout 10 curl -s --proxy "$curl_proxy" --connect-timeout 5 -I http://httpbin.org/ip >/dev/null 2>&1; then
            printf "${GREEN}✓ SUCCESS${NC}\n"
            ((success_count++))
        else
            printf "${RED}✗ FAILED${NC}\n"
        fi
    done
    
    echo "───────────────────────────────────────────────────────────────────────────────"
    
    local success_rate=0
    if [[ $total_count -gt 0 ]]; then
        success_rate=$((success_count * 100 / total_count))
    fi
    
    echo
    echo -e "${CYAN}Test Summary:${NC}"
    echo -e "  Total Proxies:   ${WHITE}$total_count${NC}"
    echo -e "  Successful:      ${GREEN}$success_count${NC}"
    echo -e "  Failed:          ${RED}$((total_count - success_count))${NC}"
    echo -e "  Success Rate:    ${YELLOW}${success_rate}%${NC}"
    
    echo
    read -p "Press Enter to continue..."
}

# Function to uninstall Danted
uninstall_danted() {
    print_header
    print_section_header "Uninstall Danted"
    
    echo -e "${RED}╭─ WARNING ────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${RED}${NC} This will completely remove Danted and all configurations!                 ${RED}${NC}"
    echo -e "${RED}${NC} All proxy users and config files will be affected.                         ${RED}${NC}"    
    echo -e "${RED}╰──────────────────────────────────────────────────────────────────────────────╯${NC}"
    
    echo
    read -p "$(echo -e "${RED}❯${NC} Are you sure you want to uninstall Danted? (y/N): ")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    print_color $YELLOW "Uninstalling Danted..."
    
    # Stop and disable service
    echo -e "${GRAY}Stopping service...${NC}"
    systemctl stop $DANTED_SERVICE 2>/dev/null
    systemctl disable $DANTED_SERVICE 2>/dev/null
    
    # Remove package
    echo -e "${GRAY}Removing package...${NC}"
    apt remove --purge -y dante-server >/dev/null 2>&1
    
    # Remove configuration files
    echo -e "${GRAY}Removing configuration files...${NC}"
    rm -f "$DANTED_CONFIG"
    rm -f /var/log/danted.log
    
    # Ask about user configs
    if [[ -d "$CONFIG_DIR" ]] && [[ $(ls -A "$CONFIG_DIR" 2>/dev/null) ]]; then
        echo
        read -p "$(echo -e "${YELLOW}❯${NC} Do you want to remove all user config files in '$CONFIG_DIR'? (y/N): ")" remove_configs
        if [[ "$remove_configs" =~ ^[Yy]$ ]]; then
            rm -rf "$CONFIG_DIR"
            print_success "User config files removed"
        fi
    fi
    
    # Ask about users
    local socks_users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            socks_users+=("$user")
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1)
    
    if [[ ${#socks_users[@]} -gt 0 ]]; then
        echo
        print_warning "Found ${#socks_users[@]} SOCKS5 users:"
        for user in "${socks_users[@]}"; do
            echo -e "  ${YELLOW}•${NC} $user"
        done
        echo
        read -p "$(echo -e "${YELLOW}❯${NC} Do you want to remove all SOCKS5 users? (y/N): ")" remove_users
        if [[ "$remove_users" =~ ^[Yy]$ ]]; then
            for user in "${socks_users[@]}"; do
                userdel "$user" 2>/dev/null
                print_success "Removed user: $user"
            done
        fi
    fi
    
    echo
    print_success "Danted has been completely uninstalled!"
    
    echo
    read -p "Press Enter to continue..."
}

# Main menu function
show_main_menu() {
    print_header
    print_section_header "Main Menu"
    
    echo -e "${CYAN}1.${NC} Install Danted SOCKS5 Proxy"
    echo -e "${CYAN}2.${NC} Show Users"
    echo -e "${CYAN}3.${NC} Add Users"
    echo -e "${CYAN}4.${NC} Delete Users"
    echo -e "${CYAN}5.${NC} Test Proxies"
    echo -e "${CYAN}6.${NC} Check Status & Monitoring"
    echo -e "${CYAN}7.${NC} Uninstall Danted"
    echo -e "${CYAN}8.${NC} Exit"
    echo
}

# Main program loop
main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root!"
        print_warning "Please run: sudo $0"
        exit 1
    fi
    
    # Check for required commands
    local required_commands=("curl" "netstat" "systemctl" "useradd" "userdel")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "Required command '$cmd' not found!"
            print_warning "Please install the required packages."
            exit 1
        fi
    done
    
    while true; do
        show_main_menu
        read -p "$(echo -e "${YELLOW}❯${NC} Select option [1-8]: ")" choice
        
        case $choice in
            1) install_danted ;;
            2) show_users ;;
            3) manage_add_users ;;
            4) delete_users ;;
            5) test_proxies ;;
            6) check_service_status ;;
            7) uninstall_danted ;;
            8) 
                print_color $GREEN "Thank you for using Danted SOCKS5 Proxy Manager!"
                exit 0
                ;;
            *) 
                print_error "Invalid option! Please select 1-8."
                sleep 1
                ;;
        esac
    done
}

# Run main function
main "$@".66.66",
          "117.50.22.22",
          "2400:7fc0:849e:200::4",
          "2404:c2c0:85d8:901::4",
          "117.50.10.10",
          "52.80.52.52",
          "2400:7fc0:849e:200::8",
          "2404:c2c0:85d8:901::8",
          "117.50.60.30",
          "52.80