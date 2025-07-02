#!/bin/bash

CONFIG_DIR="$(pwd)/configFiles"
DANTED_CONFIG="/etc/danted.conf"

# Function to display the main menu
show_main_menu() {
    clear
    echo "========================================"
    echo "  Danted SOCKS5 Proxy Management Script "
    echo "========================================"
    echo "1. Cài đặt Danted Proxy SOCKS5"
    echo "2. Hiển thị danh sách người dùng"
    echo "3. Thêm người dùng mới"
    echo "4. Xóa người dùng"
    echo "5. Kiểm tra hàng loạt proxy"
    echo "6. Gỡ cài đặt Danted hoàn toàn"
    echo "7. Thoát"
    echo "========================================"
    read -p "Vui lòng chọn một tùy chọn: " main_choice
}

# Function to display the add user submenu
show_add_user_submenu() {
    clear
    echo "========================================"
    echo "          Thêm người dùng mới           "
    echo "========================================"
    echo "1. Thêm một người dùng"
    echo "2. Thêm nhiều người dùng"
    echo "3. Quay lại menu chính"
    echo "========================================"
    read -p "Vui lòng chọn một tùy chọn: " add_user_choice
}

# Function to install Danted SOCKS5 Proxy
install_danted() {
    echo "Đang cài đặt Danted SOCKS5 Proxy..."

    # Check if Danted is already installed
    if dpkg -s dante-server &> /dev/null;
    then
        echo "Danted đã được cài đặt. Bỏ qua cài đặt."
    else
        sudo apt update
        sudo apt install -y dante-server
        if [ $? -ne 0 ]; then
            echo "Lỗi: Không thể cài đặt Danted. Vui lòng kiểm tra kết nối mạng hoặc thử lại sau."
            return 1
        fi
        echo "Danted đã được cài đặt thành công."
    fi

    echo "Đang lấy danh sách Network Interfaces..."
    interfaces=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+\sscope\sglobal\s\K\w+' | sort -u)
    if [ -z "$interfaces" ]; then
        echo "Lỗi: Không tìm thấy Network Interfaces nào. Vui lòng kiểm tra cấu hình mạng."
        return 1
    fi

    echo "Các Network Interfaces có sẵn và địa chỉ IP của chúng:"
    select_interface_options=()
    interface_ips=()
    i=1
    while IFS= read -r iface;
    do
        ip_addr=$(ip -4 addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        echo "$i. $iface ($ip_addr)"
        select_interface_options+=("$iface")
        interface_ips+=("$ip_addr")
        ((i++))
    done <<< "$interfaces"

    selected_interface_index=-1
    while [ $selected_interface_index -lt 1 ] || [ $selected_interface_index -gt ${#select_interface_options[@]} ];
    do
        read -p "Vui lòng chọn số của Network Interface để sử dụng: " selected_interface_index
    done

    NETWORK_INTERFACE=${select_interface_options[$selected_interface_index-1]}
    NETWORK_IP=${interface_ips[$selected_interface_index-1]}
    echo "Bạn đã chọn Network Interface: $NETWORK_INTERFACE ($NETWORK_IP)"

    read -p "Vui lòng nhập cổng (port) cho Danted Proxy (ví dụ: 1080): " PROXY_PORT
    while ! [[ "$PROXY_PORT" =~ ^[0-9]+$ ]] || [ "$PROXY_PORT" -lt 1 ] || [ "$PROXY_PORT" -gt 65535 ];
    do
        echo "Cổng không hợp lệ. Vui lòng nhập một số từ 1 đến 65535."
        read -p "Vui lòng nhập cổng (port) cho Danted Proxy (ví dụ: 1080): " PROXY_PORT
    done

    echo "Đang cấu hình Danted..."
    sudo tee $DANTED_CONFIG > /dev/null <<EOF
logoutput: syslog

internal: $NETWORK_INTERFACE port = $PROXY_PORT
external: $NETWORK_INTERFACE

clientmethod: none
user.privileged: root
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
}

client block {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    log: error connect disconnect
}

block {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}
EOF

    if [ $? -ne 0 ]; then
        echo "Lỗi: Không thể ghi cấu hình Danted."
        return 1
    fi

    echo "Đang khởi động lại dịch vụ Danted..."
    sudo systemctl restart dante-server
    if [ $? -ne 0 ]; then
        echo "Lỗi: Không thể khởi động lại dịch vụ Danted. Vui lòng kiểm tra cấu hình."
        return 1
    fi

    echo "Đang kiểm tra trạng thái dịch vụ Danted..."
    sudo systemctl status dante-server | grep "Active: active (running)"
    if [ $? -eq 0 ]; then
        echo "Danted SOCKS5 Proxy đã được cài đặt và chạy thành công trên $NETWORK_IP:$PROXY_PORT."
        echo "IP của bạn: $NETWORK_IP"
        echo "Port của bạn: $PROXY_PORT"
    else
        echo "Lỗi: Danted SOCKS5 Proxy không chạy. Vui lòng kiểm tra nhật ký hệ thống để biết thêm chi tiết."
    fi
}

# Function to uninstall Danted
uninstall_danted() {
    echo "Đang gỡ cài đặt Danted SOCKS5 Proxy..."
    sudo systemctl stop dante-server &> /dev/null
    sudo apt purge -y dante-server
    sudo apt autoremove -y
    if [ -f "$DANTED_CONFIG" ]; then
        sudo rm "$DANTED_CONFIG"
    fi
    echo "Danted SOCKS5 Proxy đã được gỡ cài đặt hoàn toàn."
}

# Function to list users
list_users() {
    echo "Danh sách người dùng đã tạo:\n"
    local users=()
    while IFS= read -r user_entry;
    do
        users+=("$user_entry")
    done < <(grep -E '^[^:]+:[^:]+:[0-9]+:[0-9]+:[^:]+:/bin/false$' /etc/passwd | cut -d: -f1)

    if [ ${#users[@]} -eq 0 ]; then
        echo "Không có người dùng nào được tạo."
        return
    fi

    for i in "${!users[@]}";
    do
        printf "%d. %s\n" $((i+1)) "${users[$i]}"
    done
}

# Function to create user config file
create_user_config_file() {
    local username=$1
    local password=$2
    local ip_address="$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)"
    local port=$(grep -oP '(?<=internal: .* port = )[0-9]+' $DANTED_CONFIG | head -1)
    local config_content="""
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
            "address": "$ip_address",
            "ota": false,
            "port": $port,
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
}
"""
    echo "$config_content" > "$CONFIG_DIR/$username"
    echo "Đã tạo file cấu hình cho người dùng '$username' tại $CONFIG_DIR/$username"
}

# Function to add a single user
add_single_user() {
    echo "Thêm một người dùng mới:"
    read -p "Nhập tên người dùng: " username
    if id "$username" &>/dev/null; then
        echo "Lỗi: Người dùng '$username' đã tồn tại. Vui lòng chọn tên khác."
        return 1
    fi

    read -s -p "Nhập mật khẩu cho người dùng '$username': " password
    echo

    sudo useradd -r -s /bin/false "$username"
    if [ $? -ne 0 ]; then
        echo "Lỗi: Không thể tạo người dùng hệ thống '$username'."
        return 1
    fi

    echo "$username:$password" | sudo chpasswd
    if [ $? -ne 0 ]; then
        echo "Lỗi: Không thể đặt mật khẩu cho người dùng '$username'."
        return 1
    fi

    echo "Người dùng '$username' đã được tạo thành công."

    # Create user config file
    create_user_config_file "$username" "$password"
}

# Function to add multiple users
add_multi_user() {
    echo "Thêm nhiều người dùng mới:"
    echo "Nhập danh sách người dùng (mỗi người dùng một dòng, nhấn Enter hai lần để kết thúc):"
    usernames=()
    while IFS= read -r line;
    do
        if [ -z "$line" ]; then
            break
        fi
        usernames+=("$line")
    done

    if [ ${#usernames[@]} -eq 0 ]; then
        echo "Không có người dùng nào được nhập."
        return
    fi

    for username in "${usernames[@]}";
    do
        if id "$username" &>/dev/null; then
            echo "Cảnh báo: Người dùng '$username' đã tồn tại. Bỏ qua."
            continue
        fi

        read -s -p "Nhập mật khẩu cho người dùng '$username': " password
        echo

        sudo useradd -r -s /bin/false "$username"
        if [ $? -ne 0 ]; then
            echo "Lỗi: Không thể tạo người dùng hệ thống '$username'. Bỏ qua."
            continue
        fi

        echo "$username:$password" | sudo chpasswd
        if [ $? -ne 0 ]; then
            echo "Lỗi: Không thể đặt mật khẩu cho người dùng '$username'. Bỏ qua."
            continue
        fi

        echo "Người dùng '$username' đã được tạo thành công."

        # Create user config file
        create_user_config_file "$username" "$password"
    done
}

# Function to delete users
delete_users() {
    echo "Xóa người dùng:"
    local users=()
    while IFS= read -r user_entry;
    do
        users+=("$user_entry")
    done < <(grep -E '^[^:]+:[^:]+:[0-9]+:[0-9]+:[^:]+:/bin/false$' /etc/passwd | cut -d: -f1)

    if [ ${#users[@]} -eq 0 ]; then
        echo "Không có người dùng nào để xóa."
        return
    fi

    echo "Danh sách người dùng có thể xóa:"
    for i in "${!users[@]}";
    do
        printf "%d. %s\n" $((i+1)) "${users[$i]}"
    done

    read -p "Nhập số của người dùng cần xóa (cách nhau bằng dấu cách, ví dụ: 1 3 5) hoặc 'all' để xóa tất cả: " choices

    if [ "$choices" == "all" ]; then
        for username in "${users[@]}";
        do
            sudo userdel -r "$username"
            if [ $? -eq 0 ]; then
                echo "Đã xóa người dùng '$username'."
                if [ -f "$CONFIG_DIR/$username" ]; then
                    rm "$CONFIG_DIR/$username"
                    echo "Đã xóa file cấu hình cho người dùng '$username'."
                fi
            else
                echo "Lỗi: Không thể xóa người dùng '$username'."
            fi
        done
    else
        for choice in $choices;
        do
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#users[@]} ]; then
                username=${users[$choice-1]}
                sudo userdel -r "$username"
                if [ $? -eq 0 ]; then
                    echo "Đã xóa người dùng '$username'."
                    if [ -f "$CONFIG_DIR/$username" ]; then
                        rm "$CONFIG_DIR/$username"
                        echo "Đã xóa file cấu hình cho người dùng '$username'."
                    fi
                else
                    echo "Lỗi: Không thể xóa người dùng '$username'."
                fi
            else
                echo "Lựa chọn '$choice' không hợp lệ. Bỏ qua."
            fi
        done
    fi
}

# Function to test multiple proxies
test_proxies() {
    echo "Kiểm tra hàng loạt proxy:"
    echo "Nhập danh sách proxy (mỗi proxy một dòng theo định dạng IP:port:username:password, nhấn Enter hai lần để kết thúc):"
    proxies=()
    while IFS= read -r line;
    do
        if [ -z "$line" ]; then
            break
        fi
        proxies+=("$line")
    done

    if [ ${#proxies[@]} -eq 0 ]; then
        echo "Không có proxy nào được nhập."
        return
    fi

    for proxy_entry in "${proxies[@]}";
    do
        IFS=":" read -r ip port username password <<< "$proxy_entry"
        if [ -z "$ip" ] || [ -z "$port" ] || [ -z "$username" ] || [ -z "$password" ]; then
            echo "Định dạng proxy không hợp lệ: $proxy_entry. Bỏ qua."
            continue
        fi

        echo "Đang kiểm tra proxy: $ip:$port với người dùng $username..."
        curl_proxy="socks5://$username:$password@$ip:$port"
        # Using a public IP check service to verify proxy functionality
        response=$(curl -s --proxy "$curl_proxy" https://api.ipify.org)

        if [ $? -eq 0 ]; then
            echo "Proxy $proxy_entry hoạt động. IP công cộng: $response"
        else
            echo "Proxy $proxy_entry không hoạt động hoặc có lỗi."
        fi
    done
}

# Main loop
while true;
do
    show_main_menu
    case $main_choice in
        1)
            install_danted
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        2)
            list_users
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        3)
            while true;
            do
                show_add_user_submenu
                case $add_user_choice in
                    1)
                        add_single_user
                        read -p "Nhấn Enter để tiếp tục..."
                        ;;
                    2)
                        add_multi_user
                        read -p "Nhấn Enter để tiếp tục..."
                        ;;
                    3)
                        break
                        ;;
                    *)
                        echo "Lựa chọn không hợp lệ. Vui lòng thử lại."
                        read -p "Nhấn Enter để tiếp tục..."
                        ;;
                esac
            done
            ;;
        4)
            delete_users
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        5)
            test_proxies
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        6)
            uninstall_danted
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        7)
            echo "Thoát khỏi chương trình."
            exit 0
            ;;
        *)
            echo "Lựa chọn không hợp lệ. Vui lòng thử lại."
            read -p "Nhấn Enter để tiếp tục..."
            ;;
    esac
done


