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
    local title_length=${#title}
    local padding=$((77 - title_length))
    
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────────────────────────┐${NC}"
    printf  "${BLUE}│${WHITE}${BOLD} %s${NC}${BLUE}%*s│${NC}\n" "$title" $padding ""
    echo -e "${BLUE}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

# Function to print info box
print_info_box() {
    local message=$1
    local color=${2:-$CYAN}
    local msg_length=${#message}
    local padding=$((77 - msg_length))
    
    echo -e "${color}┌─ INFO ───────────────────────────────────────────────────────────────────────┐${NC}"
    printf  "${color}│ %s%*s│${NC}\n" "$message" $padding ""
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
    echo -e "${GRAY}Enter data (Enter 1 user per line, press Enter twice to finish):${NC}"
    
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

detect_public_ip_silent() {
    local detected_ip=""
    local services=(
        "curl -s --connect-timeout 10 --max-time 15 ifconfig.me"
        "curl -s --connect-timeout 10 --max-time 15 ifconfig.co"  
        "curl -s --connect-timeout 10 --max-time 15 ipinfo.io/ip"
        "curl -s --connect-timeout 10 --max-time 15 icanhazip.com"
        "curl -s --connect-timeout 10 --max-time 15 checkip.amazonaws.com"
        "curl -s --connect-timeout 10 --max-time 15 ipecho.net/plain"
        "wget -qO- --timeout=15 ifconfig.me"
        "wget -qO- --timeout=15 ipinfo.io/ip"
    )
    
    for service in "${services[@]}"; do
        detected_ip=$(eval $service 2>/dev/null | tr -d '[:space:]')
        
        # Validate IP format
        if [[ "$detected_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            # Check each octet is between 0-255
            local valid_ip=true
            IFS='.' read -ra ADDR <<< "$detected_ip"
            for octet in "${ADDR[@]}"; do
                if [[ $octet -lt 0 || $octet -gt 255 ]]; then
                    valid_ip=false
                    break
                fi
            done
            
            if [[ "$valid_ip" == true ]]; then
                echo "$detected_ip"
                return 0
            fi
        fi
    done
    
    return 1
}

# Function to detect public IP address (with display)
detect_public_ip() {
    local detected_ip=""
    local services=(
        "curl -s --connect-timeout 10 --max-time 15 ifconfig.me"
        "curl -s --connect-timeout 10 --max-time 15 ifconfig.co"  
        "curl -s --connect-timeout 10 --max-time 15 ipinfo.io/ip"
        "curl -s --connect-timeout 10 --max-time 15 icanhazip.com"
        "curl -s --connect-timeout 10 --max-time 15 checkip.amazonaws.com"
        "curl -s --connect-timeout 10 --max-time 15 ipecho.net/plain"
        "wget -qO- --timeout=15 ifconfig.me"
        "wget -qO- --timeout=15 ipinfo.io/ip"
    )
    
    print_color $YELLOW "🔍 Auto-detecting public IP address..."
    
    for service in "${services[@]}"; do
        local service_name=$(echo "$service" | grep -o '[a-zA-Z0-9.-]*\.[a-zA-Z]*' | head -1)
        print_color $GRAY "  Trying $service_name..."
        
        detected_ip=$(eval $service 2>/dev/null | tr -d '[:space:]')
        
        # Validate IP format
        if [[ "$detected_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            # Check each octet is between 0-255
            local valid_ip=true
            IFS='.' read -ra ADDR <<< "$detected_ip"
            for octet in "${ADDR[@]}"; do
                if [[ $octet -lt 0 || $octet -gt 255 ]]; then
                    valid_ip=false
                    break
                fi
            done
            
            if [[ "$valid_ip" == true ]]; then
                print_success "Detected public IP: $detected_ip"
                echo "$detected_ip"
                return 0
            fi
        fi
    done
    
    print_error "Failed to auto-detect public IP address"
    return 1
}

# Function to check if IP exists on network interfaces
check_ip_exists() {
    local ip_to_check=$1
    if [[ "$ip_to_check" == "0.0.0.0" ]]; then
        return 0  # 0.0.0.0 is always valid
    fi
    
    # Check if IP exists on any interface
    if ip addr show | grep -q "inet $ip_to_check/"; then
        return 0  # IP exists
    else
        return 1  # IP doesn't exist
    fi
}

# Function to get network interfaces with IPs
get_network_interfaces() {
    print_section_header "Network Interface Selection"

    
    local interfaces=()
    local ips=()
    local counter=1
    
    # Header with fixed width
    echo -e "${CYAN}┌─ Available Network Interfaces ───────────────────────────────────────────────┐${NC}"
    printf "${CYAN}│${NC} ${WHITE}No.${NC} ${WHITE}Interface Name       ${WHITE}IP Address${NC}%*s${CYAN}│${NC}\n" 42 ""

    # Loop through network interfaces and IPs
    while IFS= read -r line; do
        interface=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | awk '{print $2}')
        if [[ "$interface" != "lo" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            interfaces+=("$interface")
            ips+=("$ip")

            # Format interface name and IP with fixed width
            local interface_padded=$(printf "%-20s" "$interface")
            local content_length=$((3 + 2 + 20 + 1 + ${#ip}))  # " XX. interface_name IP"
            local padding=$((78 - content_length))
            
            printf "${CYAN}│${NC} %2d. %s ${GREEN}%s${NC}%*s${CYAN}│${NC}\n" \
                $counter "$interface_padded" "$ip" $padding ""
            ((counter++))
        fi
    done < <(ip -4 addr show | grep -oP '^\d+: \K\w+|inet \K[^/]+' | paste - -)
    # Footer with fixed width
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
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


# Function to display system information with Dante status
show_system_info() {
    # Collect system information
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' | cut -d. -f1)
    memory_info=$(free -h | grep '^Mem:')
    memory_used=$(echo $memory_info | awk '{print $3}')
    memory_total=$(echo $memory_info | awk '{print $2}')
    disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    uptime_info=$(uptime -p | sed 's/up //')
    
    # Add variables to collect Dante information
    dante_status="Unknown"
    auto_start_status="Unknown"
    listen_address="Unknown"
    listen_port="Unknown"
    active_connections="0"

    # Check Dante service status
    if systemctl is-active --quiet danted 2>/dev/null; then
        dante_status="Running"
    elif systemctl is-failed --quiet danted 2>/dev/null; then
        dante_status="Failed"
    else
        dante_status="Stopped"
    fi

    # Check auto-start status
    if systemctl is-enabled --quiet danted 2>/dev/null; then
        auto_start_status="Enabled"
    else
        auto_start_status="Disabled"
    fi

    # Get listen address and port from config file or netstat
    if [ -f /etc/danted.conf ]; then
        internal_line=$(grep -E "^[[:space:]]*internal:" /etc/danted.conf | head -1)
        if [ -n "$internal_line" ]; then
            # Extract IP address and port more reliably
            listen_address=$(echo "$internal_line" | sed -n 's/.*internal:[[:space:]]*\([^[:space:]]*\).*/\1/p' | sed 's/port=.*//')
            listen_port=$(echo "$internal_line" | sed -n 's/.*port[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
            if [ -z "$listen_address" ]; then
                listen_address="Not configured"
                listen_port="Not configured"
            fi
        else
            listen_address="Not configured"
            listen_port="Not configured"
        fi
    else
        # Fallback: check from netstat
        listen_port=$(netstat -tlnp 2>/dev/null | grep danted | head -1 | awk '{print $4}' | cut -d: -f2)
        if [ -z "$listen_port" ]; then
            listen_address="Not found"
            listen_port="Not found"
        else
            listen_address="0.0.0.0"
        fi
    fi

    # Count active connections - simplified
    active_connections="0"
    
    # Get current port from config if SELECTED_PORT is not set
    if [[ -z "$SELECTED_PORT" ]]; then
        if [ -f "$DANTED_CONFIG" ]; then
            SELECTED_PORT=$(grep -E "^[[:space:]]*internal:" "$DANTED_CONFIG" | head -1 | sed -n 's/.*port[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
        fi
    fi
    
    if [[ -n "$SELECTED_PORT" ]]; then
        if command -v ss >/dev/null 2>&1; then
            conn_count=$(ss -tn 2>/dev/null | grep ":$SELECTED_PORT" | wc -l)
            active_connections="$conn_count"
        elif command -v netstat >/dev/null 2>&1; then
            conn_count=$(netstat -tn 2>/dev/null | grep ":$SELECTED_PORT" | wc -l)
            active_connections="$conn_count"
        fi
    fi

    # Function to print formatted line with exact width control
    print_info_line() {
        local label="$1"
        local value="$2"
        local color="$3"
        
        # Calculate exact content length
        local label_len=${#label}
        local value_len=${#value}
        local content_len=$((label_len + value_len + 3)) # ": " adds 2, space adds 1
        
        # Total box width is 79 characters (including borders)
        # Content area is 78 characters
        local padding=$((78 - content_len))
        
        # Ensure padding is not negative
        if [ $padding -lt 0 ]; then
            padding=0
        fi
        
        printf "${CYAN}│${NC} %s: ${color}%s${NC}%*s${CYAN}│${NC}\n" "$label" "$value" $padding ""
    }

    # Header
    echo -e "${CYAN}┌─ System Information ─────────────────────────────────────────────────────────┐${NC}"

    # System Information
    print_info_line "CPU Usage" "${cpu_usage}%" "${GREEN}"
    
    # Memory formatting
    memory_display="${memory_used} / ${memory_total}"
    if [[ ${#memory_display} -gt 25 ]]; then
        memory_display="${memory_used}/${memory_total}"
    fi
    print_info_line "Memory" "$memory_display" "${GREEN}"
    
    print_info_line "Disk Usage" "$disk_usage" "${GREEN}"
    print_info_line "Uptime" "$uptime_info" "${GREEN}"

    # Separator
    echo -e "${CYAN}├──────────────────────────────────────────────────────────────────────────────┤${NC}"

    # Dante Information
    dante_color="${GREEN}"
    if [ "$dante_status" != "Running" ]; then
        dante_color="${RED}"
    fi
    print_info_line "Dante Status" "$dante_status" "$dante_color"

    autostart_color="${GREEN}"
    if [ "$auto_start_status" != "Enabled" ]; then
        autostart_color="${YELLOW}"
    fi
    print_info_line "Auto-start Status" "$auto_start_status" "$autostart_color"

    print_info_line "Listen Address" "$listen_address"    "${GREEN}"
    print_info_line "Listen Port" "$listen_port"    "${YELLOW}"
    print_info_line "Active Connections" "$active_connections" "${GREEN}"

    # Footer
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
}

# Function to check service status
check_service_status() {
    print_header
    print_section_header "Service Status & System Monitoring"
       
    # Call the function
    show_system_info
    echo
    
    # Recent logs - Fixed width with rounded corners
    echo -e "${CYAN}┌─ Recent Service Logs ────────────────────────────────────────────────────────┐${NC}"
    
    # Log header
    local log_header="Last 5 logs from the last hour:"
    local log_header_length=$((${#log_header} + 1))
    local log_header_padding=$((78 - log_header_length))
    printf "${CYAN}│${NC} ${GRAY}%s${NC}%*s${CYAN}│${NC}\n" "$log_header" $log_header_padding ""
    
    # Display logs
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        if journalctl -u $DANTED_SERVICE --no-pager -n 5 --since "1 hour ago" 2>/dev/null | grep -q "."; then
            journalctl -u $DANTED_SERVICE --no-pager -n 5 --since "1 hour ago" 2>/dev/null | while read -r line; do
                # Truncate long log lines to fit in box
                if [[ ${#line} -gt 73 ]]; then
                    line="${line:0:70}..."
                fi
                local line_length=$((${#line} + 1))
                local line_padding=$((78 - line_length))
                printf "${CYAN}│${NC} ${GRAY}%s${NC}%*s${CYAN}│${NC}\n" "$line" $line_padding ""
            done
        else
            local no_logs="No recent logs found"
            local no_logs_length=$((${#no_logs} + 1))
            local no_logs_padding=$((78 - no_logs_length))
            printf "${CYAN}│${NC} ${GRAY}%s${NC}%*s${CYAN}│${NC}\n" "$no_logs" $no_logs_padding ""
        fi
    else
        local log_warning="Danted service is not running. No logs available."
        local log_warning_length=$((${#log_warning} + 1))
        local log_warning_padding=$((78 - log_warning_length))
        printf "${CYAN}│${NC} ${YELLOW}%s${NC}%*s${CYAN}│${NC}\n" "$log_warning" $log_warning_padding ""
    fi
    
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo

    # Control options with box formatting
    echo -e "${YELLOW}┌─ Control Options ────────────────────────────────────────────────────────────┐${NC}"

    local control_items=(
        "1. Restart Service"
        "2. Stop Service"           
        "3. Change Port"
        "4. Update Config Files"
        "5. Test Internet Bandwidth (beta)"
        "6. Full Service Logs"
        "7. Back to Main Menu"
    )

    for item in "${control_items[@]}"; do
        local item_length=$((${#item} + 1))  # +1 for leading space
        local item_padding=$((78 - item_length))
        printf "${YELLOW}│${NC} ${CYAN}%s${NC}%*s${YELLOW}│${NC}\n" "$item" $item_padding ""
    done

    echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    while true; do
        read -p "$(echo -e "${YELLOW}❯${NC} Select option [1-7]: ")" choice
        
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
                change_port
                check_service_status
                return
                ;;
            4)
                update_config_files 
                check_service_status
                return
                ;;
            5)
                test_bandwidth
                check_service_status
                return
                ;;
            6)
                print_section_header "Full Service Logs"
                journalctl -u $DANTED_SERVICE --no-pager -n 50
                echo
                read -p "Press Enter to continue..."
                check_service_status
                return
                ;;
            7)
                break
                ;;
            *)
                print_error "Invalid option!"
                ;;
        esac
    done
}

# Function to change port
change_port() {
    print_header
    print_section_header "Change Danted Port"
    
    # Check if Danted is installed
    if [ ! -f "$DANTED_CONFIG" ]; then
        print_error "Danted is not installed or configured!"
        print_warning "Please install Danted first."
        echo
        read -p "Press Enter to continue..."
        return
    fi
    
    # Get current port
    local current_port=""
    if [ -f "$DANTED_CONFIG" ]; then
        current_port=$(grep -E "^[[:space:]]*internal:" "$DANTED_CONFIG" | head -1 | sed -n 's/.*port[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
    fi
    
    if [ -z "$current_port" ]; then
        current_port="Not configured"
    fi
    
    echo -e "${CYAN}┌─ Current Configuration ──────────────────────────────────────────────────────┐${NC}"
    printf "${CYAN}${NC} Current Port: ${YELLOW}%s${NC}%*s${CYAN}${NC}\n" "$current_port" 60 ""
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    # Get new port
    while true; do
        read -p "$(echo -e "${YELLOW}❯${NC} Enter new port (1-65535): ")" new_port
        
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [[ $new_port -ge 1 ]] && [[ $new_port -le 65535 ]]; then
            # Check if port is already in use
            if netstat -tuln 2>/dev/null | grep -q ":$new_port "; then
                print_error "Port $new_port is already in use!"
                read -p "$(echo -e "${YELLOW}❯${NC} Do you want to continue anyway? (Y/N): ")" continue_anyway
                if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                    continue
                fi
            fi
            break
        else
            print_error "Invalid port number. Please enter a number between 1-65535."
        fi
    done
    
    echo
    print_warning "This will restart the Danted service."
    read -p "$(echo -e "${YELLOW}❯${NC} Continue? (Y/N): ")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    print_color $YELLOW "Changing port to $new_port..."
    
    # Backup current config
    cp "$DANTED_CONFIG" "${DANTED_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Get current IP address
    local current_ip=""
    if [ -f "$DANTED_CONFIG" ]; then
        current_ip=$(grep -E "^[[:space:]]*internal:" "$DANTED_CONFIG" | head -1 | sed -n 's/.*internal:[[:space:]]*\([^[:space:]]*\).*/\1/p' | sed 's/port=.*//')
    fi
    
    if [ -z "$current_ip" ]; then
        current_ip="0.0.0.0"
    fi
    
    # Update config file
    sed -i "s/^[[:space:]]*internal:.*/internal: $current_ip port = $new_port/" "$DANTED_CONFIG"
    
    if [ $? -eq 0 ]; then
        print_success "Configuration updated successfully!"
        
        # Restart service
        print_color $YELLOW "Restarting Danted service..."
        if systemctl restart $DANTED_SERVICE; then
            sleep 2
            if systemctl is-active --quiet $DANTED_SERVICE; then
                print_success "Service restarted successfully!"
                print_success "New port: $new_port"
            else
                print_error "Service failed to start with new port!"
                print_warning "Restoring previous configuration..."
                cp "${DANTED_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)" "$DANTED_CONFIG"
                systemctl restart $DANTED_SERVICE
            fi
        else
            print_error "Failed to restart service!"
            print_warning "Restoring previous configuration..."
            cp "${DANTED_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)" "$DANTED_CONFIG"
        fi
    else
        print_error "Failed to update configuration!"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

update_config_files() {
    print_header
    print_section_header "Update V2Ray/Xray Config Files"
    
    # Check if config directory exists
    if [[ ! -d "$CONFIG_DIR" ]]; then
        print_error "Config directory '$CONFIG_DIR' does not exist!"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Find all config files
    local config_files=()
    while IFS= read -r -d '' file; do
        config_files+=("$file")
    done < <(find "$CONFIG_DIR" -type f -print0 2>/dev/null)
    
    if [[ ${#config_files[@]} -eq 0 ]]; then
        print_warning "No config files found in '$CONFIG_DIR'!"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Display current config files
    echo -e "${CYAN}┌─ Found Config Files (${#config_files[@]} files) ───────────────────────────────────────────────┐${NC}"

    # Extract current config from first file
    local current_ip=""
    local current_port=""
    
    if [[ ${#config_files[@]} -gt 0 ]]; then
        # Use jq to extract IP and port from outbounds section (more reliable for JSON)
        if command -v jq &>/dev/null; then
            current_ip=$(jq -r '.outbounds[] | select(.settings.servers) | .settings.servers[0].address // empty' "${config_files[0]}" 2>/dev/null)
            current_port=$(jq -r '.outbounds[] | select(.settings.servers) | .settings.servers[0].port // empty' "${config_files[0]}" 2>/dev/null)
        else
            # Fallback to grep if jq is not available
            current_ip=$(grep -o '"address": "[^"]*"' "${config_files[0]}" | head -1 | cut -d'"' -f4)
            current_port=$(grep -o '"port": [0-9]*' "${config_files[0]}" | head -1 | grep -o '[0-9]*')
        fi
    fi

    # Display all config files
    for i in "${!config_files[@]}"; do
        local filename=$(basename "${config_files[i]}")
        local user_number=$(printf "%3d." $((i+1)))
        local user_display="$user_number $filename"
        local user_length=$((${#user_display} + 1))
        local user_padding=$((78 - user_length))

        printf "${CYAN}│${NC} %s%*s${CYAN}│${NC}\n" "$user_display" $user_padding ""
    done
    
    # Show current config after file list
    if [[ -n "$current_ip" && -n "$current_port" ]]; then
        echo -e "${CYAN}├──────────────────────────────────────────────────────────────────────────────┤${NC}"
        printf "${CYAN}│${NC} ${GRAY}Current config: ${WHITE}%s:%s${NC}%*s${CYAN}│${NC}\n" "$current_ip" "$current_port" $((78 - 18 - ${#current_ip} - ${#current_port})) ""
    fi
    
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    # Get new IP address
    local new_ip=""
    while true; do
        # Try to get current server IP first
        local detected_ip=""
        if [[ -n "$DETECTED_PUBLIC_IP" ]]; then
            detected_ip="$DETECTED_PUBLIC_IP"
        else
            detected_ip=$(detect_public_ip_silent)
        fi
        
        if [[ -n "$detected_ip" ]]; then
            print_color $CYAN "💡 Auto-detected current server IP: $detected_ip"
            read -p "$(echo -e "${YELLOW}❯${NC} Enter new IP address (or press Enter to use $detected_ip): ")" new_ip
            new_ip=${new_ip:-$detected_ip}
        else
            read -p "$(echo -e "${YELLOW}❯${NC} Enter new IP address: ")" new_ip
        fi
        
        # Validate IP format
        if [[ "$new_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            local valid_ip=true
            IFS='.' read -ra ADDR <<< "$new_ip"
            for octet in "${ADDR[@]}"; do
                if [[ $octet -lt 0 || $octet -gt 255 ]]; then
                    valid_ip=false
                    break
                fi
            done
            
            if [[ "$valid_ip" == true ]]; then
                break
            else
                print_error "Invalid IP address. Each number must be between 0-255."
            fi
        else
            print_error "Invalid IP format. Please use format: xxx.xxx.xxx.xxx"
        fi
    done
    
    # Get new port
    local new_port=""
    while true; do
        # Try to get current port from Dante config
        local current_dante_port=""
        if [[ -f "$DANTED_CONFIG" ]]; then
            current_dante_port=$(grep -E "^[[:space:]]*internal:" "$DANTED_CONFIG" | head -1 | sed -n 's/.*port[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
        fi
        
        if [[ -n "$current_dante_port" ]]; then
            print_color $CYAN "💡 Current Dante server port: $current_dante_port"
            read -p "$(echo -e "${YELLOW}❯${NC} Enter new port (or press Enter to use $current_dante_port): ")" new_port
            new_port=${new_port:-$current_dante_port}
        else
            read -p "$(echo -e "${YELLOW}❯${NC} Enter new port: ")" new_port
        fi
        
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [[ $new_port -ge 1 ]] && [[ $new_port -le 65535 ]]; then
            break
        else
            print_error "Invalid port number. Please enter a number between 1-65535."
        fi
    done
    
    # Confirm changes
    echo
    print_info_box "Will update ${#config_files[@]} config files with: $new_ip:$new_port"
    read -p "$(echo -e "${YELLOW}❯${NC} Continue with update? (Y/N): ")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    print_color $YELLOW "Updating config files..."
    
    # Create backup directory
    local backup_dir="${CONFIG_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Update each config file
    local updated_count=0
    local failed_count=0
    
    for config_file in "${config_files[@]}"; do
        local filename=$(basename "$config_file")
        echo -e "${CYAN}Processing: ${WHITE}$filename${NC}"
        
        # Create backup
        cp "$config_file" "$backup_dir/$filename" 2>/dev/null
        
        # Create temporary file for processing
        local temp_file=$(mktemp)
        
        # Update IP and port using jq (more reliable for JSON)
        if command -v jq &>/dev/null; then
            # Use jq to update only outbounds settings
            if jq --arg ip "$new_ip" --argjson port "$new_port" \
                '(.outbounds[] | select(.settings.servers) | .settings.servers[].address) |= $ip | 
                 (.outbounds[] | select(.settings.servers) | .settings.servers[].port) |= $port' \
                "$config_file" > "$temp_file" 2>/dev/null; then
                
                # Validate JSON format
                if python3 -m json.tool "$temp_file" >/dev/null 2>&1; then
                    mv "$temp_file" "$config_file"
                    print_success "  ✓ Updated: $filename"
                    ((updated_count++))
                else
                    print_error "  ✗ JSON validation failed: $filename"
                    rm -f "$temp_file"
                    ((failed_count++))
                fi
            else
                print_error "  ✗ Failed to process with jq: $filename"
                rm -f "$temp_file"
                ((failed_count++))
            fi
        else
            # Fallback to sed if jq is not available
            print_warning "  ⚠ jq not found, using sed (may cause issues)"
            if sed -e "s/\"address\": \"[^\"]*\"/\"address\": \"$new_ip\"/g" \
                   -e "s/\"port\": [0-9]*/\"port\": $new_port/g" \
                   "$config_file" > "$temp_file" 2>/dev/null; then
                
                # Validate JSON format
                if python3 -m json.tool "$temp_file" >/dev/null 2>&1; then
                    mv "$temp_file" "$config_file"
                    print_success "  ✓ Updated: $filename (using sed)"
                    ((updated_count++))
                else
                    print_error "  ✗ JSON validation failed: $filename"
                    rm -f "$temp_file"
                    ((failed_count++))
                fi
            else
                print_error "  ✗ Failed to process: $filename"
                rm -f "$temp_file"
                ((failed_count++))
            fi
        fi
    done
    
    echo
    print_success "Update completed!"
    print_success "✅ Successfully updated: $updated_count files"
    
    if [[ $failed_count -gt 0 ]]; then
        print_error "❌ Failed to update: $failed_count files"
    fi
    
    print_success "📁 Backup created in: $backup_dir"
    
    # Show sample of updated config
    if [[ $updated_count -gt 0 ]]; then
        echo
        print_color $CYAN "📋 Sample updated configuration:"
        local sample_file="${config_files[0]}"
        local sample_name=$(basename "$sample_file")
        echo -e "${GRAY}From file: $sample_name${NC}"
        
        # Extract and show the server configuration part
        echo -e "${CYAN}┌─ Updated Server Config ──────────────────────────────────────────────────────┐${NC}"
        
        local address_line=$(grep -n '"address":' "$sample_file" | head -1)
        local port_line=$(grep -n '"port":' "$sample_file" | head -1)
        
        if [[ -n "$address_line" && -n "$port_line" ]]; then
            printf "${CYAN}│${NC} ${GREEN}\"address\": \"$new_ip\"${NC}%*s${CYAN}│${NC}\n" $((78 - 14 - ${#new_ip})) ""
            printf "${CYAN}│${NC} ${GREEN}\"port\": $new_port${NC}%*s${CYAN}│${NC}\n" $((78 - 9 - ${#new_port})) ""
        fi
        
        echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to test bandwidth
test_bandwidth() {
    clear
    print_header
    print_section_header "Internet Bandwidth Test"
    
    # Multiple test servers for better accuracy
    local test_servers=(
        "http://speedtest.ftp.otenet.gr/files/test1Mb.db"
        "http://speedtest.ftp.otenet.gr/files/test10Mb.db"
        "http://ipv4.download.thinkbroadband.com/10MB.zip"
        "http://speedtest.tele2.net/1MB.zip"
        "http://speedtest-sgp1.digitalocean.com/10mb.test"
        "http://speedtest-nyc1.digitalocean.com/10mb.test"
        "http://speedtest-sfo1.digitalocean.com/10mb.test"
        "http://speedtest.ams01.softlayer.com/downloads/test10.zip"
        "http://speedtest.tokyo.linode.com/100MB-tokyo.bin"
        "http://speedtest.london.linode.com/100MB-london.bin"
        "http://speedtest.dal05.softlayer.com/downloads/test10.zip"
    )
    
    # Function to format speed
    format_speed() {
        local speed=$1
        if (( $(echo "$speed >= 1000" | bc -l 2>/dev/null || echo "0") )); then
            echo "$(echo "scale=2; $speed / 1000" | bc -l 2>/dev/null || echo "0") Gbps"
        else
            echo "$(echo "scale=2; $speed" | bc -l 2>/dev/null || echo "0") Mbps"
        fi
    }
    
    # Function to test single server
    test_single_server() {
        local server_url=$1
        local server_name=$(echo "$server_url" | sed 's|.*//||' | sed 's|/.*||')
        
        print_color $CYAN "Testing with: $server_name"
        
        # Test download speed
        local speed_result=$(curl -s -w "%{speed_download}" -o /dev/null --connect-timeout 10 --max-time 30 "$server_url" 2>/dev/null)
        
        if [[ "$speed_result" =~ ^[0-9]+\.?[0-9]*$ ]] && (( $(echo "$speed_result > 0" | bc -l 2>/dev/null || echo "0") )); then
            local speed_mbps=$(echo "scale=2; $speed_result / 1024 / 1024 * 8" | bc -l 2>/dev/null || echo "0")
            print_success "Speed: $(format_speed $speed_mbps)"
            echo "$speed_mbps"
        else
            print_error "Failed to test with $server_name"
            echo "0"
        fi
    }
    
    # Test direct connection
    print_color $YELLOW "Testing direct internet connection..."
    print_color $YELLOW "This may take a while... Please wait..."
    echo
    
    local speeds=()
    local valid_tests=0
    
    for server in "${test_servers[@]}"; do
        local speed=$(test_single_server "$server")
        if (( $(echo "$speed > 0" | bc -l 2>/dev/null || echo "0") )); then
            speeds+=("$speed")
            ((valid_tests++))
        fi
        echo
    done
    
    if [[ $valid_tests -eq 0 ]]; then
        print_error "All speed tests failed!"
        print_warning "Please check your internet connection."
        echo
        read -p "Press Enter to continue..."
        return
    fi
    
    # Calculate average speed
    local total_speed=0
    for speed in "${speeds[@]}"; do
        total_speed=$(echo "$total_speed + $speed" | bc -l 2>/dev/null || echo "0")
    done
    local avg_speed=$(echo "scale=2; $total_speed / $valid_tests" | bc -l 2>/dev/null || echo "0")
    
    # Display results
    echo -e "${CYAN}┌─ Direct Connection Test Results ─────────────────────────────────────────────┐${NC}"
    printf "${CYAN}${NC} Valid Tests:     ${GREEN}%d${NC}%*s${CYAN}${NC}\n" $valid_tests 60 ""
    printf "${CYAN}${NC} Average Speed:   ${GREEN}%s${NC}%*s${CYAN}${NC}\n" "$(format_speed $avg_speed)" 60 ""
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    # Ask if user wants to test proxies
    echo
    read -p "$(echo -e "${YELLOW}❯${NC} Do you want to test proxy speeds? (Y/N): ")" test_proxies
    
    if [[ "$test_proxies" =~ ^[Yy]$ ]]; then
        test_proxy_speeds "$avg_speed"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to test proxy speeds
test_proxy_speeds() {
    local direct_speed=$1
    
    print_section_header "Proxy Speed Test"
    
    # Show format example
    echo -e "${YELLOW}Format: ${WHITE}IP:PORT:USERNAME:PASSWORD${NC}"
    echo -e "${GRAY}Example:${NC}"
    echo -e "  ${CYAN}100.150.200.250:30500:user1:pass123${NC}"
    echo -e "${GRAY}Enter one proxy per line, Press Enter twice to finish.${NC}"
    echo
    
    # Read proxy list using multiline input
    local proxies_input
    exec 3>&1 4>&2
    proxies_input=$(read_multiline_input "Enter proxy list:" 2>&4)
    exec 3>&- 4>&-
    
    if [[ -z "$proxies_input" ]]; then
        print_error "No proxies provided!"
        return
    fi
    
    # Parse proxies
    local proxies=()
    while IFS= read -r proxy_line; do
        if [[ -n "$proxy_line" ]]; then
            proxy_line=$(echo "$proxy_line" | xargs)
            local colon_count=$(echo "$proxy_line" | tr -cd ':' | wc -c)
            if [[ $colon_count -eq 3 ]]; then
                IFS=':' read -r ip port user pass <<< "$proxy_line"
                if [[ -n "$ip" && -n "$port" && -n "$user" && -n "$pass" ]]; then
                    if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
                        # Check for duplicates
                        local is_duplicate=false
                        for existing_proxy in "${proxies[@]}"; do
                            if [[ "$existing_proxy" == "$proxy_line" ]]; then
                                is_duplicate=true
                                break
                            fi
                        done
                        
                        if [[ "$is_duplicate" == false ]]; then
                            proxies+=("$proxy_line")
                        fi
                    fi
                fi
            fi
        fi
    done <<< "$proxies_input"
    
    if [[ ${#proxies[@]} -eq 0 ]]; then
        print_error "No valid proxies provided!"
        return
    fi
    
    echo
    print_color $CYAN "Testing ${#proxies[@]} proxies..."
    echo
    
    # Test servers for proxy testing (smaller files for faster testing)
    local proxy_test_servers=(
        "http://speedtest.ftp.otenet.gr/files/test1Mb.db"
        "http://ipv4.download.thinkbroadband.com/1MB.zip"
    )
    
    # Function to format speed
    format_speed() {
        local speed=$1
        if (( $(echo "$speed >= 1000" | bc -l 2>/dev/null || echo "0") )); then
            echo "$(echo "scale=2; $speed / 1000" | bc -l 2>/dev/null || echo "0") Gbps"
        else
            echo "$(echo "scale=2; $speed" | bc -l 2>/dev/null || echo "0") Mbps"
        fi
    }
    
    # Function to test single proxy
    test_single_proxy() {
        local proxy=$1
        local proxy_num=$2
        local total_proxies=$3
        
        IFS=':' read -r ip port user pass <<< "$proxy"
        local curl_proxy="socks5://$user:$pass@$ip:$port"
        local display_proxy="${ip}:${port}@${user}"
        
        if [[ ${#display_proxy} -gt 25 ]]; then
            display_proxy="${display_proxy:0:22}..."
        fi
        
        local progress_indicator=$(printf "[%2d/%2d]" $proxy_num $total_proxies)
        
        # Test proxy connectivity first
        if ! timeout 10 curl -s --proxy "$curl_proxy" --connect-timeout 5 -I http://httpbin.org/ip >/dev/null 2>&1; then
            printf "${CYAN}${NC} %s %-25s ${RED}✗ CONNECTION FAILED${NC}%*s${CYAN}${NC}\n" \
                "$progress_indicator" "$display_proxy" 30 ""
            return
        fi
        
        # Test speed with multiple servers
        local total_speed=0
        local valid_tests=0
        
        for server in "${proxy_test_servers[@]}"; do
            local speed_result=$(timeout 15 curl -s -w "%{speed_download}" -o /dev/null --proxy "$curl_proxy" --connect-timeout 8 --max-time 20 "$server" 2>/dev/null)
            
            if [[ "$speed_result" =~ ^[0-9]+\.?[0-9]*$ ]] && (( $(echo "$speed_result > 0" | bc -l 2>/dev/null || echo "0") )); then
                local speed_mbps=$(echo "scale=2; $speed_result / 1024 / 1024 * 8" | bc -l 2>/dev/null || echo "0")
                total_speed=$(echo "$total_speed + $speed_mbps" | bc -l 2>/dev/null || echo "0")
                ((valid_tests++))
            fi
        done
        
        if [[ $valid_tests -gt 0 ]]; then
            local avg_speed=$(echo "scale=2; $total_speed / $valid_tests" | bc -l 2>/dev/null || echo "0")
            local speed_percentage=$(echo "scale=1; $avg_speed * 100 / $direct_speed" | bc -l 2>/dev/null || echo "0")
            
            # Color code based on performance
            local speed_color=$GREEN
            if (( $(echo "$speed_percentage < 50" | bc -l 2>/dev/null || echo "0") )); then
                speed_color=$RED
            elif (( $(echo "$speed_percentage < 80" | bc -l 2>/dev/null || echo "0") )); then
                speed_color=$YELLOW
            fi
            
            printf "${CYAN}${NC} %s %-25s ${speed_color}%s${NC} (${speed_color}%.1f%%${NC})%*s${CYAN}${NC}\n" \
                "$progress_indicator" "$display_proxy" "$(format_speed $avg_speed)" "$speed_percentage" 15 ""
        else
            printf "${CYAN}${NC} %s %-25s ${RED}✗ SPEED TEST FAILED${NC}%*s${CYAN}${NC}\n" \
                "$progress_indicator" "$display_proxy" 20 ""
        fi
    }
    
    # Display results header
    echo -e "${CYAN}┌─ Proxy Speed Test Results ───────────────────────────────────────────────────┐${NC}"
    printf "${CYAN}${NC} Direct Speed: ${GREEN}%s${NC}%*s${CYAN}${NC}\n" "$(format_speed $direct_speed)" 60 ""
    echo -e "${CYAN}├──────────────────────────────────────────────────────────────────────────────┤${NC}"
    
    # Test each proxy
    for i in "${!proxies[@]}"; do
        test_single_proxy "${proxies[i]}" $((i+1)) ${#proxies[@]}
    done
    
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    # Legend
    echo
    echo -e "${GRAY}Explanation:${NC}"
    echo -e "  ${GREEN}Green${NC}: 80-100% of direct speed"
    echo -e "  ${YELLOW}Yellow${NC}: 50-79% of direct speed"
    echo -e "  ${RED}Red${NC}: Below 50% of direct speed"
}

# Function to install Danted
install_danted() {
    print_header
    print_section_header "Install Danted SOCKS5 Proxy Server"    
    
    # Check if already installed
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        print_warning "Danted is already installed and running."
        echo -e "${YELLOW}You can reinstall it, but this will stop the current service.${NC}"
        read -p "$(echo -e "${YELLOW}❯${NC} Do you want to reinstall? (Y/N): ")" reinstall
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
    print_info_box "Installing Danted SOCKS5 Proxy Server. Please wait..."
    
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

# Network configuration
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
        # Empty state with proper box formatting
        echo -e "${CYAN}┌─ Users List (0 users) ───────────────────────────────────────────────────────┐${NC}"
        local warning_msg="No SOCKS5 users found."
        local warning_length=$((${#warning_msg} + 1))
        local warning_padding=$((78 - warning_length))
        printf "${CYAN}│${NC} ${YELLOW}%s${NC}%*s${CYAN}│${NC}\n" "$warning_msg" $warning_padding ""
        echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    else
        # Header with user count
        local header_title="Users List (${#users[@]} users)"
        local header_length=${#header_title}
        local header_padding=$((77 - header_length))  # 78 - 6 (for "─ " and " ") = 69

        printf "${CYAN}┌ %s" "$header_title"
        for ((i=0; i<$header_padding; i++)); do printf "─"; done
        printf "┐${NC}\n"

        # Display users with proper formatting
        for i in "${!users[@]}"; do
            local user_number=$(printf "%3d." $((i+1)))
            local user_display="$user_number ${users[i]}"
            local user_length=$((${#user_display} + 1))  # +1 for leading space
            local user_padding=$((78 - user_length))

            printf "${CYAN}│${NC} %s%*s${CYAN}│${NC}\n" "$user_display" $user_padding ""
        done

        echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
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
            internal_line=$(grep -E "^[[:space:]]*internal:" "$DANTED_CONFIG" | head -1)
            if [ -n "$internal_line" ]; then
                SELECTED_IP=$(echo "$internal_line" | sed -n 's/.*internal:[[:space:]]*\([^[:space:]]*\).*/\1/p' | sed 's/port=.*//')
                SELECTED_PORT=$(echo "$internal_line" | sed -n 's/.*port[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
            fi
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
      "tag": "proxy-csol",
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
#add_single_user() {
#    print_header
#    print_section_header "Add Single User"
    
#    while true; do
#        read -p "$(echo -e "${YELLOW}❯${NC} Enter username: ")" username
#        if [[ -n "$username" && "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
#            if id "$username" &>/dev/null; then
#                print_error "User '$username' already exists!"
#            else
#                break
#            fi
#        else
#            print_error "Invalid username. Use only letters, numbers, underscore and dash."
#        fi
#    done
    
#    while true; do
#        read -s -p "$(echo -e "${YELLOW}❯${NC} Enter password: ")" password
#        echo
#        if [[ ${#password} -ge 4 ]]; then
#            read -s -p "$(echo -e "${YELLOW}❯${NC} Confirm password: ")" password2
#            echo
#            if [[ "$password" == "$password2" ]]; then
#                break
#            else
#                print_error "Passwords don't match!"
#            fi
#        else
#            print_error "Password must be at least 4 characters long!"
#        fi
#    done
    
#    echo
#    print_color $YELLOW "Creating user..."
    
    # Create user
#    if useradd -r -s /bin/false "$username"; then
#        echo "$username:$password" | chpasswd
#        create_user_config "$username" "$password"
#        print_success "User '$username' created successfully!"
#        print_success "Config file created: $CONFIG_DIR/$username"
#    else
#        print_error "Failed to create user '$username'!"
#    fi
    
#    echo
#    read -p "Press Enter to continue..."
#}

# Function to add multiple users
add_multi_users() {
    print_header
    print_section_header "Add Multiple Users"

    echo -e "${GRAY}Enter data (Enter 1 user per line, press Enter twice to finish):${NC}"
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
#manage_add_users() {
#    while true; do
#        print_header
#        print_section_header "Add Users Menu"

#    echo -e "${CYAN}┌─ Add Users Options ──────────────────────────────────────────────────────────┐${NC}"

#    local add_user_items=(
#        "1. Add single user"
#        "2. Add multiple users"
#        "3. Back to main menu"
#    )

#    for item in "${add_user_items[@]}"; do
#        local item_length=$((${#item} + 1))  # +1 for leading space
#        local item_padding=$((78 - item_length))
#        printf "${CYAN}│${NC} ${GREEN}%s${NC}%*s${CYAN}│${NC}\n" "$item" $item_padding ""
#    done

#    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
#    echo

#        read -p "$(echo -e "${YELLOW}❯${NC} Select option [1-3]: ")" choice
        
#        case $choice in
#            1) add_single_user ;;
#            2) add_multi_users ;;
#            3) break ;;
#            *) print_error "Invalid option!" ;;
#        esac
#    done
#}

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

    echo
    echo -e "${CYAN}┌─ Available Users to Delete ──────────────────────────────────────────────────┐${NC}"
    for i in "${!users[@]}"; do
        local user_number=$(printf "%3d." $((i+1)))
        local user_display="$user_number ${users[i]}"
        local user_length=$((${#user_display} + 1))  # +1 for leading space
        local user_padding=$((78 - user_length))
        
        printf "${CYAN}│${NC} %s%*s${CYAN}│${NC}\n" "$user_display" $user_padding ""
    done
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
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
    read -p "$(echo -e "${RED}❯${NC} Are you sure you want to delete these users? (Y/N): ")" confirm
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
#test_proxies() {
#    clear
#    print_header
#    print_section_header "Test Proxies"
    
    # Show format example clearly
#    echo -e "${YELLOW}Format: ${WHITE}IP:PORT:USERNAME:PASSWORD${NC}"
#    echo -e "${GRAY}Example:${NC}"
#    echo -e "  ${CYAN}100.150.200.250:30500:user1:pass123${NC}"
#    echo -e "  ${CYAN}192.168.1.100:1080:alice:secret456${NC}"
#    echo -e "${GRAY}Enter one proxy per line, Press Enter twice to finish.${NC}"
#    echo
    
    # Read proxy list using multiline input
#    local proxies_input
    # Redirect stderr to display feedback, capture only stdout (pure data)
#    exec 3>&1 4>&2
#    proxies_input=$(read_multiline_input "Enter proxy list:" 2>&4)
#    exec 3>&- 4>&-
    
#    if [[ -z "$proxies_input" ]]; then
#        print_error "No proxies provided!"
#        read -p "Press Enter to continue..."
#        return
#    fi
    
#    echo
    
    # Parse proxies with silent validation (no error messages)
#    local proxies=()
#   local line_num=0
#    local valid_count=0
#    local invalid_count=0
    
    # Process each line from input
#    while IFS= read -r proxy_line; do
#        ((line_num++))
        
        # Skip empty lines
#        if [[ -z "$proxy_line" ]]; then
#            continue
#        fi
        
        # Trim whitespace
#        proxy_line=$(echo "$proxy_line" | xargs)
        
        # Skip if still empty after trim
#        if [[ -z "$proxy_line" ]]; then
#            continue
#        fi
        
        # Simple validation: count colons and check basic format
#        local colon_count=$(echo "$proxy_line" | tr -cd ':' | wc -c)
        
#        if [[ $colon_count -eq 3 ]]; then
            # Split and validate components
#            IFS=':' read -r ip port user pass <<< "$proxy_line"
            
            # Check if all components exist and port is numeric
#            if [[ -n "$ip" && -n "$port" && -n "$user" && -n "$pass" ]]; then
#                if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
                    # Check for duplicates in proxies array
#                    local is_duplicate=false
#                    for existing_proxy in "${proxies[@]}"; do
#                        if [[ "$existing_proxy" == "$proxy_line" ]]; then
#                            is_duplicate=true
#                            break
#                        fi
#                    done
                    
#                    if [[ "$is_duplicate" == false ]]; then
#                        proxies+=("$proxy_line")
#                        ((valid_count++))
#                        print_color $GREEN "  ✓ Valid: $proxy_line"
#                    fi
#                else
#                    ((invalid_count++))
#                fi
#            else
#                ((invalid_count++))
#            fi
#        else
#            ((invalid_count++))
#        fi
        
#    done <<< "$proxies_input"
    
    # Show summary instead of detailed errors
#    if [[ $invalid_count -gt 0 ]]; then
#        print_warning "Skipped $invalid_count invalid proxy entries"
#    fi
    
#    if [[ ${#proxies[@]} -eq 0 ]]; then
#        print_error "No valid proxies provided!"
#        if [[ $invalid_count -gt 0 ]]; then
#            echo -e "${GRAY}Check proxy format: IP:PORT:USERNAME:PASSWORD${NC}"
#        fi
#        read -p "Press Enter to continue..."
#        return
#    fi
    
#    echo
#    print_color $CYAN "Testing ${#proxies[@]} proxies..."
#    print_color $CYAN "Please wait..."   
#    echo
    
#    local success_count=0
#    local total_count=${#proxies[@]}
    
# Proxy test results with proper box formatting
#    echo -e "${CYAN}┌─ Proxy Test Results ─────────────────────────────────────────────────────────┐${NC}"

#    for i in "${!proxies[@]}"; do
#        local proxy="${proxies[i]}"
        
        # Parse proxy components
#        IFS=':' read -r ip port user pass <<< "$proxy"
        
#        local curl_proxy="socks5://$user:$pass@$ip:$port"
        
        # Test with timeout
#        local display_proxy="${ip}:${port}@${user}"
#        if [[ ${#display_proxy} -gt 30 ]]; then
#            display_proxy="${display_proxy:0:27}..."
#        fi
        
        # Create progress indicator
#        local progress_indicator=$(printf "[%2d/%2d]" $((i+1)) $total_count)
        
        # Test proxy first
#        if timeout 10 curl -s --proxy "$curl_proxy" --connect-timeout 5 -I http://httpbin.org/ip >/dev/null 2>&1; then
#            local result_text="${GREEN}✓ SUCCESS${NC}"
#            ((success_count++))
#        else
#            local result_text="${RED}✗ FAILED${NC}"
#        fi
        
        # Calculate padding based on actual text length (không tính mã màu)
#        local progress_len=${#progress_indicator}
#        local proxy_len=${#display_proxy}
        # Độ dài thực tế của result_text không tính mã màu
#        local result_len=8  # "✓ SUCCESS" hoặc "✗ FAILED" đều 8 ký tự
        
        # Total content: " " + progress + " " + proxy + " " + result + " "
#        local total_content_len=$((1 + progress_len + 1 + proxy_len + 1 + result_len + 1))
#        local padding=$((78 - total_content_len))
        
        # Print the formatted line
#        printf "${CYAN}${NC} %s %-30s %b%*s${CYAN}${NC}\n" \
#            "$progress_indicator" "$display_proxy" "$result_text" $padding ""
        
#    done

#    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    
#    local success_rate=0
#    if [[ $total_count -gt 0 ]]; then
#        success_rate=$((success_count * 100 / total_count))
#    fi
    
#    echo
#    echo -e "${CYAN}┌─ Test Summary ───────────────────────────────────────────────────────────────┐${NC}"

    # Total Proxies
#    local total_text="Total Proxies: $total_count"
#    local total_length=$((${#total_text} + 1))
#    local total_padding=$((78 - total_length))
#    printf "${CYAN}${NC} Total Proxies:   ${WHITE}%s${NC}%*s${CYAN}${NC}\n" "$total_count" $total_padding ""

    # Successful
#    local success_text="Successful: $success_count"
#    local success_length=$((${#success_text} + 1))
#    local success_padding=$((78 - success_length))
#    printf "${CYAN}${NC} Successful:      ${GREEN}%s${NC}%*s${CYAN}${NC}\n" "$success_count" $success_padding ""

    # Failed
#    local failed_count=$((total_count - success_count))
#    local failed_text="Failed: $failed_count"
#    local failed_length=$((${#failed_text} + 1))
#    local failed_padding=$((78 - failed_length))
#    printf "${CYAN}${NC} Failed:          ${RED}%s${NC}%*s${CYAN}${NC}\n" "$failed_count" $failed_padding ""

    # Success Rate
#    local rate_text="Success Rate: ${success_rate}%"
#    local rate_length=$((${#rate_text} + 1))
#    local rate_padding=$((78 - rate_length))
#    printf "${CYAN}${NC} Success Rate:    ${YELLOW}%s%%${NC}%*s${CYAN}${NC}\n" "$success_rate" $rate_padding ""

#    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    
#    echo
#    read -p "Press Enter to continue..."
#}

# Function to uninstall Danted
uninstall_danted() {
    print_header
    print_section_header "Uninstall Danted"
    
    echo -e "${RED}┌─ WARNING ────────────────────────────────────────────────────────────────────┐${NC}"

    # First warning line
    local warning1="This will completely remove Danted and all configurations!"
    local warning1_length=$((${#warning1} + 1))
    local warning1_padding=$((78 - warning1_length))
    printf "${RED}│${NC} %s%*s${RED}│${NC}\n" "$warning1" $warning1_padding ""

    # Second warning line
    local warning2="All proxy users and config files will be affected."
    local warning2_length=$((${#warning2} + 1))
    local warning2_padding=$((78 - warning2_length))
    printf "${RED}│${NC} %s%*s${RED}│${NC}\n" "$warning2" $warning2_padding ""

    echo -e "${RED}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    echo
    read -p "$(echo -e "${RED}❯${NC} Are you sure you want to uninstall Danted? (Y/N): ")" confirm
    
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
        read -p "$(echo -e "${YELLOW}❯${NC} Do you want to remove all user config files in '$CONFIG_DIR'? (Y/N): ")" remove_configs
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
    
    #if [[ ${#socks_users[@]} -gt 0 ]]; then
    #    echo
    #    print_warning "Found ${#socks_users[@]} SOCKS5 users:"
    #    for user in "${socks_users[@]}"; do
    #        echo -e "  ${YELLOW}•${NC} $user"
    #    done
    #    echo
    #    read -p "$(echo -e "${YELLOW}❯${NC} Do you want to remove all SOCKS5 users? (Y/N): ")" remove_users
    #    if [[ "$remove_users" =~ ^[Yy]$ ]]; then
    #        for user in "${socks_users[@]}"; do
    #            userdel "$user" 2>/dev/null
    #            print_success "Removed user: $user"
    #        done
    #    fi
    #fi
    
    echo
    print_success "Danted has been completely uninstalled!"
    
    echo
    read -p "Press Enter to continue..."
}

# Main menu function
# Main menu function
show_main_menu() {
    print_header
    print_section_header "Main Menu"
    
    # Menu box with rounded corners
    echo -e "${YELLOW}┌─ Menu Options ───────────────────────────────────────────────────────────────┐${NC}"
    
    # Menu items with proper padding
    local menu_items=(
        "1. Install Danted SOCKS5 Proxy"
        "2. Show Users"
        "3. Add Users"
        "4. Delete Users"
        #"5. Test Proxies"
        "5. Check Status & Monitoring"
        "6. Uninstall Danted"
        "7. Exit"
    )
    
    for item in "${menu_items[@]}"; do
        local item_length=$((${#item} + 1))  # +1 for leading space
        local item_padding=$((78 - item_length))
        printf "${YELLOW}│${NC} ${CYAN}%s${NC}%*s${YELLOW}│${NC}\n" "$item" $item_padding ""
    done
    
    echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
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
        read -p "$(echo -e "${YELLOW}❯${NC} Select option [1-7]: ")" choice
        
        case $choice in
            1) install_danted ;;
            2) show_users ;;
            3) add_multi_users ;;
            4) delete_users ;;
            #5) test_proxies ;;
            5) check_service_status ;;
            6) uninstall_danted ;;
            7) 
                # Clear screen and show thank you message
                clear
                print_header
                print_section_header "Thank you for using Danted SOCKS5 Proxy Manager!"
                echo
                exit 0
                ;;
            *) 
                print_error "Invalid option! Please select 1-7."
                sleep 1
                ;;
        esac
    done
}

# Run main function
main "$@"
