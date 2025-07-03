#!/bin/bash
# Danted SOCKS5 Proxy Manager - Enhanced Version
# Professional script for managing SOCKS5 proxy server on Ubuntu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration variables
DANTED_CONFIG="/etc/danted.conf"
CONFIG_DIR="configFiles"
DANTED_SERVICE="danted"
DANTED_LOG="/var/log/danted.log"
SELECTED_IP=""
SELECTED_PORT=""

# Create config directory if not exists
mkdir -p "$CONFIG_DIR"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print header
print_header() {
    clear
    print_color $CYAN "================================================================"
    print_color $CYAN "           DANTED SOCKS5 PROXY MANAGER - ENHANCED"
    print_color $CYAN "================================================================"
    echo
}

# Function to get network interfaces with IPs
get_network_interfaces() {
    print_color $YELLOW "Available Network Interfaces:"
    echo
    
    local interfaces=()
    local ips=()
    local counter=1
    
    while IFS= read -r line; do
        interface=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | awk '{print $2}')
        if [[ "$interface" != "lo" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            interfaces+=("$interface")
            ips+=("$ip")
            printf "%2d. %-15s %s\n" $counter "$interface" "$ip"
            ((counter++))
        fi
    done < <(ip -4 addr show | grep -oP '^\d+: \K\w+|inet \K[^/]+' | paste - -)
    
    echo
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        print_color $RED "No network interfaces found!"
        return 1
    fi
    
    while true; do
        read -p "Select interface number: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#interfaces[@]} ]]; then
            SELECTED_IP="${ips[$((choice-1))]}"
            print_color $GREEN "Selected: ${interfaces[$((choice-1))]} - $SELECTED_IP"
            break
        else
            print_color $RED "Invalid selection. Please try again."
        fi
    done
    return 0
}

# Function to install Danted
install_danted() {
    print_header
    print_color $WHITE "Installing Danted SOCKS5 Proxy Server"
    echo
    
    # Check if already installed
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        print_color $YELLOW "Danted is already installed and running."
        read -p "Do you want to reinstall? (y/N): " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return
        fi
        systemctl stop $DANTED_SERVICE 2>/dev/null
    fi
    
    # Get network interface
    if ! get_network_interfaces; then
        read -p "Press Enter to continue..."
        return
    fi
    
    # Get port
    while true; do
        read -p "Enter SOCKS5 port (default: 1080): " port
        port=${port:-1080}
        if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
            if ! netstat -tuln 2>/dev/null | grep -q ":$port "; then
                SELECTED_PORT="$port"
                break
            else
                print_color $RED "Port $port is already in use. Please choose another port."
            fi
        else
            print_color $RED "Invalid port number. Please enter a number between 1-65535."
        fi
    done
    
    print_color $YELLOW "Installing Danted..."
    
    # Update package list
    apt update -qq
    
    # Install Danted
    if ! apt install -y dante-server >/dev/null 2>&1; then
        print_color $RED "Failed to install Danted!"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Create Danted configuration with enhanced settings
    cat > "$DANTED_CONFIG" << EOF
# Danted SOCKS5 Proxy Configuration - Enhanced
# Generated on: $(date)

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

# Authentication methods
socksmethod: username

# User privileges
user.privileged: root
user.unprivileged: nobody

# Client rules
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
}

# SOCKS rules
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: error connect disconnect
    socksmethod: username
}

# Security rules
socks block {
    from: 0.0.0.0/0 to: 127.0.0.0/8
    log: connect error
}

socks block {
    from: 0.0.0.0/0 to: 10.0.0.0/8
    log: connect error
}
EOF
    
    # Enable and start service
    systemctl enable $DANTED_SERVICE >/dev/null 2>&1
    systemctl restart $DANTED_SERVICE
    
    # Check status
    sleep 2
    if systemctl is-active --quiet $DANTED_SERVICE; then
        print_color $GREEN "✓ Danted installed and started successfully!"
        print_color $GREEN "✓ Listening on: $SELECTED_IP:$SELECTED_PORT"
        print_color $GREEN "✓ Service status: Active"
        show_service_status
    else
        print_color $RED "✗ Failed to start Danted service!"
        print_color $YELLOW "Checking logs..."
        journalctl -u $DANTED_SERVICE --no-pager -n 10
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to uninstall Danted
uninstall_danted() {
    print_header
    print_color $WHITE "Uninstalling Danted SOCKS5 Proxy Server"
    echo
    
    print_color $YELLOW "This will completely remove Danted and all configurations."
    read -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_color $YELLOW "Uninstallation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Stop and disable service
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        print_color $YELLOW "Stopping Danted service..."
        systemctl stop $DANTED_SERVICE
        systemctl disable $DANTED_SERVICE
    fi
    
    # Remove package
    print_color $YELLOW "Removing dante-server package..."
    apt remove --purge -y dante-server >/dev/null 2>&1
    
    # Remove configuration files
    print_color $YELLOW "Removing configuration files..."
    [[ -f "$DANTED_CONFIG" ]] && rm -f "$DANTED_CONFIG"
    [[ -f "${DANTED_CONFIG}.backup"* ]] && rm -f "${DANTED_CONFIG}.backup"*
    
    # Remove log files
    [[ -f "$DANTED_LOG" ]] && rm -f "$DANTED_LOG"
    
    # Remove SOCKS users
    print_color $YELLOW "Removing SOCKS users..."
    local socks_users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            if [[ "$user" != "nobody" && "$user" != "daemon" ]]; then
                socks_users+=("$user")
            fi
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1)
    
    for user in "${socks_users[@]}"; do
        userdel "$user" 2>/dev/null && print_color $GREEN "Removed user: $user"
    done
    
    # Clean up config files
    [[ -d "$CONFIG_DIR" ]] && rm -rf "$CONFIG_DIR"
    
    systemctl daemon-reload
    
    print_color $GREEN "✓ Danted uninstalled successfully!"
    echo
    read -p "Press Enter to continue..."
}

# Service status display
show_service_status() {
    print_color $CYAN "=== Service Status ==="
    
    if systemctl is-active --quiet $DANTED_SERVICE; then
        print_color $GREEN "Status: Active"
        
        # Get service info
        local uptime=$(systemctl show -p ActiveEnterTimestamp $DANTED_SERVICE --value)
        if [[ -n "$uptime" ]]; then
            print_color $GREEN "Started: $uptime"
        fi
        
        # Show listening ports
        local listening_info
        listening_info=$(ss -tuln | grep ":$SELECTED_PORT" 2>/dev/null || ss -tuln | grep danted 2>/dev/null)
        if [[ -n "$listening_info" ]]; then
            print_color $GREEN "Listening ports:"
            echo "$listening_info" | while read -r line; do
                echo "  $line"
            done
        fi
        
        # Show connection count
        local connections
        connections=$(ss -tn 2>/dev/null | grep -c ":$SELECTED_PORT" 2>/dev/null || echo "0")
        print_color $BLUE "Active connections: $connections"
        
        # Show process info
        local pid=$(pgrep danted 2>/dev/null)
        if [[ -n "$pid" ]]; then
            print_color $BLUE "Process ID: $pid"
        fi
    else
        print_color $RED "Status: Inactive"
        
        # Show recent errors if any
        local errors
        errors=$(journalctl -u $DANTED_SERVICE --no-pager -n 5 --since "1 hour ago" 2>/dev/null | grep -i error)
        if [[ -n "$errors" ]]; then
            print_color $RED "Recent errors:"
            echo "$errors"
        fi
    fi
}

# Performance monitoring
show_performance_stats() {
    print_color $CYAN "=== Performance Statistics ==="
    
    # Check if service is running
    if ! systemctl is-active --quiet $DANTED_SERVICE; then
        print_color $RED "Danted service is not running"
        return 1
    fi
    
    # Memory usage
    local pid=$(pgrep danted 2>/dev/null)
    if [[ -n "$pid" ]]; then
        print_color $BLUE "Memory Usage:"
        ps -o pid,vsz,rss,pcpu,pmem,comm -p "$pid" 2>/dev/null | head -2
        echo
    fi
    
    # System load
    print_color $BLUE "System Load:"
    uptime
    echo
    
    # Network connections
    print_color $BLUE "Network Connections:"
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
        print_color $BLUE "Log Statistics:"
        echo "  File size: $log_size"
        echo "  Total lines: $log_lines"
        
        # Recent activity count
        local recent_connections=$(grep -c "connect" "$DANTED_LOG" 2>/dev/null | tail -100 || echo "0")
        echo "  Recent connections: $recent_connections"
    else
        print_color $YELLOW "Log file not found: $DANTED_LOG"
    fi
}

# View logs function
view_logs() {
    print_color $CYAN "=== Danted Logs ==="
    
    if [[ ! -f "$DANTED_LOG" ]]; then
        print_color $RED "Log file not found: $DANTED_LOG"
        print_color $YELLOW "Checking system journal instead..."
        journalctl -u $DANTED_SERVICE --no-pager -n 20
        return 1
    fi
    
    print_color $BLUE "Choose log view option:"
    echo "1. View last 20 lines"
    echo "2. View last 50 lines"
    echo "3. Follow log (real-time)"
    echo "4. Search in logs"
    echo "5. View system journal"
    
    read -p "Select option (1-5): " log_choice
    
    case $log_choice in
        1)
            print_color $GREEN "Last 20 lines:"
            tail -n 20 "$DANTED_LOG"
            ;;
        2)
            print_color $GREEN "Last 50 lines:"
            tail -n 50 "$DANTED_LOG"
            ;;
        3)
            print_color $GREEN "Following log (Press Ctrl+C to stop):"
            tail -f "$DANTED_LOG"
            ;;
        4)
            read -p "Enter search term: " search_term
            if [[ -n "$search_term" ]]; then
                print_color $GREEN "Search results for '$search_term':"
                grep -i "$search_term" "$DANTED_LOG" | tail -20
            fi
            ;;
        5)
            print_color $GREEN "System journal for danted:"
            journalctl -u $DANTED_SERVICE --no-pager -n 30
            ;;
        *)
            print_color $RED "Invalid option"
            ;;
    esac
}

# Service management functions
restart_service() {
    print_color $YELLOW "Restarting Danted service..."
    if systemctl restart $DANTED_SERVICE; then
        sleep 2
        if systemctl is-active --quiet $DANTED_SERVICE; then
            print_color $GREEN "✓ Service restarted successfully"
            show_service_status
        else
            print_color $RED "✗ Service failed to start after restart"
            journalctl -u $DANTED_SERVICE --no-pager -n 10
        fi
    else
        print_color $RED "Failed to restart service"
    fi
}

stop_service() {
    print_color $YELLOW "Stopping Danted service..."
    if systemctl stop $DANTED_SERVICE; then
        print_color $GREEN "✓ Service stopped successfully"
    else
        print_color $RED "Failed to stop service"
    fi
}

start_service() {
    print_color $YELLOW "Starting Danted service..."
    if systemctl start $DANTED_SERVICE; then
        sleep 2
        if systemctl is-active --quiet $DANTED_SERVICE; then
            print_color $GREEN "✓ Service started successfully"
            show_service_status
        else
            print_color $RED "✗ Service failed to start"
            journalctl -u $DANTED_SERVICE --no-pager -n 10
        fi
    else
        print_color $RED "Failed to start service"
    fi
}

# Service configuration menu
service_config_menu() {
    while true; do
        clear
        print_color $CYAN "================================================================"
        print_color $CYAN "              DANTED SERVICE CONFIGURATION"
        print_color $CYAN "================================================================"
        echo
        print_color $WHITE "1. Show Service Status"
        print_color $WHITE "2. Start Service"
        print_color $WHITE "3. Stop Service"
        print_color $WHITE "4. Restart Service"
        print_color $WHITE "5. Performance Stats"
        print_color $WHITE "6. View Logs"
        print_color $WHITE "7. Enable Auto-start"
        print_color $WHITE "8. Disable Auto-start"
        print_color $WHITE "0. Back to Main Menu"
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
                print_color $GREEN "✓ Auto-start enabled"
                ;;
            8) 
                systemctl disable $DANTED_SERVICE
                print_color $YELLOW "✓ Auto-start disabled"
                ;;
            0) break ;;
            *) print_color $RED "Invalid option" ;;
        esac
        
        [[ $service_choice != 6 ]] && read -p "Press Enter to continue..."
    done
}

# Function to show users
show_users() {
    print_header
    print_color $WHITE "SOCKS5 Proxy Users"
    echo
    
    local users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            if [[ "$user" != "nobody" && "$user" != "daemon" ]]; then
                users+=("$user")
            fi
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1 | sort)
    
    if [[ ${#users[@]} -eq 0 ]]; then
        print_color $YELLOW "No SOCKS5 users found."
    else
        print_color $GREEN "Found ${#users[@]} SOCKS5 users:"
        echo
        for i in "${!users[@]}"; do
            printf "%3d. %s\n" $((i+1)) "${users[i]}"
        done
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to load current configuration
load_current_config() {
    if [[ -f "$DANTED_CONFIG" ]]; then
        SELECTED_IP=$(grep "^internal:" "$DANTED_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
        SELECTED_PORT=$(grep "^internal:" "$DANTED_CONFIG" 2>/dev/null | awk -F'=' '{print $2}' | tr -d ' ' | head -1)
    fi
}

# Function to create config file for user
create_user_config() {
    local username=$1
    local password=$2
    
    # Load current config if not set
    if [[ -z "$SELECTED_IP" || -z "$SELECTED_PORT" ]]; then
        load_current_config
    fi
    
    if [[ -z "$SELECTED_IP" || -z "$SELECTED_PORT" ]]; then
        print_color $RED "Error: Server IP and port not configured. Please install Danted first."
        return 1
    fi
    
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

# Browser Configuration:
# Proxy Type: SOCKS5
# Proxy Host: $SELECTED_IP
# Proxy Port: $SELECTED_PORT
# Username: $username
# Password: $password
EOF
    
    print_color $GREEN "✓ Configuration saved to: $CONFIG_DIR/${username}_config.txt"
}

# Function to add user
add_user() {
    print_header
    print_color $WHITE "Add New SOCKS5 User"
    echo
    
    # Check if Danted is installed
    if ! systemctl is-enabled --quiet $DANTED_SERVICE 2>/dev/null; then
        print_color $RED "Danted is not installed. Please install it first."
        read -p "Press Enter to continue..."
        return
    fi
    
    local username password
    
    # Get username
    while true; do
        read -p "Enter username: " username
        if [[ -z "$username" ]]; then
            print_color $RED "Username cannot be empty."
            continue
        fi
        if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            print_color $RED "Username can only contain letters, numbers, underscore and dash."
            continue
        fi
        if id "$username" &>/dev/null; then
            print_color $RED "User already exists."
            continue
        fi
        break
    done
    
    # Get password
    while true; do
        read -s -p "Enter password: " password
        echo
        if [[ ${#password} -lt 6 ]]; then
            print_color $RED "Password must be at least 6 characters long."
            continue
        fi
        read -s -p "Confirm password: " password_confirm
        echo
        if [[ "$password" != "$password_confirm" ]]; then
            print_color $RED "Passwords do not match."
            continue
        fi
        break
    done
    
    # Create user
    if useradd -r -s /bin/false "$username" && echo "$username:$password" | chpasswd; then
        print_color $GREEN "✓ User '$username' created successfully!"
        
        # Create configuration file
        create_user_config "$username" "$password"
        
        # Show user info
        echo
        print_color $CYAN "User Information:"
        print_color $WHITE "Username: $username"
        print_color $WHITE "Server: $SELECTED_IP:$SELECTED_PORT"
        print_color $WHITE "Config file: $CONFIG_DIR/${username}_config.txt"
    else
        print_color $RED "✗ Failed to create user '$username'"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to delete user
delete_user() {
    print_header
    print_color $WHITE "Delete SOCKS5 User"
    echo
    
    # Get list of SOCKS users
    local users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            if [[ "$user" != "nobody" && "$user" != "daemon" ]]; then
                users+=("$user")
            fi
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1 | sort)
    
    if [[ ${#users[@]} -eq 0 ]]; then
        print_color $YELLOW "No SOCKS5 users found to delete."
        read -p "Press Enter to continue..."
        return
    fi
    
    print_color $GREEN "Available users:"
    for i in "${!users[@]}"; do
        printf "%3d. %s\n" $((i+1)) "${users[i]}"
    done
    echo
    
    while true; do
        read -p "Select user number to delete (0 to cancel): " choice
        
        if [[ "$choice" == "0" ]]; then
            print_color $YELLOW "Operation cancelled."
            read -p "Press Enter to continue..."
            return
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#users[@]} ]]; then
            local username="${users[$((choice-1))]}"
            
            print_color $YELLOW "Are you sure you want to delete user '$username'?"
            read -p "Type 'yes' to confirm: " confirm
            
            if [[ "$confirm" == "yes" ]]; then
                if userdel "$username"; then
                    print_color $GREEN "✓ User '$username' deleted successfully!"
                    
                    # Remove config file if exists
                    if [[ -f "$CONFIG_DIR/${username}_config.txt" ]]; then
                        rm -f "$CONFIG_DIR/${username}_config.txt"
                        print_color $GREEN "✓ Configuration file removed"
                    fi
                else
                    print_color $RED "✗ Failed to delete user '$username'"
                fi
            else
                print_color $YELLOW "Operation cancelled."
            fi
            break
        else
            print_color $RED "Invalid selection. Please try again."
        fi
    done
    
    echo
    read -p "Press Enter to continue..."
}

# Function to show main menu
show_menu() {
    print_header
    print_color $WHITE "1. Install/Reinstall Danted"
    print_color $WHITE "2. Uninstall Danted"
    print_color $WHITE "3. Service Configuration"
    print_color $WHITE "4. Show Users"
    print_color $WHITE "5. Add User"
    print_color $WHITE "6. Delete User"
    print_color $WHITE "0. Exit"
    echo
}

# Main function
main() {
    # Load current configuration
    load_current_config
    
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case $choice in
            1) install_danted ;;
            2) uninstall_danted ;;
            3) service_config_menu ;;
            4) show_users ;;
            5) add_user ;;
            6) delete_user ;;
            0) 
                print_color $GREEN "Thank you for using Danted Manager!"
                exit 0
                ;;
            *) 
                print_color $RED "Invalid option. Please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_color $RED "This script must be run as root!"
    print_color $YELLOW "Please run: sudo $0"
    exit 1
fi

# Run main function
main "$@"
