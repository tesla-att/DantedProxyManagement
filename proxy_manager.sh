#!/bin/bash
# User and Proxy Management Script (English)

function show_users() {
    echo "User list:"
    mapfile -t USERS < <(awk -F: '($3 < 1000 && $7 == "/bin/false") {print $1}' /etc/passwd)
    if [ ${#USERS[@]} -eq 0 ]; then
        echo "No users found!"
        return
    fi
    for i in "${!USERS[@]}"; do
        printf "%2d. %s\n" $((i+1)) "${USERS[$i]}"
    done
}

function add_single_user() {
    echo "=============================================================="
    read -p "Enter username: " username
    username=$(echo "$username" | tr -d ' ')
    if [ -z "$username" ]; then
        echo "Username cannot be empty!"
        return
    fi
    if id "$username" &>/dev/null; then
        echo "User $username already exists!"
        return
    fi
    useradd -r -s /bin/false "$username"
    if [ $? -ne 0 ]; then
        echo "Error creating user $username."
        return
    fi
    echo "User $username created."
    # --- Thay đổi: đặt password luôn, không hỏi ---
    while true; do
        read -s -p "Enter password for $username: " password
        echo
        read -s -p "Re-enter password for $username: " password2
        echo
        if [ "$password" != "$password2" ]; then
            echo "Passwords do not match. Try again."
        elif [ -z "$password" ]; then
            echo "Password cannot be empty. Try again."
        else
            echo "$username:$password" | chpasswd
            if [ $? -eq 0 ]; then
                echo "Password set for user $username."
            else
                echo "Error setting password for user $username."
            fi
            break
        fi
    done
}

function add_multi_users() {
    echo "=============================================================="
    echo "You can enter multiple usernames, one per line. Press Enter twice to finish."
    usernames=()
    while true; do
        read line
        line=$(echo "$line" | tr -d ' ')
        if [ -z "$line" ]; then
            break
        fi
        usernames+=("$line")
    done
    if [ ${#usernames[@]} -eq 0 ]; then
        echo "No users entered!"
        return
    fi

    for username in "${usernames[@]}"; do
        if [ -z "$username" ]; then
            continue
        fi
        if id "$username" &>/dev/null; then
            echo "User $username already exists! Skipping."
        else
            useradd -r -s /bin/false "$username"
            if [ $? -eq 0 ]; then
                echo "User $username created."
                while true; do
                    read -s -p "Enter password for $username: " upass
                    echo
                    read -s -p "Re-enter password for $username: " upass2
                    echo
                    if [ "$upass" != "$upass2" ]; then
                        echo "Passwords do not match. Try again."
                    elif [ -z "$upass" ]; then
                        echo "Password cannot be empty. Try again."
                    else
                        echo "$username:$upass" | chpasswd
                        if [ $? -eq 0 ]; then
                            echo "Password set for user $username."
                        else
                            echo "Error setting password for user $username."
                        fi
                        break
                    fi
                done
            else
                echo "Error creating user $username."
            fi
        fi
    done
}

function add_user() {
    echo "=============================================================="
    echo "Choose user adding method:"
    echo "1. Add a Single-User"
    echo "2. Add Multi-Users"
    read -p "Your choice [1-2]: " option
    option=$(echo "$option" | tr -d ' ')
    case $option in
        1) add_single_user ;;
        2) add_multi_users ;;
        *) echo "Invalid choice!" ;;
    esac
}

function delete_user() {
    while true; do
        # Get all system users except system accounts
        user_list=($(awk -F: '{ if ($3 >= 1000 && $1 != "nobody") print $1 }' /etc/passwd))
        if [ ${#user_list[@]} -eq 0 ]; then
            echo "No users to delete!"
            return
        fi

        echo "User list:"
        for i in "${!user_list[@]}"; do
            idx=$((i+1))
            echo "  $idx. ${user_list[$i]}"
        done

        echo "Enter the numbers of the users you want to delete (separated by spaces), or 'b' to go back:"
        read -p "> " input

        # Handle back
        if [[ "$input" == "b" || "$input" == "B" ]]; then
            echo "Returning to main menu."
            break
        fi

        # Parse input numbers
        selected=($input)
        to_delete=()
        for num in "${selected[@]}"; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#user_list[@]} ]; then
                to_delete+=("${user_list[$((num-1))]}")
            else
                echo "Invalid selection: $num"
            fi
        done

        if [ ${#to_delete[@]} -eq 0 ]; then
            echo "No valid users selected!"
            continue
        fi

        echo "You are about to delete the following users: ${to_delete[*]}"
        read -p "Are you sure? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            for user in "${to_delete[@]}"; do
                sudo userdel -r "$user" && echo "Deleted user $user." || echo "Failed to delete $user."
            done
        else
            echo "Cancelled user deletion."
        fi
        # After deletion, loop back to show menu again
    done
}

function test_proxy() {
    echo "Paste the proxy list (one proxy per line, press Enter twice to finish):"
    proxies=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        line=$(echo "$line" | tr -d ' ')
        proxies+=("$line")
    done
    for proxy in "${proxies[@]}"; do
        IFS=':' read -r ip port user pass <<< "$proxy"
        if [ -z "$user" ]; then
            curl_proxy="socks5://$ip:$port"
        else
            curl_proxy="socks5://$user:$pass@$ip:$port"
        fi
        result=$(curl -s --max-time 10 -x "$curl_proxy" https://api.ip.sb/ip)
        if [ $? -eq 0 ] && [[ $result != "" ]]; then
            echo "[SUCCESS] $proxy"
        else
            echo "[FAIL] $proxy"
        fi
    done
}

install_dante() {
    echo "=============================================================="
    echo "Installing Dante SOCKS proxy server..."
    if [ "$(id -u)" != "0" ]; then
        echo "You need root privileges to install Dante server!"
        return
    fi

    # Get public IP
    get_public_ip() {
        ip=$(curl -s https://api.ipify.org)
        if [[ -z "$ip" ]]; then
            ip=$(curl -s https://ifconfig.me)
        fi
        if [[ -z "$ip" ]]; then
            ip=$(curl -s https://icanhazip.com)
        fi
        echo "$ip"
    }

    # Define OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "Cannot determine operating system!"
        return
    fi

    # Install dante-server
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y dante-server
            ;;
        centos|rhel|fedora)
            yum install -y epel-release
            yum install -y dante-server
            ;;
        *)
            echo "Operating system not supported!"
            return
            ;;
    esac
    if [ $? -ne 0 ]; then
        echo "Failed to install Dante server!"
        return
    fi

    read -p "Enter port for Dante SOCKS server [1080]: " port
    port=$(echo "$port" | tr -d ' ')
    if [ -z "$port" ]; then
        port=1080
    fi

    # Show network interfaces
    all_intf=($(ip -o link show | awk -F': ' '{print $2}'))
    declare -A ip_map
    while IFS= read -r line; do
        intf=$(echo "$line" | awk '{print $2}')
        ipaddr=$(echo "$line" | awk '{print $4}')
        ip_map["$intf"]="$ipaddr"
    done < <(ip -o -4 addr show)
    echo "Network interfaces:"
    for i in "${!all_intf[@]}"; do
        ip="${ip_map[${all_intf[$i]}]}"
        if [ -z "$ip" ]; then ip="No IP"; fi
        echo "$((i+1)). ${all_intf[$i]} - IP: $ip"
    done
    read -p "Choose the interface number to use for Dante (e.g. 2): " if_num
    if_num=$(echo "$if_num" | tr -d ' ')
    if ! [[ "$if_num" =~ ^[0-9]+$ ]] || ((if_num < 1 || if_num > ${#all_intf[@]})); then
        echo "Invalid choice! Defaulting to eth0."
        interface="eth0"
    else
        interface="${all_intf[$((if_num-1))]}"
    fi

    read -p "Do you want to require user authentication? (y/n): " auth_required
    auth_required=$(echo "$auth_required" | tr -d ' ')

    # Create Danted configuration file
    cat > /etc/danted.conf << EOF
logoutput: syslog
user.privileged: root
user.unprivileged: nobody

internal: 0.0.0.0 port=$port
external: $interface

method: $(if [[ "$auth_required" == "y" || "$auth_required" == "Y" ]]; then echo "username"; else echo "none"; fi)

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

    # Restart service and show status
    if [ -f /bin/systemctl ] || [ -f /usr/bin/systemctl ]; then
        systemctl enable danted
        systemctl restart danted
        dante_status=$(systemctl is-active danted)
        echo "Dante service status: $dante_status"
        if [ "$dante_status" = "active" ]; then
            status=0
        else
            status=1
        fi
    else
        service danted restart
        dante_status=$(service danted status | grep -E 'Active|running')
        echo "Dante service status: $dante_status"
        if [[ "$dante_status" == *"running"* ]]; then
            status=0
        else
            status=1
        fi
    fi

    # Show result
    if [ $status -eq 0 ]; then
        echo "Dante SOCKS server has been installed and is running on port $port"
        echo "Configuration: /etc/danted.conf"
        echo -n "Server IP: "
        get_public_ip
        if [[ "$auth_required" == "y" || "$auth_required" == "Y" ]]; then
            echo "You chose user authentication."
            echo "Use the 'Add user' function to create users for the proxy."
        else
            echo "You chose no authentication."
            echo "Proxy can be used immediately: $(get_public_ip):$port"
        fi
    else
        echo "Failed to start Dante server!"
    fi
}

function uninstall_dante() {
    echo "Uninstalling Dante SOCKS proxy server completely..."
    if [ "$(id -u)" != "0" ]; then
        echo "You need root privileges to uninstall Dante server!"
        return
    fi
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "Cannot determine operating system!"
        return
    fi
    case $OS in
        ubuntu|debian)
            apt-get remove --purge -y dante-server
            apt-get autoremove -y
            ;;
        centos|rhel|fedora)
            yum remove -y dante-server
            ;;
        *)
            echo "Operating system not supported!"
            return
            ;;
    esac
    rm -f /etc/danted.conf
    rm -f /var/log/danted.log
    if [ -f /bin/systemctl ] || [ -f /usr/bin/systemctl ]; then
        systemctl disable danted
        systemctl stop danted
    else
        service danted stop
    fi
    echo "Dante SOCKS proxy server has been completely uninstalled!"
}

while true; do
    echo ""
    echo "============ User & Proxy Manager ============"
    echo "1. Install Dante SOCKS proxy server"
    echo "2. Show user list"
    echo "3. Add user"
    echo "4. Delete user"
    echo "5. Batch test proxies"
    echo "6. Uninstall Dante SOCKS proxy server completely"
    echo "7. Exit"
    read -p "Choose a function [1-7]: " choice
    choice=$(echo "$choice" | tr -d ' ')
    case $choice in
        1) install_dante ;;
        2) show_users ;;
        3) add_user ;;
        4) delete_user ;;
        5) test_proxy ;;
        6) uninstall_dante ;;
        7) exit 0 ;;
        *) echo "Invalid choice!" ;;
    esac
done