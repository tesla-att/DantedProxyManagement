#!/bin/bash
# Optimized Danted SOCKS5 Proxy Manager
# Enhanced version with better error handling and performance

# Colors and formatting
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [PURPLE]='\033[0;35m'
    [CYAN]='\033[0;36m'
    [WHITE]='\033[1;37m'
    [NC]='\033[0m'
)

# Configuration
readonly DANTED_CONFIG="/etc/danted.conf"
readonly CONFIG_DIR="configFiles"
readonly DANTED_SERVICE="danted"
readonly LOG_FILE="/var/log/danted_manager.log"

# Global variables
SELECTED_IP=""
SELECTED_PORT=""

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# Enhanced print function with logging
print_color() {
    local color="$1"
    local message="$2"
    local log_level="${3:-INFO}"
    
    echo -e "${COLORS[$color]}${message}${COLORS[NC]}"
    log_message "$log_level" "$message"
}

# Improved error handling
handle_error() {
    local exit_code="$1"
    local error_message="$2"
    
    if [[ $exit_code -ne 0 ]]; then
        print_color "RED" "ERROR: $error_message" "ERROR"
        return 1
    fi
    return 0
}

# Optimized network interface detection
get_network_interfaces() {
    print_color "YELLOW" "Detecting network interfaces..."
    
    local -a interfaces=()
    local -a ips=()
    local counter=1
    
    # More efficient interface detection
    while read -r interface ip; do
        if [[ "$interface" != "lo" && "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            interfaces+=("$interface")
            ips+=("$ip")
            printf "%2d. %-15s %s\n" $counter "$interface" "$ip"
            ((counter++))
        fi
    done < <(ip -4 addr show | awk '/^[0-9]+:/ {iface=substr($2,1,length($2)-1)} /inet / && !/127\.0\.0\.1/ {print iface, $2}' | cut -d'/' -f1)
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        print_color "RED" "No suitable network interfaces found!" "ERROR"
        return 1
    fi
    
    # Input validation with timeout
    local choice
    while true; do
        read -t 30 -p "Select interface number (timeout 30s): " choice || {
            print_color "YELLOW" "Input timeout, using first interface"
            choice=1
            break
        }
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#interfaces[@]} ]]; then
            SELECTED_IP="${ips[$((choice-1))]}"
            print_color "GREEN" "Selected: ${interfaces[$((choice-1))]} - $SELECTED_IP"
            break
        else
            print_color "RED" "Invalid selection. Please try again."
        fi
    done
    
    return 0
}

# Enhanced installation with dependency check
install_danted() {
    print_color "WHITE" "Starting Danted installation process..."
    
    # Check system requirements
    if ! command -v systemctl &> /dev/null; then
        print_color "RED" "systemctl not found. This script requires systemd." "ERROR"
        return 1
    fi
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_color "RED" "This script must be run as root" "ERROR"
        return 1
    fi
    
    # Service status check
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        print_color "YELLOW" "Danted is already running."
        read -p "Reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
        systemctl stop $DANTED_SERVICE
    fi
    
    # Network configuration
    get_network_interfaces || return 1
    
    # Port configuration with validation
    while true; do
        read -p "Enter SOCKS5 port (1080): " port
        port=${port:-1080}
        
        if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1024 ]] && [[ $port -le 65535 ]]; then
            if ! ss -tuln | grep -q ":$port "; then
                SELECTED_PORT="$port"
                break
            else
                print_color "RED" "Port $port is in use. Choose another."
            fi
        else
            print_color "RED" "Invalid port. Use 1024-65535."
        fi
    done
    
    # Installation process
    print_color "YELLOW" "Installing dependencies..."
    
    # Update package cache
    apt update -qq || handle_error $? "Failed to update package cache"
    
    # Install Dante server
    if ! apt install -y dante-server; then
        handle_error 1 "Failed to install dante-server"
        return 1
    fi
    
    # Create optimized configuration
    create_danted_config || return 1
    
    # Service management
    systemctl daemon-reload
    systemctl enable $DANTED_SERVICE
    systemctl restart $DANTED_SERVICE
    
    # Verification
    sleep 3
    if systemctl is-active --quiet $DANTED_SERVICE; then
        print_color "GREEN" "✓ Danted installed successfully!"
        print_color "GREEN" "✓ Listening on: $SELECTED_IP:$SELECTED_PORT"
        show_service_status
    else
        print_color "RED" "✗ Service failed to start"
        journalctl -u $DANTED_SERVICE --no-pager -n 10
        return 1
    fi
}

# Optimized configuration creation
create_danted_config() {
    print_color "YELLOW" "Creating optimized configuration..."
    
    # Backup existing config
    [[ -f "$DANTED_CONFIG" ]] && cp "$DANTED_CONFIG" "${DANTED_CONFIG}.backup.$(date +%s)"
    
    # Create new configuration with better performance settings
    cat > "$DANTED_CONFIG" << EOF
# Optimized Danted SOCKS5 Configuration
# Generated by Danted Manager on $(date)

# Logging
logoutput: /var/log/danted.log
debug: 0

# Network settings
internal: $SELECTED_IP port = $SELECTED_PORT
external: $SELECTED_IP

# Performance tuning
timeout.connect: 30
timeout.io: 86400
timeout.negotiate: 30

# Authentication
socksmethod: username

# User privileges
user.privileged: root
user.unprivileged: nobody

# Client access rules
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
}

# SOCKS rules with optimizations
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: error connect disconnect
    socksmethod: username
}

# Block rules for security
socks block {
    from: 0.0.0.0/0 to: 127.0.0.0/8
    log: connect error
}

socks block {
    from: 0.0.0.0/0 to: 10.0.0.0/8
    log: connect error
}
EOF

    print_color "GREEN" "Configuration created successfully"
    return 0
}

# Enhanced user management
manage_users() {
    local action="$1"
    
    case "$action" in
        "list")
            print_color "WHITE" "SOCKS5 Proxy Users:"
            local users=()
            while IFS= read -r user; do
                if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
                    users+=("$user")
                fi
            done < <(getent passwd | grep '/bin/false' | cut -d: -f1 | sort)
            
            if [[ ${#users[@]} -eq 0 ]]; then
                print_color "YELLOW" "No SOCKS5 users found."
            else
                print_color "GREEN" "Found ${#users[@]} users:"
                printf '%s\n' "${users[@]}" | nl
            fi
            ;;
        "add")
            add_socks_user
            ;;
        "delete")
            delete_socks_user
            ;;
    esac
}

# Improved user creation
add_socks_user() {
    local username password
    
    read -p "Enter username: " username
    if [[ -z "$username" || ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_color "RED" "Invalid username format"
        return 1
    fi
    
    if id "$username" &>/dev/null; then
        print_color "RED" "User already exists"
        return 1
    fi
    
    read -s -p "Enter password: " password
    echo
    if [[ ${#password} -lt 6 ]]; then
        print_color "RED" "Password must be at least 6 characters"
        return 1
    fi
    
    # Create user with restricted shell
    if useradd -r -s /bin/false "$username" && echo "$username:$password" | chpasswd; then
        print_color "GREEN" "✓ User '$username' created successfully"
        create_user_config "$username" "$password"
    else
        print_color "RED" "Failed to create user"
        return 1
    fi
}

# Service status display
show_service_status() {
    print_color "CYAN" "=== Service Status ==="
    
    if systemctl is-active --quiet $DANTED_SERVICE; then
        print_color "GREEN" "Status: Active"
        print_color "GREEN" "Uptime: $(systemctl show -p ActiveEnterTimestamp $DANTED_SERVICE --value)"
        
        # Show listening ports
        local listening_ports
        listening_ports=$(ss -tuln | grep ":$SELECTED_PORT")
        if [[ -n "$listening_ports" ]]; then
            print_color "GREEN" "Listening: $listening_ports"
        fi
        
        # Show connection count
        local connections
        connections=$(ss -tn | grep -c ":$SELECTED_PORT")
        print_color "BLUE" "Active connections: $connections"
    else
        print_color "RED" "Status: Inactive"
    fi
}

# Performance monitoring
show_performance_stats() {
    print_color "CYAN" "=== Performance Statistics ==="
    
    # Memory usage
    local memory_usage
    memory_usage=$(ps -o pid,vsz,rss,comm -p "$(pgrep danted)" 2>/dev/null)
    if [[ -n "$memory_usage" ]]; then
        print_color "BLUE" "Memory Usage:"
        echo "$memory_usage"
    fi
    
    # Log analysis
    if [[ -f "/var/log/danted.log" ]]; then
        local log_lines
        log_lines=$(wc -l < "/var/log/danted.log")
        print_color "BLUE" "Log entries: $log_lines"
        
        # Recent connections
        print_color "BLUE" "Recent activity (last 10 entries):"
        tail -n 10 "/var/log/danted.log" | while read -r line; do
            echo "  $line"
        done
    fi
}

# Main menu with improved UX
show_menu() {
    clear
    print_color "CYAN" "================================================================"
    print_color "CYAN" "           OPTIMIZED DANTED SOCKS5 PROXY MANAGER"
    print_color "CYAN" "================================================================"
    echo
    print_color "WHITE" "1. Install/Reinstall Danted"
    print_color "WHITE" "2. Show Service Status"
    print_color "WHITE" "3. List Users"
    print_color "WHITE" "4. Add User"
    print_color "WHITE" "5. Delete User"
    print_color "WHITE" "6. Performance Stats"
    print_color "WHITE" "7. View Logs"
    print_color "WHITE" "8. Restart Service"
    print_color "WHITE" "9. Stop Service"
    print_color "WHITE" "0. Exit"
    echo
}

# Main execution
main() {
    # Create necessary directories
    mkdir -p "$CONFIG_DIR"
    touch "$LOG_FILE"
    
    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
        print_color "RED" "This script requires root privileges"
        exit 1
    fi
    
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case $choice in
            1) install_danted ;;
            2) show_service_status ;;
            3) manage_users "list" ;;
            4) manage_users "add" ;;
            5) manage_users "delete" ;;
            6) show_performance_stats ;;
            7) [[ -f "/var/log/danted.log" ]] && tail -f "/var/log/danted.log" || print_color "RED" "Log file not found" ;;
            8) systemctl restart $DANTED_SERVICE && print_color "GREEN" "Service restarted" ;;
            9) systemctl stop $DANTED_SERVICE && print_color "YELLOW" "Service stopped" ;;
            0) print_color "GREEN" "Goodbye!"; exit 0 ;;
            *) print_color "RED" "Invalid option" ;;
        esac
        
        [[ $choice != 7 ]] && read -p "Press Enter to continue..."
    done
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
