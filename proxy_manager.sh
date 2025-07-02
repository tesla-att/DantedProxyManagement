#!/bin/bash
# User and Proxy Management Script (English) - Fixed Version

# Global variables
readonly SCRIPT_NAME="User & Proxy Manager"
readonly DANTE_CONFIG="/etc/danted.conf"
readonly SEPARATOR="=============================================================="

# Color codes for better output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Utility functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This function requires root privileges!"
        return 1
    fi
    return 0
}

# Sanitize input by removing spaces and special characters
sanitize_input() {
    echo "$1" | tr -d ' \t\n\r' | sed 's/[^a-zA-Z0-9._-]//g'
}

# Validate username
validate_username() {
    local username="$1"
    [[ -n "$username" && "$username" =~ ^[a-zA-Z0-9._-]+$ && ${#username} -le 32 ]]
}

# Get all proxy users (both system and regular users with /bin/false shell)
get_proxy_users() {
    awk -F: '($7 == "/bin/false" && $1 != "nobody" && $1 != "nfsnobody") {print $1}' /etc/passwd | sort
}

# Get regular users with /bin/false shell (UID >= 1000)
get_regular_users() {
    awk -F: '($3 >= 1000 && $7 == "/bin/false" && $1 != "nobody") {print $1}' /etc/passwd | sort
}

# Get system users with /bin/false shell (UID < 1000)
get_system_users() {
    local min_uid="${1:-0}"
    local max_uid="${2:-999}"
    awk -F: -v min="$min_uid" -v max="$max_uid" \
        '($3 >= min && $3 <= max && $7 == "/bin/false" && $1 != "nobody" && $1 != "nfsnobody") {print $1}' \
        /etc/passwd | sort
}

# Display users in a formatted list
display_users() {
    local -a users=("$@")
    if [[ ${#users[@]} -eq 0 ]]; then
        log_warning "No users found!"
        return 1
    fi
    
    log_info "User list:"
    for i in "${!users[@]}"; do
        # Get UID for each user
        local uid=$(id -u "${users[$i]}" 2>/dev/null)
        printf "  %2d. %-20s (UID: %s)\n" $((i+1)) "${users[$i]}" "${uid:-unknown}"
    done
    return 0
}

# Fixed password input function
get_password() {
    local username="$1"
    local password password2
    local attempts=0
    local max_attempts=3
    
    while [[ $attempts -lt $max_attempts ]]; do
        echo -n "Enter password for $username: "
        read -s password
        echo  # New line after password input
        
        # Check if password is empty
        if [[ -z "$password" ]]; then
            log_error "Password cannot be empty!"
            ((attempts++))
            continue
        fi
        
        # Check password length
        if [[ ${#password} -lt 6 ]]; then
            log_error "Password must be at least 6 characters long!"
            ((attempts++))
            continue
        fi
        
        # Confirm password
        echo -n "Re-enter password for $username: "
        read -s password2
        echo  # New line after password input
        
        # Check if passwords match
        if [[ "$password" != "$password2" ]]; then
            log_error "Passwords do not match!"
            ((attempts++))
            continue
        fi
        
        # Password is valid
        echo "$password"
        return 0
    done
    
    log_error "Maximum password attempts reached!"
    return 1
}

# Set user password with better error handling
set_user_password() {
    local username="$1"
    local password
    
    log_info "Setting password for user: $username"
    
    if password=$(get_password "$username"); then
        if echo "$username:$password" | chpasswd 2>/dev/null; then
            log_success "Password set for user $username"
            return 0
        else
            log_error "Failed to set password for user $username"
            return 1
        fi
    else
        log_error "Password setup cancelled for user $username"
        return 1
    fi
}

# Create a single user
create_user() {
    local username="$1"
    
    if ! validate_username "$username"; then
        log_error "Invalid username: $username"
        return 1
    fi
    
    if id "$username" &>/dev/null; then
        log_warning "User $username already exists!"
        return 1
    fi
    
    if useradd -r -s /bin/false "$username" 2>/dev/null; then
        log_success "User $username created"
        if set_user_password "$username"; then
            return 0
        else
            log_warning "User $username created but password setup failed"
            return 1
        fi
    else
        log_error "Failed to create user $username"
        return 1
    fi
}

function show_users() {
    echo "$SEPARATOR"
    local -a users
    mapfile -t users < <(get_proxy_users)
    
    if [[ ${#users[@]} -eq 0 ]]; then
        log_warning "No proxy users found!"
        log_info "Proxy users are users with shell '/bin/false'"
        return 1
    fi
    
    display_users "${users[@]}"
    
    # Show statistics
    local system_count regular_count
    system_count=$(get_system_users | wc -l)
    regular_count=$(get_regular_users | wc -l)
    
    echo
    log_info "Statistics:"
    echo "  - System users (UID < 1000): $system_count"
    echo "  - Regular users (UID >= 1000): $regular_count"
    echo "  - Total proxy users: ${#users[@]}"
}

function add_single_user() {
    echo "$SEPARATOR"
    local username
    
    echo -n "Enter username: "
    read username
    username=$(sanitize_input "$username")
    
    if [[ -z "$username" ]]; then
        log_error "Username cannot be empty!"
        return 1
    fi
    
    create_user "$username"
}

function add_multi_users() {
    echo "$SEPARATOR"
    log_info "Enter multiple usernames, one per line. Press Enter on empty line to finish."
    
    local -a usernames=()
    local line
    
    while true; do
        echo -n "> "
        read -r line
        line=$(sanitize_input "$line")
        [[ -z "$line" ]] && break
        usernames+=("$line")
    done
    
    if [[ ${#usernames[@]} -eq 0 ]]; then
        log_warning "No users entered!"
        return 1
    fi
    
    log_info "Creating ${#usernames[@]} users..."
    local created=0 skipped=0
    
    for username in "${usernames[@]}"; do
        echo
        log_info "Processing user: $username"
        if create_user "$username"; then
            ((created++))
        else
            ((skipped++))
        fi
    done
    
    echo
    log_info "Summary: $created users created, $skipped users skipped"
}

function add_user() {
    echo "$SEPARATOR"
    log_info "Choose user adding method:"
    echo "1. Add a Single User"
    echo "2. Add Multiple Users"
    
    local option
    echo -n "Your choice [1-2]: "
    read option
    option=$(sanitize_input "$option")
    
    case $option in
        1) add_single_user ;;
        2) add_multi_users ;;
        *) log_error "Invalid choice!" ;;
    esac
}

function delete_user() {
    while true; do
        echo "$SEPARATOR"
        local -a user_list
        mapfile -t user_list < <(get_proxy_users)
        
        if [[ ${#user_list[@]} -eq 0 ]]; then
            log_warning "No proxy users to delete!"
            return 1
        fi
        
        # Show all proxy users with more details
        log_info "Available proxy users:"
        for i in "${!user_list[@]}"; do
            local uid=$(id -u "${user_list[$i]}" 2>/dev/null)
            local user_type="regular"
            [[ $uid -lt 1000 ]] && user_type="system"
            printf "  %2d. %-20s (UID: %s, Type: %s)\n" $((i+1)) "${user_list[$i]}" "${uid:-unknown}" "$user_type"
        done
        
        echo
        log_info "Enter user numbers to delete (space-separated) or 'b' to go back:"
        local input
        echo -n "> "
        read input
        
        if [[ "$input" =~ ^[Bb]$ ]]; then
            log_info "Returning to main menu"
            break
        fi
        
        # Parse and validate selections
        local -a selected=($input)
        local -a to_delete=()
        local invalid=0
        
        for num in "${selected[@]}"; do
            if [[ "$num" =~ ^[0-9]+$ ]] && ((num >= 1 && num <= ${#user_list[@]})); then
                to_delete+=("${user_list[$((num-1))]}")
            else
                log_error "Invalid selection: $num"
                ((invalid++))
            fi
        done
        
        if [[ ${#to_delete[@]} -eq 0 ]]; then
            log_warning "No valid users selected!"
            continue
        fi
        
        # Confirmation
        log_warning "You are about to delete: ${to_delete[*]}"
        local confirm
        echo -n "Are you sure? (y/N): "
        read confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            local deleted=0 failed=0
            for user in "${to_delete[@]}"; do
                if userdel -r "$user" 2>/dev/null; then
                    log_success "Deleted user $user"
                    ((deleted++))
                else
                    log_error "Failed to delete user $user"
                    ((failed++))
                fi
            done
            log_info "Summary: $deleted users deleted, $failed users failed"
        else
            log_info "User deletion cancelled"
        fi
    done
}

# Parallel proxy testing function
test_single_proxy() {
    local proxy="$1"
    local timeout="${2:-10}"
    
    IFS=':' read -r ip port user pass <<< "$proxy"
    local curl_proxy
    
    if [[ -z "$user" ]]; then
        curl_proxy="socks5://$ip:$port"
    else
        curl_proxy="socks5://$user:$pass@$ip:$port"
    fi
    
    local result
    result=$(curl -s --max-time "$timeout" --connect-timeout 5 -x "$curl_proxy" https://api.ip.sb/ip 2>/dev/null)
    
    if [[ $? -eq 0 && -n "$result" ]]; then
        log_success "$proxy -> $result"
    else
        log_error "$proxy -> FAILED"
    fi
}

function test_proxy() {
    echo "$SEPARATOR"
    log_info "Paste proxy list (one per line, empty line to finish):"
    
    local -a proxies=()
    local line
    
    while true; do
        echo -n "> "
        read -r line
        [[ -z "$line" ]] && break
        line=$(echo "$line" | tr -d ' \t')
        [[ -n "$line" ]] && proxies+=("$line")
    done
    
    if [[ ${#proxies[@]} -eq 0 ]]; then
        log_warning "No proxies entered!"
        return 1
    fi
    
    log_info "Testing ${#proxies[@]} proxies..."
    
    # Test proxies in parallel (limit to 10 concurrent)
    local max_jobs=10
    local job_count=0
    
    for proxy in "${proxies[@]}"; do
        test_single_proxy "$proxy" &
        ((job_count++))
        
        if ((job_count >= max_jobs)); then
            wait
            job_count=0
        fi
    done
    wait
    
    log_info "Proxy testing completed"
}

# Get public IP with fallback
get_public_ip() {
    local ip
    local -a services=("https://api.ipify.org" "https://ifconfig.me" "https://icanhazip.com")
    
    for service in "${services[@]}"; do
        ip=$(curl -s --max-time 5 "$service" 2>/dev/null | tr -d '\n\r')
        if [[ -n "$ip" && "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        fi
    done
    
    log_warning "Could not determine public IP"
    echo "unknown"
    return 1
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    else
        log_error "Cannot determine operating system!"
        return 1
    fi
}

# Install packages based on OS
install_package() {
    local package="$1"
    local os
    os=$(detect_os) || return 1
    
    case "$os" in
        ubuntu|debian)
            apt-get update -qq && apt-get install -y "$package"
            ;;
        centos|rhel|fedora)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y epel-release && dnf install -y "$package"
            else
                yum install -y epel-release && yum install -y "$package"
            fi
            ;;
        *)
            log_error "Unsupported operating system: $os"
            return 1
            ;;
    esac
}

# Get network interfaces
get_network_interfaces() {
    local -A interfaces
    local interface ip
    
    while read -r line; do
        interface=$(echo "$line" | awk '{print $2}')
        ip=$(echo "$line" | awk '{print $4}' | cut -d'/' -f1)
        interfaces["$interface"]="$ip"
    done < <(ip -o -4 addr show 2>/dev/null)
    
    local i=1
    for interface in $(ip -o link show | awk -F': ' '{print $2}'); do
        ip="${interfaces[$interface]:-No IP}"
        echo "$i. $interface - IP: $ip"
        ((i++))
    done
}

function install_dante() {
    echo "$SEPARATOR"
    log_info "Installing Dante SOCKS proxy server..."
    
    check_root || return 1
    
    # Install dante-server
    if ! install_package "dante-server"; then
        log_error "Failed to install Dante server!"
        return 1
    fi
    
    # Get configuration
    local port interface auth_required
    echo -n "Enter port for Dante SOCKS server [1080]: "
    read port
    port=${port:-1080}
    
    if ! [[ "$port" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
        log_error "Invalid port number!"
        return 1
    fi
    
    log_info "Available network interfaces:"
    get_network_interfaces
    
    echo -n "Choose interface number [1]: "
    read if_num
    if_num=${if_num:-1}
    
    local -a all_interfaces
    mapfile -t all_interfaces < <(ip -o link show | awk -F': ' '{print $2}')
    
    if ! [[ "$if_num" =~ ^[0-9]+$ ]] || ((if_num < 1 || if_num > ${#all_interfaces[@]})); then
        log_warning "Invalid choice! Using eth0"
        interface="eth0"
    else
        interface="${all_interfaces[$((if_num-1))]}"
    fi
    
    echo -n "Require user authentication? (y/N): "
    read auth_required
    
    # Create configuration
    cat > "$DANTE_CONFIG" << EOF
# Dante SOCKS proxy configuration
logoutput: syslog
user.privileged: root
user.unprivileged: nobody

internal: 0.0.0.0 port=$port
external: $interface

method: $(if [[ "$auth_required" =~ ^[Yy]$ ]]; then echo "username"; else echo "none"; fi)

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    log: connect disconnect error
}
EOF

    # Start and enable service
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable danted 2>/dev/null
        systemctl restart danted
        local status
        status=$(systemctl is-active danted)
    else
        service danted restart
        local status="unknown"
    fi
    
    # Show results
    if [[ "$status" == "active" ]] || service danted status >/dev/null 2>&1; then
        log_success "Dante SOCKS server installed and running on port $port"
        log_info "Configuration: $DANTE_CONFIG"
        log_info "Server IP: $(get_public_ip)"
        
        if [[ "$auth_required" =~ ^[Yy]$ ]]; then
            log_info "Authentication required - use 'Add user' to create proxy users"
        else
            log_info "No authentication - proxy ready: $(get_public_ip):$port"
        fi
    else
        log_error "Failed to start Dante server!"
        return 1
    fi
}

function uninstall_dante() {
    echo "$SEPARATOR"
    log_warning "Uninstalling Dante SOCKS proxy server completely..."
    
    check_root || return 1
    
    # Stop and disable service
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop danted 2>/dev/null
        systemctl disable danted 2>/dev/null
    else
        service danted stop 2>/dev/null
    fi
    
    # Remove package
    local os
    os=$(detect_os) || return 1
    
    case "$os" in
        ubuntu|debian)
            apt-get remove --purge -y dante-server
            apt-get autoremove -y
            ;;
        centos|rhel|fedora)
            if command -v dnf >/dev/null 2>&1; then
                dnf remove -y dante-server
            else
                yum remove -y dante-server
            fi
            ;;
    esac
    
    # Remove configuration files
    rm -f "$DANTE_CONFIG" /var/log/danted.log
    
    log_success "Dante SOCKS proxy server completely uninstalled!"
}

# Main menu
show_menu() {
    echo
    echo "============ $SCRIPT_NAME ============"
    echo "1. Install Dante SOCKS proxy server"
    echo "2. Show user list"
    echo "3. Add user"
    echo "4. Delete user"
    echo "5. Batch test proxies"
    echo "6. Uninstall Dante SOCKS proxy server"
    echo "7. Exit"
}

# Main loop
main() {
    while true; do
        show_menu
        local choice
        echo -n "Choose a function [1-7]: "
        read choice
        choice=$(sanitize_input "$choice")
        
        case $choice in
            1) install_dante ;;
            2) show_users ;;
            3) add_user ;;
            4) delete_user ;;
            5) test_proxy ;;
            6) uninstall_dante ;;
            7) log_info "Goodbye!"; exit 0 ;;
            *) log_error "Invalid choice!" ;;
        esac
    done
}

# Run main function
main "$@"