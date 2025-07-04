#!/bin/bash

# Danted SOCKS5 Proxy Manager v3.0 - Gradient Progress Style
# Professional script for managing SOCKS5 proxy server on Ubuntu

# Enhanced Colors for gradient effects
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

# Gradient colors
LIGHT_BLUE='\033[1;34m'
LIGHT_CYAN='\033[1;36m'
LIGHT_GREEN='\033[1;32m'
LIGHT_YELLOW='\033[1;33m'
LIGHT_RED='\033[1;31m'
LIGHT_PURPLE='\033[1;35m'

# Block characters for gradient effects
FULL_BLOCK='█'
LIGHT_BLOCK='▓'
MEDIUM_BLOCK='▒'
DARK_BLOCK='░'

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

# Function to create gradient line
create_gradient_line() {
    local width="${1:-78}"
    local style="${2:-1}"  # 1=blue, 2=green, 3=rainbow
    
    case $style in
        1) # Blue gradient
            printf "${CYAN}${FULL_BLOCK}${LIGHT_CYAN}${FULL_BLOCK}${BLUE}${LIGHT_BLOCK}${CYAN}${MEDIUM_BLOCK}"
            for ((i=5; i<=width-5; i++)); do printf "${BLUE}${DARK_BLOCK}"; done
            printf "${CYAN}${MEDIUM_BLOCK}${BLUE}${LIGHT_BLOCK}${LIGHT_CYAN}${FULL_BLOCK}${CYAN}${FULL_BLOCK}${NC}\n"
            ;;
        2) # Green gradient
            printf "${GREEN}${FULL_BLOCK}${LIGHT_GREEN}${FULL_BLOCK}${GREEN}${LIGHT_BLOCK}${GREEN}${MEDIUM_BLOCK}"
            for ((i=5; i<=width-5; i++)); do printf "${GREEN}${DARK_BLOCK}"; done
            printf "${GREEN}${MEDIUM_BLOCK}${GREEN}${LIGHT_BLOCK}${LIGHT_GREEN}${FULL_BLOCK}${GREEN}${FULL_BLOCK}${NC}\n"
            ;;
        3) # Rainbow gradient
            local colors=(${RED} ${YELLOW} ${GREEN} ${CYAN} ${BLUE} ${PURPLE})
            for ((i=0; i<width; i++)); do
                local color_index=$((i % 6))
                printf "${colors[$color_index]}${FULL_BLOCK}"
            done
            printf "${NC}\n"
            ;;
    esac
}

# Function to create progress bar
create_progress_bar() {
    local current=$1
    local total=$2
    local width="${3:-50}"
    local label="${4:-Progress}"
    local show_percentage="${5:-true}"
    
    local percentage=0
    if [[ $total -gt 0 ]]; then
        percentage=$((current * 100 / total))
    fi
    
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    # Ensure we don't exceed bounds
    if [[ $filled -gt $width ]]; then filled=$width; fi
    if [[ $empty -lt 0 ]]; then empty=0; fi
    
    printf "${CYAN}%s: ${WHITE}[" "$label"
    
    # Filled portion with gradient
    for ((i=0; i<filled; i++)); do
        if [[ $i -lt $((filled/3)) ]]; then
            printf "${GREEN}${FULL_BLOCK}"
        elif [[ $i -lt $((filled*2/3)) ]]; then
            printf "${YELLOW}${FULL_BLOCK}"
        else
            printf "${RED}${FULL_BLOCK}"
        fi
    done
    
    # Empty portion
    for ((i=0; i<empty; i++)); do
        printf "${GRAY}${DARK_BLOCK}"
    done
    
    if [[ "$show_percentage" == "true" ]]; then
        printf "${WHITE}] ${YELLOW}%d%%${NC} ${GRAY}(%d/%d)${NC}\n" $percentage $current $total
    else
        printf "${WHITE}]${NC}\n"
    fi
}

# Function to print fancy header with gradient
print_header() {
    clear
    create_gradient_line 78 3
    echo -e "${CYAN}${LIGHT_BLOCK}${WHITE}${BOLD}                    DANTED SOCKS5 PROXY MANAGER v3.0                     ${NC}${CYAN}${LIGHT_BLOCK}${NC}"
    echo -e "${BLUE}${MEDIUM_BLOCK}${WHITE}                        Gradient Progress Style                          ${NC}${BLUE}${MEDIUM_BLOCK}${NC}"
    create_gradient_line 78 3
    echo
}

# Function to print section header with gradient
print_section_header() {
    local title=$1
    echo -e "${CYAN}${LIGHT_BLOCK}${BLUE}${MEDIUM_BLOCK}${CYAN}${DARK_BLOCK} ${WHITE}${BOLD}$title${NC} ${CYAN}${DARK_BLOCK}${BLUE}${MEDIUM_BLOCK}${CYAN}${LIGHT_BLOCK}${NC}"
    create_gradient_line 78 1
    echo
}

# Function to print progress section header
print_progress_header() {
    local title=$1
    local current=${2:-0}
    local total=${3:-1}
    
    echo -e "${PURPLE}${FULL_BLOCK}${LIGHT_PURPLE}${LIGHT_BLOCK}${PURPLE}${MEDIUM_BLOCK} ${WHITE}${BOLD}$title${NC} ${PURPLE}${MEDIUM_BLOCK}${LIGHT_PURPLE}${LIGHT_BLOCK}${PURPLE}${FULL_BLOCK}${NC}"
    if [[ $total -gt 1 ]]; then
        create_progress_bar $current $total 60 "Progress"
    fi
    echo
}

# Function to print success message with gradient
print_success() {
    local message=$1
    echo -e "${GREEN}${FULL_BLOCK}${LIGHT_GREEN}${LIGHT_BLOCK}${GREEN}${MEDIUM_BLOCK}${NC} ${GREEN}$message${NC}"
}

# Function to print error message with gradient
print_error() {
    local message=$1
    echo -e "${RED}${FULL_BLOCK}${LIGHT_RED}${LIGHT_BLOCK}${RED}${MEDIUM_BLOCK}${NC} ${RED}$message${NC}"
}

# Function to print warning message with gradient
print_warning() {
    local message=$1
    echo -e "${YELLOW}${FULL_BLOCK}${LIGHT_YELLOW}${LIGHT_BLOCK}${YELLOW}${MEDIUM_BLOCK}${NC} ${YELLOW}$message${NC}"
}

# Function to print info message with gradient
print_info() {
    local message=$1
    echo -e "${BLUE}${FULL_BLOCK}${LIGHT_BLUE}${LIGHT_BLOCK}${BLUE}${MEDIUM_BLOCK}${NC} ${CYAN}$message${NC}"
}

# Function to create gradient box
create_gradient_box() {
    local title="$1"
    local width="${2:-78}"
    local style="${3:-1}"
    local -n content_ref=$4
    
    # Top border with gradient
    case $style in
        1) # Blue gradient box
            printf "${CYAN}${FULL_BLOCK}${LIGHT_CYAN}${LIGHT_BLOCK}${BLUE}${MEDIUM_BLOCK} ${WHITE}${BOLD}%s${NC} " "$title"
            local title_len=$((${#title} + 6))
            for ((i=title_len; i<width; i++)); do printf "${BLUE}${MEDIUM_BLOCK}"; done
            printf "${LIGHT_CYAN}${LIGHT_BLOCK}${CYAN}${FULL_BLOCK}${NC}\n"
            ;;
        2) # Green gradient box
            printf "${GREEN}${FULL_BLOCK}${LIGHT_GREEN}${LIGHT_BLOCK}${GREEN}${MEDIUM_BLOCK} ${WHITE}${BOLD}%s${NC} " "$title"
            local title_len=$((${#title} + 6))
            for ((i=title_len; i<width; i++)); do printf "${GREEN}${MEDIUM_BLOCK}"; done
            printf "${LIGHT_GREEN}${LIGHT_BLOCK}${GREEN}${FULL_BLOCK}${NC}\n"
            ;;
        3) # Purple gradient box
            printf "${PURPLE}${FULL_BLOCK}${LIGHT_PURPLE}${LIGHT_BLOCK}${PURPLE}${MEDIUM_BLOCK} ${WHITE}${BOLD}%s${NC} " "$title"
            local title_len=$((${#title} + 6))
            for ((i=title_len; i<width; i++)); do printf "${PURPLE}${MEDIUM_BLOCK}"; done
            printf "${LIGHT_PURPLE}${LIGHT_BLOCK}${PURPLE}${FULL_BLOCK}${NC}\n"
            ;;
    esac
    
    # Content
    for line in "${content_ref[@]}"; do
        case $style in
            1) echo -e "${CYAN}${LIGHT_BLOCK}${NC} $line" ;;
            2) echo -e "${GREEN}${LIGHT_BLOCK}${NC} $line" ;;
            3) echo -e "${PURPLE}${LIGHT_BLOCK}${NC} $line" ;;
        esac
    done
    
    # Bottom border
    case $style in
        1) create_gradient_line $width 1 ;;
        2) create_gradient_line $width 2 ;;
        3) for ((i=0; i<width; i++)); do printf "${PURPLE}${MEDIUM_BLOCK}"; done; printf "${NC}\n" ;;
    esac
}

# Function to show animated progress
show_progress_animation() {
    local steps=$1
    local message="$2"
    
    for ((i=1; i<=steps; i++)); do
        printf "\r${CYAN}${message}${NC} "
        create_progress_bar $i $steps 30 "" false
        sleep 0.1
    done
    echo
}

# Function to read multiline input with paste support
read_multiline_input() {
    local prompt=$1
    local items=()
    local line_count=0
    
    print_info "$prompt"
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
                    # Print feedback with gradient
                    echo -e "  ${GREEN}${FULL_BLOCK}${NC} [$line_count] $line" >&2
                else
                    echo -e "  ${YELLOW}${MEDIUM_BLOCK}${NC} Duplicate skipped: $line" >&2
                fi
            fi
        fi
    done
    
    # Return only the pure data - output to stdout
    for item in "${items[@]}"; do
        echo "$item"
    done
}

# Function to get network interfaces with gradient display
get_network_interfaces() {
    print_section_header "Network Interface Selection"
    
    local interfaces=()
    local ips=()
    local counter=1
    local content_lines=()
    
    # Collect interfaces first
    while IFS= read -r line; do
        interface=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | awk '{print $2}')
        if [[ "$interface" != "lo" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            interfaces+=("$interface")
            ips+=("$ip")
            content_lines+=("${CYAN}$counter.${NC} ${WHITE}$interface${NC} ${GREEN}→${NC} ${YELLOW}$ip${NC}")
            ((counter++))
        fi
    done < <(ip -4 addr show | grep -oP '^\d+: \K\w+|inet \K[^/]+' | paste - -)
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        print_error "No network interfaces found!"
        return 1
    fi
    
    # Display in gradient box
    create_gradient_box "Available Network Interfaces" 78 1 content_lines
    echo
    
    while true; do
        read -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Select interface number: ")" choice
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

# Function to get system info with progress bars
get_system_info() {
    local content_lines=()
    
    # Get system metrics
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
    local memory_info=$(free -h | grep "Mem:" 2>/dev/null || echo "N/A N/A N/A")
    local memory_used=$(echo $memory_info | awk '{print $3}' 2>/dev/null || echo "N/A")
    local memory_total=$(echo $memory_info | awk '{print $2}' 2>/dev/null || echo "N/A")
    local disk_usage=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%' 2>/dev/null || echo "0")
    local uptime_info=$(uptime -p 2>/dev/null || echo "N/A")
    
    # CPU usage bar
    local cpu_num=${cpu_usage%.*}  # Remove decimal
    [[ -z "$cpu_num" || ! "$cpu_num" =~ ^[0-9]+$ ]] && cpu_num=0
    content_lines+=("${WHITE}CPU Usage:${NC}")
    content_lines+=("$(create_progress_bar $cpu_num 100 40 "" true)")
    
    # Memory info
    content_lines+=("${WHITE}Memory:${NC} ${GREEN}$memory_used${NC} / ${CYAN}$memory_total${NC}")
    
    # Disk usage bar
    local disk_num=${disk_usage%.*}  # Remove decimal
    [[ -z "$disk_num" || ! "$disk_num" =~ ^[0-9]+$ ]] && disk_num=0
    content_lines+=("${WHITE}Disk Usage:${NC}")
    content_lines+=("$(create_progress_bar $disk_num 100 40 "" true)")
    
    # Uptime
    if [[ ${#uptime_info} -gt 50 ]]; then
        uptime_info="${uptime_info:0:47}..."
    fi
    content_lines+=("${WHITE}Uptime:${NC} ${YELLOW}$uptime_info${NC}")
    
    create_gradient_box "System Information" 78 2 content_lines
}

# Function to check service status with gradient
check_service_status() {
    print_header
    print_section_header "Service Status & System Monitoring"
    
    local status_lines=()
    
    # Determine service status
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        local status="RUNNING"
        local status_color="${GREEN}"
        local status_icon="${GREEN}${FULL_BLOCK}${NC}"
    else
        local status="STOPPED"
        local status_color="${RED}"
        local status_icon="${RED}${FULL_BLOCK}${NC}"
    fi
    
    status_lines+=("${WHITE}Service Status:${NC} $status_icon ${status_color}$status${NC}")
    
    # Auto-start status
    if systemctl is-enabled --quiet $DANTED_SERVICE 2>/dev/null; then
        status_lines+=("${WHITE}Auto-start:${NC} ${GREEN}${FULL_BLOCK}${NC} ${GREEN}ENABLED${NC}")
    else
        status_lines+=("${WHITE}Auto-start:${NC} ${RED}${FULL_BLOCK}${NC} ${RED}DISABLED${NC}")
    fi
    
    # Listen address
    if [[ -f "$DANTED_CONFIG" ]]; then
        local config_ip=$(grep "internal:" "$DANTED_CONFIG" | awk '{print $2}' 2>/dev/null || echo "N/A")
        local config_port=$(grep "internal:" "$DANTED_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ' 2>/dev/null || echo "N/A")
        local listen_address="${config_ip}:${config_port}"
        status_lines+=("${WHITE}Listen Address:${NC} ${YELLOW}$listen_address${NC}")
    else
        status_lines+=("${WHITE}Listen Address:${NC} ${GRAY}Not configured${NC}")
    fi
    
    # Active connections
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null && [[ -f "$DANTED_CONFIG" ]]; then
        local config_port=$(grep "internal:" "$DANTED_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ' 2>/dev/null)
        local connections=$(netstat -tn 2>/dev/null | grep ":$config_port " | wc -l 2>/dev/null || echo "0")
        status_lines+=("${WHITE}Active Connections:${NC} ${BLUE}$connections${NC}")
    else
        status_lines+=("${WHITE}Active Connections:${NC} ${GRAY}N/A${NC}")
    fi
    
    create_gradient_box "Danted Service Status" 78 1 status_lines
    echo
    
    # System information
    get_system_info
    echo
    
    # Recent logs in gradient box
    local log_lines=()
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        if journalctl -u $DANTED_SERVICE --no-pager -n 3 --since "1 hour ago" 2>/dev/null | grep -q "."; then
            while IFS= read -r line; do
                if [[ ${#line} -gt 70 ]]; then
                    line="${line:0:67}..."
                fi
                log_lines+=("${GRAY}$line${NC}")
            done < <(journalctl -u $DANTED_SERVICE --no-pager -n 3 --since "1 hour ago" 2>/dev/null)
        else
            log_lines+=("${GRAY}No recent logs found${NC}")
        fi
    else
        log_lines+=("${YELLOW}Service not running - No logs available${NC}")
    fi
    
    create_gradient_box "Recent Service Logs" 78 3 log_lines
    echo
    
    # Control options
    local control_lines=(
        "${CYAN}1.${NC} ${YELLOW}${FULL_BLOCK}${NC} Restart Service"
        "${CYAN}2.${NC} ${RED}${FULL_BLOCK}${NC} Stop Service"
        "${CYAN}3.${NC} ${BLUE}${FULL_BLOCK}${NC} View Full Logs"
        "${CYAN}4.${NC} ${GREEN}${FULL_BLOCK}${NC} Test Internet Bandwidth"
        "${CYAN}0.${NC} ${PURPLE}${FULL_BLOCK}${NC} Back to Main Menu"
    )
    
    create_gradient_box "Control Options" 78 2 control_lines
    echo
    
    while true; do
        read -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Select option [0-4]: ")" choice
        
        case $choice in
            1)
                print_info "Restarting Danted service..."
                show_progress_animation 20 "Restarting"
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
                print_info "Stopping Danted service..."
                show_progress_animation 15 "Stopping"
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

# Function to test bandwidth with progress
test_bandwidth() {
    print_section_header "Internet Bandwidth Test"
    
    print_info "Preparing bandwidth test..."
    show_progress_animation 30 "Testing download speed"
    
    # Test with curl
    local test_file="http://speedtest.ftp.otenet.gr/files/test1Mb.db"
    local start_time=$(date +%s.%N)
    
    if curl -s -w "%{speed_download}" -o /dev/null "$test_file" 2>/dev/null | grep -q "[0-9]"; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1")
        local speed=$(curl -s -w "%{speed_download}" -o /dev/null "$test_file" 2>/dev/null)
        local speed_mbps=$(echo "scale=2; $speed / 1024 / 1024 * 8" | bc 2>/dev/null || echo "0")
        
        local result_lines=(
            "${WHITE}Download Speed:${NC} ${GREEN}${speed_mbps} Mbps${NC}"
            "${WHITE}Test Duration:${NC} ${BLUE}${duration}s${NC}"
            "${WHITE}Status:${NC} ${GREEN}${FULL_BLOCK} SUCCESS${NC}"
        )
        
        create_gradient_box "Bandwidth Test Results" 78 2 result_lines
        print_success "Bandwidth test completed successfully!"
    else
        print_error "Bandwidth test failed!"
        print_warning "Please check your internet connection."
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to install Danted with progress
install_danted() {
    print_header
    print_section_header "Install Danted SOCKS5 Proxy Server"    
    
    # Check if already installed
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        print_warning "Danted is already installed and running."
        echo -e "${YELLOW}You can reinstall it, but this will stop the current service.${NC}"
        read -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Do you want to reinstall? (y/N): ")" reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return
        fi
        systemctl stop $DANTED_SERVICE 2>/dev/null
        print_info "Stopping existing Danted service..."
    fi
    
    # Get network interface
    if ! get_network_interfaces; then
        read -p "Press Enter to continue..."
        return
    fi
    
    # Get port
    echo
    while true; do
        read -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Enter SOCKS5 port (default: 1080): ")" port
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
    print_progress_header "Installation Progress" 0 4
    
    # Update package list
    print_info "Updating package list..."
    show_progress_animation 20 "Updating"
    apt update -qq
    print_progress_header "Installation Progress" 1 4
    
    # Install Danted
    print_info "Installing dante-server..."
    show_progress_animation 25 "Installing"
    if ! apt install -y dante-server >/dev/null 2>&1; then
        print_error "Failed to install Danted!"
        read -p "Press Enter to continue..."
        return
    fi
    print_progress_header "Installation Progress" 2 4
    
    # Create Danted configuration
    print_info "Creating configuration..."
    show_progress_animation 15 "Configuring"
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
    print_progress_header "Installation Progress" 3 4
    
    # Enable and start service
    print_info "Starting service..."
    show_progress_animation 20 "Starting"
    systemctl enable $DANTED_SERVICE >/dev/null 2>&1
    systemctl restart $DANTED_SERVICE
    print_progress_header "Installation Progress" 4 4
    
    # Check status
    sleep 2
    echo
    if systemctl is-active --quiet $DANTED_SERVICE; then
        local success_lines=(
            "${WHITE}Status:${NC} ${GREEN}${FULL_BLOCK} Danted installed successfully!${NC}"
            "${WHITE}Listen Address:${NC} ${YELLOW}$SELECTED_IP:$SELECTED_PORT${NC}"
            "${WHITE}Service Status:${NC} ${GREEN}${FULL_BLOCK} Active and Running${NC}"
        )
        create_gradient_box "Installation Complete" 78 2 success_lines
    else
        print_error "Failed to start Danted service!"
        print_warning "Checking logs..."
        journalctl -u $DANTED_SERVICE --no-pager -n 10
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to show users with gradient
show_users() {
    print_header
    print_section_header "SOCKS5 Proxy Users"
    
    local users=()
    local user_lines=()
    
    # Collect users
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            users+=("$user")
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1 | sort)
    
    # Create progress bar for user count
    local max_users=20  # Assume max 20 users for visual
    local current_users=${#users[@]}
    if [[ $current_users -gt $max_users ]]; then max_users=$current_users; fi
    
    user_lines+=("${WHITE}Total Users:${NC} ${YELLOW}$current_users${NC}")
    user_lines+=("$(create_progress_bar $current_users $max_users 50 "Capacity" true)")
    user_lines+=("")
    
    if [[ ${#users[@]} -eq 0 ]]; then
        user_lines+=("${RED}${MEDIUM_BLOCK}${NC} ${YELLOW}No SOCKS5 users found${NC}")
    else
        # Display users with gradient colors
        local colors=(${GREEN} ${CYAN} ${BLUE} ${PURPLE} ${YELLOW} ${RED})
        for i in "${!users[@]}"; do
            local color_index=$((i % 6))
            local user_number=$(printf "%2d." $((i+1)))
            user_lines+=("${colors[$color_index]}${FULL_BLOCK}${NC} ${WHITE}$user_number${NC} ${CYAN}${users[i]}${NC}")
        done
    fi
    
    create_gradient_box "Users Management Dashboard" 78 1 user_lines
    
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

# Function to add single user with progress
add_single_user() {
    print_header
    print_section_header "Add Single User"
    
    local input_lines=(
        "${WHITE}Action:${NC} ${CYAN}Creating new SOCKS5 user${NC}"
        "${WHITE}Steps:${NC} Username → Password → Create → Config"
    )
    create_gradient_box "User Creation Process" 78 2 input_lines
    echo
    
    while true; do
        read -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Enter username: ")" username
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
        read -s -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Enter password: ")" password
        echo
        if [[ ${#password} -ge 4 ]]; then
            read -s -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Confirm password: ")" password2
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
    print_progress_header "Creating User" 0 3
    
    # Create user
    print_info "Creating system user..."
    show_progress_animation 15 "Creating"
    if useradd -r -s /bin/false "$username"; then
        print_progress_header "Creating User" 1 3
        
        print_info "Setting password..."
        show_progress_animation 10 "Configuring"
        echo "$username:$password" | chpasswd
        print_progress_header "Creating User" 2 3
        
        print_info "Creating config file..."
        show_progress_animation 12 "Generating"
        create_user_config "$username" "$password"
        print_progress_header "Creating User" 3 3
        
        local success_lines=(
            "${WHITE}Username:${NC} ${CYAN}$username${NC}"
            "${WHITE}Status:${NC} ${GREEN}${FULL_BLOCK} Created successfully!${NC}"
            "${WHITE}Config:${NC} ${YELLOW}$CONFIG_DIR/$username${NC}"
        )
        create_gradient_box "User Creation Complete" 78 2 success_lines
    else
        print_error "Failed to create user '$username'!"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to add multiple users with progress
add_multi_users() {
    print_header
    print_section_header "Add Multiple Users"

    local instruction_lines=(
        "${WHITE}Instructions:${NC}"
        "${CYAN}1.${NC} Enter usernames (one per line)"
        "${CYAN}2.${NC} Empty line twice to finish"
        "${CYAN}3.${NC} Set passwords for each user"
    )
    create_gradient_box "Bulk User Creation" 78 2 instruction_lines
    echo

    # Read usernames using multiline input
    local usernames_input
    usernames_input=$(read_multiline_input "Enter usernames (one per line):")
    if [[ -z "$usernames_input" ]]; then
        print_error "No usernames provided!"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Parse usernames
    local usernames=()
    local line_num=0
    while IFS= read -r username; do
        ((line_num++))
        [[ -z "$username" ]] && continue
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
    print_progress_header "Bulk User Creation" 0 ${#usernames[@]}
    
    # Create users and set passwords
    local created_users=()
    for i in "${!usernames[@]}"; do
        local username="${usernames[i]}"
        
        local user_info_lines=(
            "${WHITE}Current User:${NC} ${CYAN}$username${NC}"
            "${WHITE}Progress:${NC} $((i+1)) of ${#usernames[@]}"
        )
        create_gradient_box "Setting up: $username" 78 3 user_info_lines
        
        while true; do
            read -s -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Set password for '$username': ")" password
            echo
            if [[ ${#password} -ge 4 ]]; then
                read -s -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Confirm password for '$username': ")" password2
                echo
                if [[ "$password" == "$password2" ]]; then
                    print_info "Creating user '$username'..."
                    show_progress_animation 10 "Processing"
                    
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
        
        print_progress_header "Bulk User Creation" $((i+1)) ${#usernames[@]}
        echo
    done
    
    local summary_lines=(
        "${WHITE}Total Processed:${NC} ${YELLOW}${#usernames[@]}${NC}"
        "${WHITE}Successfully Created:${NC} ${GREEN}${#created_users[@]}${NC}"
        "${WHITE}Failed:${NC} ${RED}$((${#usernames[@]} - ${#created_users[@]}))${NC}"
        "${WHITE}Config Directory:${NC} ${CYAN}$CONFIG_DIR/${NC}"
    )
    create_gradient_box "Creation Summary" 78 2 summary_lines
    
    echo
    read -p "Press Enter to continue..."
}

# Function to manage user addition
manage_add_users() {
    while true; do
        print_header
        print_section_header "Add Users Menu"
        
        local menu_lines=(
            "${CYAN}1.${NC} ${GREEN}${FULL_BLOCK}${NC} Add single user"
            "${CYAN}2.${NC} ${BLUE}${FULL_BLOCK}${NC} Add multiple users"
            "${CYAN}0.${NC} ${PURPLE}${FULL_BLOCK}${NC} Back to main menu"
        )
        
        create_gradient_box "User Management Options" 78 1 menu_lines
        echo
        
        read -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Select option [0-2]: ")" choice
        
        case $choice in
            1) add_single_user ;;
            2) add_multi_users ;;
            0) break ;;
            *) print_error "Invalid option!" ;;
        esac
    done
}

# Function to delete users with progress
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
        local empty_lines=("${RED}${MEDIUM_BLOCK}${NC} ${YELLOW}No SOCKS5 users found to delete${NC}")
        create_gradient_box "User Deletion" 78 3 empty_lines
        echo
        read -p "Press Enter to continue..."
        return
    fi
    
    local user_list_lines=()
    user_list_lines+=("${WHITE}Available Users for Deletion:${NC}")
    user_list_lines+=("")
    
    for i in "${!users[@]}"; do
        local color_index=$((i % 6))
        local colors=(${RED} ${YELLOW} ${GREEN} ${CYAN} ${BLUE} ${PURPLE})
        user_list_lines+=("${colors[$color_index]}${FULL_BLOCK}${NC} ${WHITE}$((i+1)).${NC} ${users[i]}")
    done
    
    create_gradient_box "Users Available for Deletion" 78 1 user_list_lines
    
    echo
    local instruction_lines=(
        "${WHITE}Instructions:${NC}"
        "${CYAN}•${NC} Enter user numbers separated by spaces"
        "${CYAN}•${NC} Example: ${YELLOW}1 3 5${NC} (to delete users 1, 3, and 5)"
    )
    create_gradient_box "Selection Format" 78 3 instruction_lines
    echo
    
    read -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Selection: ")" selections
    
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
    local confirm_lines=()
    confirm_lines+=("${RED}${FULL_BLOCK} WARNING: Users to be deleted:${NC}")
    confirm_lines+=("")
    for user in "${to_delete[@]}"; do
        confirm_lines+=("${RED}${MEDIUM_BLOCK}${NC} $user")
    done
    create_gradient_box "Deletion Confirmation" 78 3 confirm_lines
    
    echo
    read -p "$(echo -e "${RED}${FULL_BLOCK}${NC} Are you sure you want to delete these users? (y/N): ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    print_progress_header "Deleting Users" 0 ${#to_delete[@]}
    
    # Delete users
    local deleted_count=0
    for i in "${!to_delete[@]}"; do
        local user="${to_delete[i]}"
        print_info "Deleting user: $user"
        show_progress_animation 8 "Removing"
        
        if userdel "$user" 2>/dev/null; then
            rm -f "$CONFIG_DIR/$user"
            print_success "Deleted user: $user"
            ((deleted_count++))
        else
            print_error "Failed to delete user: $user"
        fi
        
        print_progress_header "Deleting Users" $((i+1)) ${#to_delete[@]}
    done
    
    echo
    local summary_lines=(
        "${WHITE}Total Selected:${NC} ${YELLOW}${#to_delete[@]}${NC}"
        "${WHITE}Successfully Deleted:${NC} ${GREEN}$deleted_count${NC}"
        "${WHITE}Failed:${NC} ${RED}$((${#to_delete[@]} - deleted_count))${NC}"
    )
    create_gradient_box "Deletion Summary" 78 2 summary_lines
    
    echo
    read -p "Press Enter to continue..."
}

# Function to test proxies with gradient progress
test_proxies() {
    print_header
    print_section_header "Test Proxies"
    
    local format_lines=(
        "${WHITE}Format:${NC} ${YELLOW}IP:PORT:USERNAME:PASSWORD${NC}"
        "${WHITE}Example:${NC}"
        "${CYAN}192.168.1.100:1080:alice:secret456${NC}"
        "${CYAN}10.0.0.1:8080:bob:password123${NC}"
    )
    create_gradient_box "Proxy Format Guide" 78 2 format_lines
    echo
    
    # Read proxy list using multiline input
    local proxies_input
    exec 3>&1 4>&2
    proxies_input=$(read_multiline_input "Enter proxy list:" 2>&4)
    exec 3>&- 4>&-
    
    if [[ -z "$proxies_input" ]]; then
        print_error "No proxies provided!"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    
    # Parse proxies with validation
    local proxies=()
    local valid_count=0
    local invalid_count=0
    
    while IFS= read -r proxy_line; do
        [[ -z "$proxy_line" ]] && continue
        proxy_line=$(echo "$proxy_line" | xargs)
        [[ -z "$proxy_line" ]] && continue
        
        local colon_count=$(echo "$proxy_line" | tr -cd ':' | wc -c)
        
        if [[ $colon_count -eq 3 ]]; then
            IFS=':' read -r ip port user pass <<< "$proxy_line"
            
            if [[ -n "$ip" && -n "$port" && -n "$user" && -n "$pass" ]]; then
                if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
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
                        print_success "Valid: $proxy_line"
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
    
    if [[ $invalid_count -gt 0 ]]; then
        print_warning "Skipped $invalid_count invalid proxy entries"
    fi
    
    if [[ ${#proxies[@]} -eq 0 ]]; then
        print_error "No valid proxies provided!"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    print_progress_header "Testing Proxies" 0 ${#proxies[@]}
    
    local success_count=0
    local total_count=${#proxies[@]}
    local result_lines=()
    
    for i in "${!proxies[@]}"; do
        local proxy="${proxies[i]}"
        IFS=':' read -r ip port user pass <<< "$proxy"
        
        local curl_proxy="socks5://$user:$pass@$ip:$port"
        local display_proxy="${ip}:${port}@${user}"
        if [[ ${#display_proxy} -gt 25 ]]; then
            display_proxy="${display_proxy:0:22}..."
        fi
        
        local progress_indicator=$(printf "[%2d/%2d]" $((i+1)) $total_count)
        
        print_info "Testing: $display_proxy"
        
        if timeout 10 curl -s --proxy "$curl_proxy" --connect-timeout 5 -I http://httpbin.org/ip >/dev/null 2>&1; then
            result_lines+=("${GREEN}${FULL_BLOCK}${NC} ${progress_indicator} ${display_proxy} ${GREEN}SUCCESS${NC}")
            ((success_count++))
        else
            result_lines+=("${RED}${FULL_BLOCK}${NC} ${progress_indicator} ${display_proxy} ${RED}FAILED${NC}")
        fi
        
        print_progress_header "Testing Proxies" $((i+1)) ${#proxies[@]}
    done

    echo
    create_gradient_box "Proxy Test Results" 78 1 result_lines
    
    local success_rate=0
    if [[ $total_count -gt 0 ]]; then
        success_rate=$((success_count * 100 / total_count))
    fi
    
    echo
    local summary_lines=(
        "${WHITE}Total Proxies:${NC} ${YELLOW}$total_count${NC}"
        "${WHITE}Successful:${NC} ${GREEN}$success_count${NC}"
        "${WHITE}Failed:${NC} ${RED}$((total_count - success_count))${NC}"
        "${WHITE}Success Rate:${NC} $(create_progress_bar $success_rate 100 30 "" true)"
    )
    create_gradient_box "Test Summary" 78 2 summary_lines
    
    echo
    read -p "Press Enter to continue..."
}

# Function to uninstall Danted with progress
uninstall_danted() {
    print_header
    print_section_header "Uninstall Danted"
    
    local warning_lines=(
        "${RED}${FULL_BLOCK} WARNING: COMPLETE REMOVAL${NC}"
        "${YELLOW}This will completely remove Danted and all configurations!${NC}"
        "${YELLOW}All proxy users and config files will be affected.${NC}"
    )
    create_gradient_box "Uninstallation Warning" 78 3 warning_lines
    
    echo
    read -p "$(echo -e "${RED}${FULL_BLOCK}${NC} Are you sure you want to uninstall Danted? (y/N): ")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    print_progress_header "Uninstalling Danted" 0 4
    
    # Stop and disable service
    print_info "Stopping service..."
    show_progress_animation 15 "Stopping"
    systemctl stop $DANTED_SERVICE 2>/dev/null
    systemctl disable $DANTED_SERVICE 2>/dev/null
    print_progress_header "Uninstalling Danted" 1 4
    
    # Remove package
    print_info "Removing package..."
    show_progress_animation 20 "Removing"
    apt remove --purge -y dante-server >/dev/null 2>&1
    print_progress_header "Uninstalling Danted" 2 4
    
    # Remove configuration files
    print_info "Removing configuration files..."
    show_progress_animation 10 "Cleaning"
    rm -f "$DANTED_CONFIG"
    rm -f /var/log/danted.log
    print_progress_header "Uninstalling Danted" 3 4
    
    # Ask about user configs
    if [[ -d "$CONFIG_DIR" ]] && [[ $(ls -A "$CONFIG_DIR" 2>/dev/null) ]]; then
        echo
        read -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Remove all user config files in '$CONFIG_DIR'? (y/N): ")" remove_configs
        if [[ "$remove_configs" =~ ^[Yy]$ ]]; then
            rm -rf "$CONFIG_DIR"
            print_success "User config files removed"
        fi
    fi
    
    print_progress_header "Uninstalling Danted" 4 4
    
    # Ask about users
    local socks_users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            socks_users+=("$user")
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1)
    
    if [[ ${#socks_users[@]} -gt 0 ]]; then
        echo
        local user_found_lines=()
        user_found_lines+=("${YELLOW}Found ${#socks_users[@]} SOCKS5 users:${NC}")
        user_found_lines+=("")
        for user in "${socks_users[@]}"; do
            user_found_lines+=("${YELLOW}${MEDIUM_BLOCK}${NC} $user")
        done
        create_gradient_box "SOCKS5 Users Found" 78 3 user_found_lines
        
        echo
        read -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Remove all SOCKS5 users? (y/N): ")" remove_users
        if [[ "$remove_users" =~ ^[Yy]$ ]]; then
            echo
            print_info "Removing SOCKS5 users..."
            
            local user_removal_lines=()
            for user in "${socks_users[@]}"; do
                if userdel "$user" 2>/dev/null; then
                    user_removal_lines+=("${GREEN}${FULL_BLOCK}${NC} Removed: $user")
                else
                    user_removal_lines+=("${RED}${FULL_BLOCK}${NC} Failed: $user")
                fi
            done
            create_gradient_box "User Removal Results" 78 2 user_removal_lines
        fi
    fi
    
    echo
    local completion_lines=(
        "${GREEN}${FULL_BLOCK} Danted has been completely uninstalled!${NC}"
        "${CYAN}${MEDIUM_BLOCK} System cleaned up successfully!${NC}"
        "${BLUE}${DARK_BLOCK} All services and configurations removed.${NC}"
    )
    create_gradient_box "Uninstallation Complete" 78 2 completion_lines
    
    echo
    read -p "Press Enter to continue..."
}

# Main menu function with gradient
show_main_menu() {
    print_header
    print_section_header "Main Menu"
    
    local menu_lines=(
        "${CYAN}1.${NC} ${GREEN}${FULL_BLOCK}${NC} Install Danted SOCKS5 Proxy"
        "${CYAN}2.${NC} ${BLUE}${FULL_BLOCK}${NC} Show Users"
        "${CYAN}3.${NC} ${YELLOW}${FULL_BLOCK}${NC} Add Users"
        "${CYAN}4.${NC} ${RED}${FULL_BLOCK}${NC} Delete Users"
        "${CYAN}5.${NC} ${PURPLE}${FULL_BLOCK}${NC} Test Proxies"
        "${CYAN}6.${NC} ${LIGHT_CYAN}${FULL_BLOCK}${NC} Check Status & Monitoring"
        "${CYAN}7.${NC} ${LIGHT_RED}${FULL_BLOCK}${NC} Uninstall Danted"
        "${CYAN}0.${NC} ${WHITE}${FULL_BLOCK}${NC} Exit"
    )
    
    create_gradient_box "Proxy Management Dashboard" 78 1 menu_lines
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
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        local error_lines=()
        error_lines+=("${RED}Missing required commands:${NC}")
        error_lines+=("")
        for cmd in "${missing_commands[@]}"; do
            error_lines+=("${RED}${FULL_BLOCK}${NC} $cmd")
        done
        error_lines+=("")
        error_lines+=("${YELLOW}Please install the required packages.${NC}")
        create_gradient_box "System Requirements Error" 78 3 error_lines
        exit 1
    fi
    
    while true; do
        show_main_menu
        read -p "$(echo -e "${YELLOW}${FULL_BLOCK}${NC} Select option [0-7]: ")" choice
        
        case $choice in
            1) install_danted ;;
            2) show_users ;;
            3) manage_add_users ;;
            4) delete_users ;;
            5) test_proxies ;;
            6) check_service_status ;;
            7) uninstall_danted ;;
            0) 
                # Clear screen and show thank you message with gradient
                clear
                create_gradient_line 78 3
                echo -e "${CYAN}${LIGHT_BLOCK}${WHITE}${BOLD}                            THANK YOU!                              ${NC}${CYAN}${LIGHT_BLOCK}${NC}"
                echo -e "${BLUE}${MEDIUM_BLOCK}${WHITE}              Thank you for using Danted SOCKS5 Proxy Manager!        ${NC}${BLUE}${MEDIUM_BLOCK}${NC}"
                echo -e "${PURPLE}${DARK_BLOCK}${WHITE}                     Gradient Progress Style v3.0                   ${NC}${PURPLE}${DARK_BLOCK}${NC}"
                create_gradient_line 78 3
                
                local farewell_lines=(
                    "${GREEN}${FULL_BLOCK} Session completed successfully!${NC}"
                    "${CYAN}${MEDIUM_BLOCK} All operations finished.${NC}"
                    "${YELLOW}${DARK_BLOCK} Have a great day!${NC}"
                )
                create_gradient_box "Session Complete" 78 2 farewell_lines
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