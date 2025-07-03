#!/bin/bash
# Optimized Danted SOCKS5 Proxy Manager - Fixed Version
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
readonly DANTED_LOG="/var/log/danted.log"

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

# NEW: Uninstall Danted function
uninstall_danted() {
    print_color "WHITE" "Starting Danted uninstallation process..."
    
    # Confirmation
    print_color "YELLOW" "This will completely remove Danted and all configurations."
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_color "YELLOW" "Uninstallation cancelled."
        return 0
    fi
    
    # Stop and disable service
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        print_color "YELLOW" "Stopping Danted service..."
        systemctl stop $DANTED_SERVICE
        systemctl disable $DANTED_SERVICE
    fi
    
    # Remove package
    print_color "YELLOW" "Removing dante-server package..."
    apt remove --purge -y dante-server
    
    # Remove configuration files
    print_color "YELLOW" "Removing configuration files..."
    [[ -f "$DANTED_CONFIG" ]] && rm -f "$DANTED_CONFIG"
    [[ -f "${DANTED_CONFIG}.backup"* ]] && rm -f "${DANTED_CONFIG}.backup"*
    
    # Remove log files
    [[ -f "$DANTED_LOG" ]] && rm -f "$DANTED_LOG"
    
    # Remove SOCKS users
    print_color "YELLOW" "Removing SOCKS users..."
    local socks_users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            socks_users+=("$user")
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1)
    
    for user in "${socks_users[@]}"; do
        if [[ "$user" != "nobody" && "$user" != "daemon" ]]; then
            userdel "$user" 2>/dev/null && print_color "GREEN" "Removed user: $user"
        fi
    done
    
    # Clean up
    systemctl daemon-reload
    
    print_color "GREEN" "✓ Danted uninstalled successfully!"
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
logoutput: $DANTED_LOG
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

# FIXED: Delete user function
delete_socks_user() {
    print_color "WHITE" "Available SOCKS5 users:"
    local users=()
    local counter=1
    
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            if [[ "$user" != "nobody" && "$user" != "daemon" ]]; then
                users+=("$user")
                printf "%2d. %s\n" $counter "$user"
                ((counter++))
            fi
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1 | sort)
    
    if [[ ${#users[@]} -eq 0 ]]; then
        print_color "YELLOW" "No SOCKS5 users found to delete."
        return 0
    fi
    
    local choice
    while true; do
        read -p "Select user number to delete (0 to cancel): " choice
        
        if [[ "$choice" == "0" ]]; then
            print_color "YELLOW" "Operation cancelled."
            return 0
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#users[@]} ]]; then
            local username="${users[$((choice-1))]}"
            read -p "Delete user '$username'? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if userdel "$username"; then
                    print_color "GREEN" "✓ User '$username' deleted successfully"
                    # Remove user config if exists
                    [[ -f "$CONFIG_DIR/${username}_config.txt" ]] && rm -f "$CONFIG_DIR/${username}_config.txt"
                else
                    print_color "RED" "Failed to delete user '$username'"
                fi
            fi
            break
        else
            print_color "RED" "Invalid selection. Please try again."
        fi
    done
}

# FIXED: Create user config function
create_user_config() {
    local username="$1"
    local password="$2"
    
    # Create config directory if not exists
    mkdir -p "$CONFIG_DIR"
    
    # Create user configuration file
    cat > "$CONFIG_DIR/${username}_config.txt" << EOF
# SOCKS5 Proxy Configuration for user: $username
# Generated on: $(date)

Server: $SELECTED_IP
Port: $SELECTED_PORT
Username: $username
Password: $password
Protocol: SOCKS5

# Usage examples:
# curl -x socks5://$username:$password@$SELECTED_IP:$SELECTED_PORT https://httpbin.org/ip
# proxychains4 -f /path/to/proxychains.conf your_command
EOF
    
    print_color "GREEN" "✓ Configuration saved to: $CONFIG_DIR/${username}_config.txt"
}

# Service status display
show_service_status() {
    print_color "CYAN" "=== Service Status ==="
    
    if systemctl is-active --quiet $DANTED_SERVICE; then
        print_color "GREEN" "Status: Active"
        
        # Get service info
        local uptime=$(systemctl show -p ActiveEnterTimestamp $DANTED_SERVICE --value)
        if [[ -n "$uptime" ]]; then
            print_color "GREEN" "Started: $uptime"
        fi
        
        # Show listening ports
        local listening_info
        listening_info=$(ss -tuln | grep ":$SELECTED_PORT" 2>/dev/null || ss -tuln | grep danted 2>/dev/null)
        if [[ -n "$listening_info" ]]; then
            print_color "GREEN" "Listening ports:"
            echo "$listening_info" | while read -r line; do
                echo "  $line"
            done
        fi
        
        # Show connection count
        local connections
        connections=$(ss -tn 2>/dev/null | grep -c ":$SELECTED_PORT" 2>/dev/null || echo "0")
        print_color "BLUE" "Active connections: $connections"
        
        # Show process info
        local pid=$(pgrep danted 2>/dev/null)
        if [[ -n "$pid" ]]; then
            print_color "BLUE" "Process ID: $pid"
        fi
    else
        print_color "RED" "Status: Inactive"
        
        # Show recent errors if any
        local errors
        errors=$(journalctl -u $DANTED_SERVICE --no-pager -n 5 --since "1 hour ago" 2>/dev/null | grep -i error)
        if [[ -n "$errors" ]]; then
            print_color "RED" "Recent errors:"
            echo "$errors"
        fi
    fi
}

# FIXED: Performance monitoring
show_performance_stats() {
    print_color "CYAN" "=== Performance Statistics ==="
    
    # Check if service is running
    if ! systemctl is-active --quiet $DANTED_SERVICE; then
        print_color "RED" "Danted service is not running"
        return 1
    fi
    
    # Memory usage
    local pid=$(pgrep danted 2>/dev/null)
    if [[ -n "$pid" ]]; then
        print_color "BLUE" "Memory Usage:"
        ps -o pid,vsz,rss,pcpu,pmem,comm -p "$pid" 2>/dev/null | head -2
        echo
    fi
    
    # System load
    print_color "BLUE" "System Load:"
    uptime
    echo
    
    # Network connections
    print_color "BLUE" "Network Connections:"
    local port_info
    if [[ -n "$SELECTED_PORT" ]]; then
        port_info=$(ss -tn 2>/dev/null | grep ":$SELECTED_PORT")
    else
        port_info=$(ss -tn 2>/dev/null | grep danted)
    fi
    
    if [[ -n "$port_info" ]]; then
        echo "$port_info" | head -10
    else
        echo "No active connections found"
    fi
    echo
    
    # Log analysis
    if [[ -f "$DANTED_LOG" ]]; then
        local log_size=$(du -h "$DANTED_LOG" 2>/dev/null | cut -f1)
        local log_lines=$(wc -l < "$DANTED_LOG" 2>/dev/null)
        print_color "BLUE" "Log Statistics:"
        echo "  File size: $log_size"
        echo "  Total lines: $log_lines"
        
        # Recent activity count
        local recent_connections=$(grep -c "connect" "$DANTED_LOG" 2>/dev/null | tail -100 || echo "0")
        echo "  Recent connections: $recent_connections"
    else
        print_color "YELLOW" "Log file not found: $DANTED_LOG"
    fi
}

# FIXED: View logs function
view_logs() {
    print_color "CYAN" "=== Danted Logs ==="
    
    if [[ ! -f "$DANTED_LOG" ]]; then
        print_color "RED" "Log file not found: $DANTED_LOG"
        print_color "YELLOW" "Checking system journal instead..."
        journalctl -u $DANTED_SERVICE --no-pager -n 20
        return 1
    fi
    
    print_color "BLUE" "Choose log view option:"
    echo "1. View last 20 lines"
    echo "2. View last 50 lines"
    echo "3. Follow log (real-time)"
    echo "4. Search in logs"
    echo "5. View system journal"
    
    read -p "Select option (1-5): " log_choice
    
    case $log_choice in
        1)
            print_color "GREEN" "Last 20 lines:"
            tail -n 20 "$DANTED_LOG"
            ;;
        2)
            print_color "GREEN" "Last 50 lines:"
            tail -n 50 "$DANTED_LOG"
            ;;
        3)
            print_color "GREEN" "Following log (Press Ctrl+C to stop):"
            tail -f "$DANTED_LOG"
            ;;
        4)
            read -p "Enter search term: " search_term
            if [[ -n "$search_term" ]]; then
                print_color "GREEN" "Search results for '$search_term':"
                grep -i "$search_term" "$DANTED_LOG" | tail -20
            fi
            ;;
        5)
            print_color "GREEN" "System journal for danted:"
            journalctl -u $DANTED_SERVICE --no-pager -n 30
            ;;
        *)
            print_color "RED" "Invalid option"
            ;;
    esac
}

# Service management functions
restart_service() {
    print_color "YELLOW" "Restarting Danted service..."
    if systemctl restart $DANTED_SERVICE; then
        sleep 2
        if systemctl is-active --quiet $DANTED_SERVICE; then
            print_color "GREEN" "✓ Service restarted successfully"
            show_service_status
        else
            print_color "RED" "✗ Service failed to start after restart"
            journalctl -u $DANTED_SERVICE --no-pager -n 10
        fi
    else
        print_color "RED" "Failed to restart service"
    fi
}

stop_service() {
    print_color "YELLOW" "Stopping Danted service..."
    if systemctl stop $DANTED_SERVICE; then
        print_color "GREEN" "✓ Service stopped successfully"
    else
        print_color "RED" "Failed to stop service"
    fi
}

start_service() {
    print_color "YELLOW" "Starting Danted service..."
    if systemctl start $DANTED_SERVICE; then
        sleep 2
        if systemctl is-active --quiet $DANTED_SERVICE; then
            print_color "GREEN" "✓ Service started successfully"
            show_service_status
        else
            print_color "RED" "✗ Service failed to start"
            journalctl -u $DANTED_SERVICE --no-pager -n 10
        fi
    else
        print_color "RED" "Failed to start service"
    fi
}

# NEW: Service configuration menu
service_config_menu() {
    while true; do
        clear
        print_color "CYAN" "================================================================"
        print_color "CYAN" "              DANTED SERVICE CONFIGURATION"
        print_color "CYAN" "================================================================"
        echo
        print_color "WHITE" "1. Show Service Status"
        print_color "WHITE" "2. Start Service"
        print_color "WHITE" "3. Stop Service"
        print_color "WHITE" "4. Restart Service"
        print_color "WHITE" "5. Performance Stats"
        print_color "WHITE" "6. View Logs"
        print_color "WHITE" "7. Enable Auto-start"
        print_color "WHITE" "8. Disable Auto-start"
        print_color "WHITE" "0. Back to Main Menu"
        echo
        
        read -p "Select option: " service_choice
        
        case $service_choice in
            1) show_service_status ;;
            2) start_service ;;
            3) stop_service ;;
            4) restart_service ;;
            5) show_performance_stats ;;
            6) view_logs ;;
            7) 
                systemctl enable $DANTED_SERVICE
                print_color "GREEN" "✓ Auto-start enabled"
                ;;
            8) 
                systemctl disable $DANTED_SERVICE
                print_color "YELLOW" "✓ Auto-start disabled"
                ;;
            0) break ;;
            *) print_color "RED" "Invalid option" ;;
        esac
        
        [[ $service_choice != 6 ]] && read -p "Press Enter to continue..."
    done
}

# Main menu with improved UX
show_menu() {
    clear
    print_color "CYAN" "================================================================"
    print_color "CYAN" "           OPTIMIZED DANTED SOCKS5 PROXY MANAGER"
    print_color "CYAN" "================================================================"
    echo
    print_color "WHITE" "1. Install/Reinstall Danted"
    print_color "WHITE" "2. Uninstall Danted"
    print_color "WHITE" "3. Danted Service Configuration"
    print_color "WHITE" "4. List Users"
    print_color "WHITE" "5. Add User"
    print_color "WHITE" "6. Delete User"
    print_color "WHITE" "0. Exit"
    echo
}

# Load current configuration
load_current_config() {
    if [[ -f "$DANTED_CONFIG" ]]; then
        SELECTED_IP=$(grep "^internal:" "$DANTED_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
        SELECTED_PORT=$(grep "^internal:" "$DANTED_CONFIG" 2>/dev/null | awk -F'=' '{print $2}' | tr -d ' ' | head -1)
    fi
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
    
    # Load current configuration
    load_current_config
    
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case $choice in
            1) install_danted ;;
            2) uninstall_danted ;;
            3) service_config_menu ;;
            4) manage_users "list" ;;
            5) manage_users "add" ;;
            6) manage_users "delete" ;;
            0) print_color "GREEN" "Goodbye!"; exit 0 ;;
            *) print_color "RED" "Invalid option" ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
