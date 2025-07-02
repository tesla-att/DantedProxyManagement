#!/bin/bash

# Danted SOCKS5 Proxy Manager
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
    print_color $CYAN "              DANTED SOCKS5 PROXY MANAGER                       "
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
    
    # Create Danted configuration
    cat > "$DANTED_CONFIG" << EOF
# Danted SOCKS5 Proxy Configuration
logoutput: /var/log/danted.log
internal: $SELECTED_IP port = $SELECTED_PORT
external: $SELECTED_IP

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
    
    # Enable and start service
    systemctl enable $DANTED_SERVICE >/dev/null 2>&1
    systemctl restart $DANTED_SERVICE
    
    # Check status
    sleep 2
    if systemctl is-active --quiet $DANTED_SERVICE; then
        print_color $GREEN "✓ Danted installed and started successfully!"
        print_color $GREEN "✓ Listening on: $SELECTED_IP:$SELECTED_PORT"
        print_color $GREEN "✓ Service status: Active"
    else
        print_color $RED "✗ Failed to start Danted service!"
        print_color $YELLOW "Checking logs..."
        journalctl -u $DANTED_SERVICE --no-pager -n 10
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to show users
show_users() {
    print_header
    print_color $WHITE "SOCKS5 Proxy Users"
    echo
    
    local users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            users+=("$user")
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

# Function to create config file for user
create_user_config() {
    local username=$1
    local password=$2
    
    if [[ -z "$SELECTED_IP" || -z "$SELECTED_PORT" ]]; then
        # Try to get from existing config
        if [[ -f "$DANTED_CONFIG" ]]; then
            SELECTED_IP=$(grep "internal:" "$DANTED_CONFIG" | awk '{print $2}')
            SELECTED_PORT=$(grep "internal:" "$DANTED_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ')
        fi
    fi
    
    if [[ -z "$SELECTED_IP" || -z "$SELECTED_PORT" ]]; then
        print_color $RED "Error: Server IP and port not configured. Please install Danted first."
        return 1
    fi
    
    # Read the sample template
    local config_content='
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
            "address": "'"$SELECTED_IP"'",
            "ota": false,
            "port": '"$SELECTED_PORT"',
            "level": 1,
            "users": [
              {
                "user": "'"$username"'",
                "pass": "'"$password"'",
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
          "52.80.66.66",
          "117.50.22.22",
          "2400:7fc0:849e:200::4",
          "2404:c2c0:85d8:901::4",
          "117.50.10.10",
          "52.80.52.52",
          "2400:7fc0:849e:200::8",
          "2404:c2c0:85d8:901::8",
          "117.50.60.30",
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
}'
    
    echo "$config_content" > "$CONFIG_DIR/$username"
    return 0
}

# Function to add single user
add_single_user() {
    print_header
    print_color $WHITE "Add Single User"
    echo
    
    while true; do
        read -p "Enter username: " username
        if [[ -n "$username" && "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            if id "$username" &>/dev/null; then
                print_color $RED "User '$username' already exists!"
            else
                break
            fi
        else
            print_color $RED "Invalid username. Use only letters, numbers, underscore and dash."
        fi
    done
    
    while true; do
        read -s -p "Enter password: " password
        echo
        if [[ ${#password} -ge 4 ]]; then
            read -s -p "Confirm password: " password2
            echo
            if [[ "$password" == "$password2" ]]; then
                break
            else
                print_color $RED "Passwords don't match!"
            fi
        else
            print_color $RED "Password must be at least 4 characters long!"
        fi
    done
    
    # Create user
    if useradd -r -s /bin/false "$username"; then
        echo "$username:$password" | chpasswd
        create_user_config "$username" "$password"
        print_color $GREEN "✓ User '$username' created successfully!"
        print_color $GREEN "✓ Config file created: $CONFIG_DIR/$username"
    else
        print_color $RED "✗ Failed to create user '$username'!"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to add multiple users
add_multi_users() {
    print_header
    print_color $WHITE "Add Multiple Users"
    echo
    
    print_color $YELLOW "Enter usernames (one per line, press Enter twice to finish):"
    echo
    
    local usernames=()
    while true; do
        read -p "> " username
        if [[ -z "$username" ]]; then
            if [[ ${#usernames[@]} -gt 0 ]]; then
                break
            else
                print_color $YELLOW "Please enter at least one username."
                continue
            fi
        fi
        
        if [[ "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            if id "$username" &>/dev/null; then
                print_color $RED "User '$username' already exists! Skipping..."
            else
                usernames+=("$username")
                print_color $GREEN "Added: $username"
            fi
        else
            print_color $RED "Invalid username '$username'. Skipping..."
        fi
    done
    
    if [[ ${#usernames[@]} -eq 0 ]]; then
        print_color $RED "No valid usernames provided!"
        read -p "Press Enter to continue..."
        return
    fi
    
    print_color $CYAN "Creating ${#usernames[@]} users..."
    echo
    
    # Create users and set passwords
    local created_users=()
    for username in "${usernames[@]}"; do
        while true; do
            read -s -p "Set password for '$username': " password
            echo
            if [[ ${#password} -ge 4 ]]; then
                read -s -p "Confirm password for '$username': " password2
                echo
                if [[ "$password" == "$password2" ]]; then
                    if useradd -r -s /bin/false "$username"; then
                        echo "$username:$password" | chpasswd
                        create_user_config "$username" "$password"
                        created_users+=("$username")
                        print_color $GREEN "✓ User '$username' created successfully!"
                    else
                        print_color $RED "✗ Failed to create user '$username'!"
                    fi
                    break
                else
                    print_color $RED "Passwords don't match for '$username'!"
                fi
            else
                print_color $RED "Password for '$username' must be at least 4 characters long!"
            fi
        done
        echo
    done
    
    print_color $GREEN "Successfully created ${#created_users[@]} users!"
    print_color $GREEN "Config files created in: $CONFIG_DIR/"
    
    echo
    read -p "Press Enter to continue..."
}

# Function to manage user addition
manage_add_users() {
    while true; do
        print_header
        print_color $WHITE "Add Users Menu"
        echo
        print_color $CYAN "1. Add single user"
        print_color $CYAN "2. Add multiple users"
        print_color $CYAN "3. Back to main menu"
        echo
        
        read -p "Select option [1-3]: " choice
        
        case $choice in
            1) add_single_user ;;
            2) add_multi_users ;;
            3) break ;;
            *) print_color $RED "Invalid option!" ;;
        esac
    done
}

# Function to delete users
delete_users() {
    print_header
    print_color $WHITE "Delete Users"
    echo
    
    local users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            users+=("$user")
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1 | sort)
    
    if [[ ${#users[@]} -eq 0 ]]; then
        print_color $YELLOW "No SOCKS5 users found to delete."
        read -p "Press Enter to continue..."
        return
    fi
    
    print_color $GREEN "Available users to delete:"
    echo
    for i in "${!users[@]}"; do
        printf "%3d. %s\n" $((i+1)) "${users[i]}"
    done
    
    echo
    print_color $YELLOW "Enter user numbers to delete (space-separated, e.g., '1 3 5'):"
    read -p "> " selections
    
    if [[ -z "$selections" ]]; then
        print_color $YELLOW "No selection made."
        read -p "Press Enter to continue..."
        return
    fi
    
    local to_delete=()
    for selection in $selections; do
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#users[@]} ]]; then
            to_delete+=("${users[$((selection-1))]}")
        else
            print_color $RED "Invalid selection: $selection"
        fi
    done
    
    if [[ ${#to_delete[@]} -eq 0 ]]; then
        print_color $RED "No valid users selected!"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo
    print_color $YELLOW "Users to be deleted:"
    for user in "${to_delete[@]}"; do
        echo "  - $user"
    done
    
    echo
    read -p "Are you sure you want to delete these users? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_color $YELLOW "Operation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Delete users
    local deleted_count=0
    for user in "${to_delete[@]}"; do
        if userdel "$user" 2>/dev/null; then
            # Remove config file
            rm -f "$CONFIG_DIR/$user"
            print_color $GREEN "✓ Deleted user: $user"
            ((deleted_count++))
        else
            print_color $RED "✗ Failed to delete user: $user"
        fi
    done
    
    print_color $GREEN "Successfully deleted $deleted_count users!"
    
    echo
    read -p "Press Enter to continue..."
}

# Function to test proxies
test_proxies() {
    print_header
    print_color $WHITE "Test Proxies"
    echo
    
    print_color $YELLOW "Enter proxy details in format: IP:PORT:USERNAME:PASSWORD"
    print_color $YELLOW "(One per line, press Enter twice to finish):"
    echo
    
    local proxies=()
    while true; do
        read -p "> " proxy_line
        if [[ -z "$proxy_line" ]]; then
            if [[ ${#proxies[@]} -gt 0 ]]; then
                break
            else
                print_color $YELLOW "Please enter at least one proxy."
                continue
            fi
        fi
        
        if [[ "$proxy_line" =~ ^[^:]+:[0-9]+:[^:]+:[^:]+$ ]]; then
            proxies+=("$proxy_line")
            print_color $GREEN "Added: $proxy_line"
        else
            print_color $RED "Invalid format: $proxy_line (Expected: IP:PORT:USERNAME:PASSWORD)"
        fi
    done
    
    if [[ ${#proxies[@]} -eq 0 ]]; then
        print_color $RED "No valid proxies provided!"
        read -p "Press Enter to continue..."
        return
    fi
    
    print_color $CYAN "Testing ${#proxies[@]} proxies..."
    echo
    
    local success_count=0
    local total_count=${#proxies[@]}
    
    for i in "${!proxies[@]}"; do
        local proxy="${proxies[i]}"
        IFS=':' read -r ip port user pass <<< "$proxy"
        
        local curl_proxy="socks5://$user:$pass@$ip:$port"
        
        printf "[%2d/%2d] Testing %s:%s@%s:%s ... " $((i+1)) $total_count "$user" "$pass" "$ip" "$port"
        
        # Test with timeout
        if timeout 10 curl -s --proxy "$curl_proxy" --connect-timeout 5 -I http://httpbin.org/ip >/dev/null 2>&1; then
            print_color $GREEN "✓ SUCCESS"
            ((success_count++))
        else
            print_color $RED "✗ FAILED"
        fi
    done
    
    echo
    print_color $CYAN "Test Results:"
    print_color $GREEN "✓ Successful: $success_count/$total_count"
    print_color $RED "✗ Failed: $((total_count - success_count))/$total_count"
    
    local success_rate=$((success_count * 100 / total_count))
    print_color $YELLOW "Success Rate: $success_rate%"
    
    echo
    read -p "Press Enter to continue..."
}

# Function to uninstall Danted
uninstall_danted() {
    print_header
    print_color $WHITE "Uninstall Danted"
    echo
    
    print_color $RED "WARNING: This will completely remove Danted and all configurations!"
    echo
    read -p "Are you sure you want to uninstall Danted? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_color $YELLOW "Operation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    print_color $YELLOW "Uninstalling Danted..."
    
    # Stop and disable service
    systemctl stop $DANTED_SERVICE 2>/dev/null
    systemctl disable $DANTED_SERVICE 2>/dev/null
    
    # Remove package
    apt remove --purge -y dante-server >/dev/null 2>&1
    
    # Remove configuration files
    rm -f "$DANTED_CONFIG"
    rm -f /var/log/danted.log
    
    # Ask about user configs
    if [[ -d "$CONFIG_DIR" ]] && [[ $(ls -A "$CONFIG_DIR" 2>/dev/null) ]]; then
        echo
        read -p "Do you want to remove all user config files in '$CONFIG_DIR'? (y/N): " remove_configs
        if [[ "$remove_configs" =~ ^[Yy]$ ]]; then
            rm -rf "$CONFIG_DIR"
            print_color $GREEN "✓ User config files removed"
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
        print_color $YELLOW "Found ${#socks_users[@]} SOCKS5 users:"
        for user in "${socks_users[@]}"; do
            echo "  - $user"
        done
        echo
        read -p "Do you want to remove all SOCKS5 users? (y/N): " remove_users
        if [[ "$remove_users" =~ ^[Yy]$ ]]; then
            for user in "${socks_users[@]}"; do
                userdel "$user" 2>/dev/null
                print_color $GREEN "✓ Removed user: $user"
            done
        fi
    fi
    
    print_color $GREEN "✓ Danted has been completely uninstalled!"
    
    echo
    read -p "Press Enter to continue..."
}

# Main menu function
show_main_menu() {
    print_header
    print_color $WHITE "Main Menu"
    echo
    print_color $CYAN "1. Install Danted SOCKS5 Proxy"
    print_color $CYAN "2. Show Users"
    print_color $CYAN "3. Add Users"
    print_color $CYAN "4. Delete Users"
    print_color $CYAN "5. Test Proxies"
    print_color $CYAN "6. Uninstall Danted"
    print_color $CYAN "7. Exit"
    echo
}

# Main program loop
main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_color $RED "This script must be run as root!"
        print_color $YELLOW "Please run: sudo $0"
        exit 1
    fi
    
    while true; do
        show_main_menu
        read -p "Select option [1-7]: " choice
        
        case $choice in
            1) install_danted ;;
            2) show_users ;;
            3) manage_add_users ;;
            4) delete_users ;;
            5) test_proxies ;;
            6) uninstall_danted ;;
            7) 
                print_color $GREEN "Thank you for using Danted SOCKS5 Proxy Manager!"
                exit 0
                ;;
            *) 
                print_color $RED "Invalid option! Please select 1-7."
                sleep 1
                ;;
        esac
    done
}

# Run main function
main "$@"