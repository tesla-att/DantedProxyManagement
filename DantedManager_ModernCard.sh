#!/bin/bash

# Danted SOCKS5 Proxy Manager v2.0 - Modern Card Style
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
    echo -e "${CYAN}┌─ 🚀 DANTED SOCKS5 PROXY MANAGER v2.0 ─────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}${BOLD}Professional SOCKS5 Proxy Management Tool${NC}"
    echo -e "${CYAN}│${NC}  ${GRAY}Modern Card Interface - Optimized Performance${NC}"
    echo -e "${CYAN}│${NC}"
    echo -e "${CYAN}└───────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

# Function to print section header
print_section_header() {
    local title=$1
    echo -e "${BLUE}┌─ 📋 ${title} ──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}"
}

# Function to close section
close_section() {
    echo -e "${BLUE}│${NC}"
    echo -e "${BLUE}└───────────────────────────────────────────────────────────────────────────────┘${NC}"
}

# Function to print card content line
print_card_line() {
    local icon="$1"
    local label="$2"
    local value="$3"
    local color="${4:-$WHITE}"
    
    printf "${BLUE}│${NC}  ${icon} ${WHITE}${label}:${NC} ${color}%s${NC}\n" "$value"
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

# Function to print info message
print_info() {
    local message=$1
    echo -e "${CYAN}ℹ${NC} ${CYAN}$message${NC}"
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
    
    # Header
    print_card_line "🌐" "Available Interfaces" "Select your network interface"
    echo -e "${BLUE}│${NC}"
    
    # Loop through network interfaces and IPs
    while IFS= read -r line; do
        interface=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | awk '{print $2}')
        if [[ "$interface" != "lo" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            interfaces+=("$interface")
            ips+=("$ip")
            
            printf "${BLUE}│${NC}  ${CYAN}%2d.${NC} ${WHITE}%-15s${NC} ${GREEN}%s${NC}\n" \
                $counter "$interface" "$ip"
            ((counter++))
        fi
    done < <(ip -4 addr show | grep -oP '^\d+: \K\w+|inet \K[^/]+' | paste - -)
    
    close_section
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
    
    echo -e "${CYAN}┌─ 📊 System Information ────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}"
    print_card_line "🔧" "CPU Usage" "${cpu_usage}%" "$GREEN"
    print_card_line "💾" "Memory" "${memory_used} / ${memory_total}" "$GREEN"
    print_card_line "💿" "Disk Usage" "$disk_usage" "$GREEN"
    print_card_line "⏱️" "Uptime" "$uptime_info" "$GREEN"
    close_section
}

# Function to check service status
check_service_status() {
    print_header
    print_section_header "Service Status & System Monitoring"
    
    # Determine service status
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        local status="RUNNING"
        local color=$GREEN
        local status_icon="🟢"
    else
        local status="STOPPED"
        local color=$RED
        local status_icon="🔴"
    fi
    
    print_card_line "$status_icon" "Service Status" "$status" "$color"
    
    # Auto-start status
    if systemctl is-enabled --quiet $DANTED_SERVICE 2>/dev/null; then
        print_card_line "🔄" "Auto-start" "ENABLED" "$GREEN"
    else
        print_card_line "🔄" "Auto-start" "DISABLED" "$RED"
    fi
    
    # Listen address
    if [[ -f "$DANTED_CONFIG" ]]; then
        local config_ip=$(grep "internal:" "$DANTED_CONFIG" | awk '{print $2}' 2>/dev/null || echo "N/A")
        local config_port=$(grep "internal:" "$DANTED_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ' 2>/dev/null || echo "N/A")
        local listen_address="${config_ip}:${config_port}"
        print_card_line "🌐" "Listen Address" "$listen_address" "$YELLOW"
    else
        print_card_line "🌐" "Listen Address" "Not configured" "$GRAY"
    fi
    
    # Active connections
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null && [[ -f "$DANTED_CONFIG" ]]; then
        local config_port=$(grep "internal:" "$DANTED_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ' 2>/dev/null)
        local connections=$(netstat -tn 2>/dev/null | grep ":$config_port " | wc -l 2>/dev/null || echo "0")
        print_card_line "🔗" "Active Connections" "$connections" "$BLUE"
    else
        print_card_line "🔗" "Active Connections" "N/A" "$GRAY"
    fi
    
    close_section
    echo
    
    # System information
    get_system_info
    echo
    
    # Recent logs
    echo -e "${CYAN}┌─ 📝 Recent Service Logs ───────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}"
    
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        if journalctl -u $DANTED_SERVICE --no-pager -n 3 --since "1 hour ago" 2>/dev/null | grep -q "."; then
            journalctl -u $DANTED_SERVICE --no-pager -n 3 --since "1 hour ago" 2>/dev/null | while read -r line; do
                # Truncate long log lines to fit in card
                if [[ ${#line} -gt 73 ]]; then
                    line="${line:0:70}..."
                fi
                echo -e "${CYAN}│${NC}  ${GRAY}$line${NC}"
            done
        else
            echo -e "${CYAN}│${NC}  ${GRAY}No recent logs found${NC}"
        fi
    else
        echo -e "${CYAN}│${NC}  ${YELLOW}Service not running - No logs available${NC}"
    fi
    
    close_section
    echo
    
    # Control options
    echo -e "${YELLOW}┌─ ⚙️ Control Options ────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│${NC}"
    echo -e "${YELLOW}│${NC}  ${CYAN}1.${NC} 🔄 Restart Service"
    echo -e "${YELLOW}│${NC}  ${CYAN}2.${NC} ⏹️ Stop Service"           
    echo -e "${YELLOW}│${NC}  ${CYAN}3.${NC} 📖 View Full Logs"
    echo -e "${YELLOW}│${NC}  ${CYAN}4.${NC} 🌐 Test Internet Bandwidth"
    echo -e "${YELLOW}│${NC}  ${CYAN}0.${NC} ⬅️ Back to Main Menu"
    close_section
    echo
    
    while true; do
        read -p "$(echo -e "${YELLOW}❯${NC} Select option [1-4]: ")" choice
        
        case $choice in
            1)
                print_color $YELLOW "🔄 Restarting Danted service..."
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
                print_color $YELLOW "⏹️ Stopping Danted service..."
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
                print_section_header "Full Service Logs"
                journalctl -u $DANTED_SERVICE --no-pager -n 50
                echo
                read -p "Press Enter to continue..."
                check_service_status
                return
                ;;
            4)
                test_bandwidth
                check_service_status
                return
                ;;
            0)
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
    
    print_card_line "🌐" "Status" "Testing download speed..." "$YELLOW"
    close_section
    echo
    
    # Test with curl
    local test_file="http://speedtest.ftp.otenet.gr/files/test1Mb.db"
    local start_time=$(date +%s.%N)
    
    if curl -s -w "%{speed_download}" -o /dev/null "$test_file" 2>/dev/null | grep -q "[0-9]"; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1")
        local speed=$(curl -s -w "%{speed_download}" -o /dev/null "$test_file" 2>/dev/null)
        local speed_mbps=$(echo "scale=2; $speed / 1024 / 1024 * 8" | bc 2>/dev/null || echo "0")
        
        echo -e "${CYAN}┌─ 📈 Bandwidth Test Results ─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC}"
        print_card_line "🚀" "Download Speed" "${speed_mbps} Mbps" "$GREEN"
        print_card_line "⏱️" "Test Duration" "${duration}s" "$BLUE"
        close_section
        print_success "Bandwidth test completed successfully!"
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
        print_card_line "⚠️" "Warning" "Danted is already installed and running" "$YELLOW"
        echo -e "${BLUE}│${NC}  ${YELLOW}You can reinstall it, but this will stop the current service.${NC}"
        close_section
        echo
        read -p "$(echo -e "${YELLOW}❯${NC} Do you want to reinstall? (y/N): ")" reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return
        fi
        systemctl stop $DANTED_SERVICE 2>/dev/null
        print_info "🔄 Stopping existing Danted service..."
    else
        print_card_line "📦" "Installation" "Ready to install Danted SOCKS5 Proxy" "$GREEN"
        close_section
    fi
    
    echo
    
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
    echo -e "${CYAN}┌─ 📦 Installation Progress ──────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}"
    
    # Update package list
    echo -e "${CYAN}│${NC}  ${GRAY}🔄 Updating package list...${NC}"
    apt update -qq
    
    # Install Danted
    echo -e "${CYAN}│${NC}  ${GRAY}📥 Installing dante-server...${NC}"
    if ! apt install -y dante-server >/dev/null 2>&1; then
        echo -e "${CYAN}│${NC}  ${RED}✗ Failed to install Danted!${NC}"
        close_section
        read -p "Press Enter to continue..."
        return
    fi
    
    # Create Danted configuration
    echo -e "${CYAN}│${NC}  ${GRAY}⚙️ Creating configuration...${NC}"
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
    echo -e "${CYAN}│${NC}  ${GRAY}🚀 Starting service...${NC}"
    systemctl enable $DANTED_SERVICE >/dev/null 2>&1
    systemctl restart $DANTED_SERVICE
    
    close_section
    
    # Check status
    sleep 2
    echo
    if systemctl is-active --quiet $DANTED_SERVICE; then
        echo -e "${GREEN}┌─ ✅ Installation Complete ──────────────────────────────────────────────────────┐${NC}"
        echo -e "${GREEN}│${NC}"
        print_card_line "✅" "Status" "Danted installed successfully!" "$GREEN"
        print_card_line "🌐" "Listen Address" "$SELECTED_IP:$SELECTED_PORT" "$CYAN"
        print_card_line "🔄" "Service Status" "Active and Running" "$GREEN"
        close_section
    else
        echo -e "${RED}┌─ ❌ Installation Failed ─────────────────────────────────────────────────────────┐${NC}"
        echo -e "${RED}│${NC}"
        print_card_line "❌" "Error" "Failed to start Danted service!" "$RED"
        print_card_line "📋" "Logs" "Checking service logs..." "$YELLOW"
        close_section
        echo
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
    
    # Collect users
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            users+=("$user")
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1 | sort)
    
    print_card_line "👥" "Total Users" "${#users[@]}" "$YELLOW"
    echo -e "${BLUE}│${NC}"
    
    if [[ ${#users[@]} -eq 0 ]]; then
        print_card_line "❌" "Status" "No SOCKS5 users found" "$RED"
    else
        for i in "${!users[@]}"; do
            printf "${BLUE}│${NC}  ${GREEN}✓${NC} ${WHITE}%2d.${NC} ${CYAN}%s${NC}\n" $((i+1)) "${users[i]}"
        done
    fi
    
    close_section
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
    
    # Create config content (same as original)
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
    
    print_card_line "👤" "Action" "Creating new SOCKS5 user" "$CYAN"
    close_section
    echo
    
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
    echo -e "${CYAN}┌─ 🔄 Creating User ───────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}"
    
    # Create user
    if useradd -r -s /bin/false "$username"; then
        echo "$username:$password" | chpasswd
        create_user_config "$username" "$password"
        print_card_line "✅" "Status" "User '$username' created successfully!" "$GREEN"
        print_card_line "📁" "Config" "File created: $CONFIG_DIR/$username" "$BLUE"
    else
        print_card_line "❌" "Error" "Failed to create user '$username'!" "$RED"
    fi
    
    close_section
    echo
    read -p "Press Enter to continue..."
}

# Function to add multiple users
add_multi_users() {
    print_header
    print_section_header "Add Multiple Users"

    print_card_line "👥" "Action" "Creating multiple SOCKS5 users" "$CYAN"
    close_section
    echo

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
                if id "$username" &>/dev/null; then
                    print_error "User '$username' already exists! Skipping..."
                else
                    usernames+=("$username")
                fi
            fi
        fi
    done <<< "$usernames_input"
    
    if [[ ${#usernames[@]} -eq 0 ]]; then
        print_error "No valid usernames provided!"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    echo -e "${CYAN}┌─ 🔄 Creating Users ──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}"
    print_card_line "📋" "Total Users" "${#usernames[@]} users to create" "$YELLOW"
    close_section
    echo
    
    # Create users and set passwords
    local created_users=()
    for username in "${usernames[@]}"; do
        echo -e "${CYAN}┌─ 👤 Setting up: ${WHITE}$username${NC} ${CYAN}──────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC}"
        
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
                                print_card_line "✅" "Status" "User '$username' created successfully!" "$GREEN"
                            else
                                print_card_line "⚠️" "Warning" "User '$username' created but config file failed!" "$YELLOW"
                                created_users+=("$username")
                            fi
                        else
                            print_card_line "❌" "Error" "Failed to set password for user '$username'!" "$RED"
                            userdel "$username" 2>/dev/null
                        fi
                    else
                        print_card_line "❌" "Error" "Failed to create user '$username'!" "$RED"
                    fi
                    break
                else
                    print_error "Passwords don't match for '$username'!"
                fi
            else
                print_error "Password for '$username' must be at least 4 characters long!"
            fi
        done
        close_section
        echo
    done
    
    echo -e "${GREEN}┌─ ✅ Summary ─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│${NC}"
    print_card_line "✅" "Created Users" "${#created_users[@]} users" "$GREEN"
    print_card_line "📁" "Config Directory" "$CONFIG_DIR/" "$BLUE"
    close_section
    
    echo
    read -p "Press Enter to continue..."
}

# Function to manage user addition
manage_add_users() {
    while true; do
        print_header
        print_section_header "Add Users Menu"
        
        print_card_line "👥" "User Management" "Choose how to add users" "$CYAN"
        echo -e "${BLUE}│${NC}"
        echo -e "${BLUE}│${NC}  ${CYAN}1.${NC} 👤 Add single user"
        echo -e "${BLUE}│${NC}  ${CYAN}2.${NC} 👥 Add multiple users"
        echo -e "${BLUE}│${NC}  ${CYAN}0.${NC} ⬅️ Back to main menu"
        close_section
        echo
        
        read -p "$(echo -e "${YELLOW}❯${NC} Select option [1-2]: ")" choice
        
        case $choice in
            1) add_single_user ;;
            2) add_multi_users ;;
            0) break ;;
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
        print_card_line "❌" "Status" "No SOCKS5 users found to delete" "$RED"
        close_section
        echo
        read -p "Press Enter to continue..."
        return
    fi
    
    print_card_line "🗑️" "Available Users" "${#users[@]} users available for deletion" "$YELLOW"
    echo -e "${BLUE}│${NC}"
    
    for i in "${!users[@]}"; do
        printf "${BLUE}│${NC}  ${RED}%2d.${NC} ${WHITE}%s${NC}\n" $((i+1)) "${users[i]}"
    done
    
    close_section
    echo
    
    echo -e "${YELLOW}┌─ ℹ️ Instructions ──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│${NC}"
    print_card_line "📝" "Format" "Enter user numbers separated by spaces" "$CYAN"
    print_card_line "💡" "Example" "1 3 5 (to delete users 1, 3, and 5)" "$GRAY"
    close_section
    echo
    
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
    echo -e "${RED}┌─ ⚠️ Confirmation ──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${RED}│${NC}"
    print_card_line "🗑️" "Action" "Users to be deleted:" "$RED"
    for user in "${to_delete[@]}"; do
        echo -e "${RED}│${NC}  ${RED}•${NC} $user"
    done
    close_section
    
    echo
    read -p "$(echo -e "${RED}❯${NC} Are you sure you want to delete these users? (y/N): ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    echo -e "${CYAN}┌─ 🔄 Deleting Users ──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}"
    
    # Delete users
    local deleted_count=0
    for user in "${to_delete[@]}"; do
        if userdel "$user" 2>/dev/null; then
            # Remove config file
            rm -f "$CONFIG_DIR/$user"
            print_card_line "✅" "Deleted" "$user" "$GREEN"
            ((deleted_count++))
        else
            print_card_line "❌" "Failed" "$user" "$RED"
        fi
    done
    
    close_section
    
    echo
    echo -e "${GREEN}┌─ ✅ Summary ─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│${NC}"
    print_card_line "✅" "Successfully Deleted" "$deleted_count users" "$GREEN"
    close_section
    
    echo
    read -p "Press Enter to continue..."
}

# Function to test proxies
test_proxies() {
    print_header
    print_section_header "Test Proxies"
    
    print_card_line "🧪" "Proxy Testing" "Test your SOCKS5 proxy connections" "$CYAN"
    echo -e "${BLUE}│${NC}"
    print_card_line "📝" "Format" "IP:PORT:USERNAME:PASSWORD" "$YELLOW"
    print_card_line "💡" "Example" "192.168.1.100:1080:alice:secret456" "$GRAY"
    close_section
    
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
    echo -e "${CYAN}┌─ 🧪 Testing ${#proxies[@]} proxies ──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}"
    
    local success_count=0
    local total_count=${#proxies[@]}
    
    for i in "${!proxies[@]}"; do
        local proxy="${proxies[i]}"
        
        # Parse proxy components
        IFS=':' read -r ip port user pass <<< "$proxy"
        
        local curl_proxy="socks5://$user:$pass@$ip:$port"
        
        # Test with timeout
        local display_proxy="${ip}:${port}@${user}"
        if [[ ${#display_proxy} -gt 30 ]]; then
            display_proxy="${display_proxy:0:27}..."
        fi
        
        # Create progress indicator
        local progress_indicator=$(printf "[%2d/%2d]" $((i+1)) $total_count)
        
        # Test proxy first
        if timeout 10 curl -s --proxy "$curl_proxy" --connect-timeout 5 -I http://httpbin.org/ip >/dev/null 2>&1; then
            print_card_line "✅" "$progress_indicator $display_proxy" "SUCCESS" "$GREEN"
            ((success_count++))
        else
            print_card_line "❌" "$progress_indicator $display_proxy" "FAILED" "$RED"
        fi
    done

    close_section
    
    local success_rate=0
    if [[ $total_count -gt 0 ]]; then
        success_rate=$((success_count * 100 / total_count))
    fi
    
    echo
    echo -e "${CYAN}┌─ 📊 Test Summary ────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}"
    print_card_line "📋" "Total Proxies" "$total_count" "$WHITE"
    print_card_line "✅" "Successful" "$success_count" "$GREEN"
    print_card_line "❌" "Failed" "$((total_count - success_count))" "$RED"
    print_card_line "📈" "Success Rate" "${success_rate}%" "$YELLOW"
    close_section
    
    echo
    read -p "Press Enter to continue..."
}

# Function to uninstall Danted
uninstall_danted() {
    print_header
    print_section_header "Uninstall Danted"
    
    echo -e "${RED}┌─ ⚠️ WARNING ─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${RED}│${NC}"
    print_card_line "⚠️" "Warning" "This will completely remove Danted!" "$RED"
    print_card_line "🗑️" "Impact" "All configurations will be deleted!" "$RED"
    print_card_line "👥" "Users" "All proxy users will be affected!" "$RED"
    close_section
    
    echo
    read -p "$(echo -e "${RED}❯${NC} Are you sure you want to uninstall Danted? (y/N): ")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    echo -e "${CYAN}┌─ 🔄 Uninstalling Danted ─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}"
    
    # Stop and disable service
    echo -e "${CYAN}│${NC}  ${GRAY}⏹️ Stopping service...${NC}"
    systemctl stop $DANTED_SERVICE 2>/dev/null
    systemctl disable $DANTED_SERVICE 2>/dev/null
    
    # Remove package
    echo -e "${CYAN}│${NC}  ${GRAY}📦 Removing package...${NC}"
    apt remove --purge -y dante-server >/dev/null 2>&1
    
    # Remove configuration files
    echo -e "${CYAN}│${NC}  ${GRAY}🗑️ Removing configuration files...${NC}"
    rm -f "$DANTED_CONFIG"
    rm -f /var/log/danted.log
    
    close_section
    
    # Ask about user configs
    if [[ -d "$CONFIG_DIR" ]] && [[ $(ls -A "$CONFIG_DIR" 2>/dev/null) ]]; then
        echo
        read -p "$(echo -e "${YELLOW}❯${NC} Do you want to remove all user config files in '$CONFIG_DIR'? (y/N): ")" remove_configs
        if [[ "$remove_configs" =~ ^[Yy]$ ]]; then
            rm -rf "$CONFIG_DIR"
            print_success "✅ User config files removed"
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
        echo -e "${YELLOW}┌─ 👥 Found SOCKS5 Users ──────────────────────────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}│${NC}"
        print_card_line "👥" "Total Found" "${#socks_users[@]} users" "$YELLOW"
        for user in "${socks_users[@]}"; do
            echo -e "${YELLOW}│${NC}  ${YELLOW}•${NC} $user"
        done
        close_section
        echo
        read -p "$(echo -e "${YELLOW}❯${NC} Do you want to remove all SOCKS5 users? (y/N): ")" remove_users
        if [[ "$remove_users" =~ ^[Yy]$ ]]; then
            echo
            echo -e "${CYAN}┌─ 🗑️ Removing Users ──────────────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}│${NC}"
            for user in "${socks_users[@]}"; do
                if userdel "$user" 2>/dev/null; then
                    print_card_line "✅" "Removed" "$user" "$GREEN"
                else
                    print_card_line "❌" "Failed" "$user" "$RED"
                fi
            done
            close_section
        fi
    fi
    
    echo
    echo -e "${GREEN}┌─ ✅ Uninstallation Complete ────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│${NC}"
    print_card_line "✅" "Status" "Danted has been completely uninstalled!" "$GREEN"
    print_card_line "🧹" "Cleanup" "System cleaned up successfully!" "$GREEN"
    close_section
    
    echo
    read -p "Press Enter to continue..."
}

# Main menu function
show_main_menu() {
    print_header
    print_section_header "Main Menu"
    
    print_card_line "🚀" "Proxy Manager" "Choose an action below" "$CYAN"
    echo -e "${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${CYAN}1.${NC} 📦 Install Danted SOCKS5 Proxy"
    echo -e "${BLUE}│${NC}  ${CYAN}2.${NC} 👥 Show Users"
    echo -e "${BLUE}│${NC}  ${CYAN}3.${NC} ➕ Add Users"
    echo -e "${BLUE}│${NC}  ${CYAN}4.${NC} 🗑️ Delete Users"
    echo -e "${BLUE}│${NC}  ${CYAN}5.${NC} 🧪 Test Proxies"
    echo -e "${BLUE}│${NC}  ${CYAN}6.${NC} 📊 Check Status & Monitoring"
    echo -e "${BLUE}│${NC}  ${CYAN}7.${NC} 🗑️ Uninstall Danted"
    echo -e "${BLUE}│${NC}  ${CYAN}0.${NC} 🚪 Exit"
    close_section
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
        read -p "$(echo -e "${YELLOW}❯${NC} Select option [0-7]: ")" choice
        
        case $choice in
            1) install_danted ;;
            2) show_users ;;
            3) manage_add_users ;;
            4) delete_users ;;
            5) test_proxies ;;
            6) check_service_status ;;
            7) uninstall_danted ;;
            0) 
                # Clear screen and show thank you message
                clear
                echo -e "${GREEN}┌─ 👋 Thank You ────────────────────────────────────────────────────────────────────┐${NC}"
                echo -e "${GREEN}│${NC}"
                print_card_line "🙏" "Thanks" "Thank you for using Danted SOCKS5 Proxy Manager!" "$GREEN"
                print_card_line "✨" "Version" "Modern Card Style v2.0" "$CYAN"
                close_section
                echo
                exit 0
                ;;
            *) 
                print_error "Invalid option! Please select 0-7."
                sleep 1
                ;;
        esac
    done
}

# Run main function
main "$@"