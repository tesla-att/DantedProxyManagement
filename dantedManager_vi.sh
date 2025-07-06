#!/bin/bash

# Quan ly SOCKS5 Proxy Danted v1.0
# Script chuyen nghiep quan ly may chu proxy SOCKS5 tren Ubuntu

# Mau sac cho dau ra
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

# Bien cau hinh
DANTED_CONFIG="/etc/danted.conf"
CONFIG_DIR="configFiles"
DANTED_SERVICE="danted"
SELECTED_IP=""
SELECTED_PORT=""

# Tao thu muc cau hinh neu chua co
if [[ ! -d "$CONFIG_DIR" ]]; then
    mkdir -p "$CONFIG_DIR" 2>/dev/null || {
        echo -e "${RED}Khong the tao thu muc cau hinh: $CONFIG_DIR${NC}"
        echo -e "${RED}Vui long kiem tra quyen tao thu muc.${NC}"
        exit 1
    }
fi

# Ham in mau sac
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Ham in tieu de chinh
print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}                        DANTED SOCKS5 PROXY MANAGER v1.0                      ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Ham in tieu de phan
print_section_header() {
    local title=$1
    local title_length=${#title}
    local padding=$((77 - title_length))
    
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────────────────────────┐${NC}"
    printf  "${BLUE}│${WHITE}${BOLD} %s${NC}${BLUE}%*s│${NC}\n" "$title" $padding ""
    echo -e "${BLUE}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

# Ham in hop thong tin
print_info_box() {
    local message=$1
    local color=${2:-$CYAN}
    local msg_length=${#message}
    local padding=$((77 - msg_length))
    
    echo -e "${color}┌─ THONG TIN ──────────────────────────────────────────────────────────────────┐${NC}"
    printf  "${color}│ %s%*s│${NC}\n" "$message" $padding ""
    echo -e "${color}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

# Ham in thong bao thanh cong
print_success() {
    local message=$1
    echo -e "${GREEN}✓${NC} ${GREEN}$message${NC}"
}

# Ham in thong bao loi
print_error() {
    local message=$1
    echo -e "${RED}✗${NC} ${RED}$message${NC}"
}

# Ham in thong bao canh bao
print_warning() {
    local message=$1
    echo -e "${YELLOW}⚠${NC} ${YELLOW}$message${NC}"
}

# Ham doc nhieu dong voi ho tro dan
read_multiline_input() {
    local prompt=$1
    local items=()
    local line_count=0
    
    print_color $YELLOW "$prompt"
    echo -e "${GRAY}Nhap du lieu (Nhap 1 user moi dong, nhan Enter 2 lan de ket thuc):${NC}"
    
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
                # Cat khoang trang
                line=$(echo "$line" | xargs)
                
                # Kiem tra trung lap
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
                    # In phan hoi ra stderr de khong bi bat trong ket qua tra ve
                    echo -e "  ✓ [$line_count] $line" >&2
                else
                    echo -e "  ⚠ Bo qua trung lap: $line" >&2
                fi
            fi
        fi
    done
    
    # Chi tra ve du lieu thuan tuy - xuat ra stdout
    for item in "${items[@]}"; do
        echo "$item"
    done
}

# Ham lay giao dien mang voi IP
get_network_interfaces() {
    print_section_header "Chon Giao Dien Mang"

    
    local interfaces=()
    local ips=()
    local counter=1
    
    # Tieu de voi chieu rong co dinh
    echo -e "${CYAN}┌─ Giao Dien Mang Co San ──────────────────────────────────────────────────────┐${NC}"
    printf "${CYAN}│${NC} ${WHITE}STT${NC} ${WHITE}Interface Name       ${WHITE}Dia Chi IP${NC}%*s${CYAN}│${NC}\n" 42 ""

    # Lap qua cac giao dien mang va IP
    while IFS= read -r line; do
        interface=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | awk '{print $2}')
        if [[ "$interface" != "lo" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            interfaces+=("$interface")
            ips+=("$ip")

            # Dinh dang ten giao dien va IP voi chieu rong co dinh
            local interface_padded=$(printf "%-20s" "$interface")
            local content_length=$((3 + 2 + 20 + 1 + ${#ip}))  # " XX. interface_name IP"
            local padding=$((78 - content_length))
            
            printf "${CYAN}│${NC} %2d. %s ${GREEN}%s${NC}%*s${CYAN}│${NC}\n" \
                $counter "$interface_padded" "$ip" $padding ""
            ((counter++))
        fi
    done < <(ip -4 addr show | grep -oP '^\d+: \K\w+|inet \K[^/]+' | paste - -)
    # Chan voi chieu rong co dinh
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        print_error "Khong tim thay giao dien mang nao!"
        return 1
    fi
    
    while true; do
        read -p "$(echo -e "${YELLOW}❯${NC} Chon so thu tu giao dien: ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#interfaces[@]} ]]; then
            SELECTED_IP="${ips[$((choice-1))]}"
            print_success "Da chon: ${interfaces[$((choice-1))]} - $SELECTED_IP"
            break
        else
            print_error "Lua chon khong hop le. Vui long thu lai."
        fi
    done
    return 0
}


# Ham hien thi thong tin he thong voi trang thai Dante
show_system_info() {
    # Thu thap thong tin he thong
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' | cut -d. -f1)
    memory_info=$(free -h | grep '^Mem:')
    memory_used=$(echo $memory_info | awk '{print $3}')
    memory_total=$(echo $memory_info | awk '{print $2}')
    disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    uptime_info=$(uptime -p | sed 's/up //')
    
    # Them bien de thu thap thong tin Dante
    dante_status="Khong ro"
    auto_start_status="Khong ro"
    listen_address="Khong ro"
    listen_port="Khong ro"
    active_connections="0"

    # Kiem tra trang thai dich vu Dante
    if systemctl is-active --quiet danted 2>/dev/null; then
        dante_status="Dang chay"
    elif systemctl is-failed --quiet danted 2>/dev/null; then
        dante_status="That bai"
    else
        dante_status="Da dung"
    fi

    # Kiem tra trang thai tu dong khoi dong
    if systemctl is-enabled --quiet danted 2>/dev/null; then
        auto_start_status="Da bat"
    else
        auto_start_status="Da tat"
    fi

    # Lay dia chi va cong nghe tu file cau hinh hoac netstat
    if [ -f /etc/danted.conf ]; then
        internal_line=$(grep -E "^[[:space:]]*internal:" /etc/danted.conf | head -1)
        if [ -n "$internal_line" ]; then
            # Trich xuat dia chi IP va cong tin cay hon
            listen_address=$(echo "$internal_line" | sed -n 's/.*internal:[[:space:]]*\([^[:space:]]*\).*/\1/p' | sed 's/port=.*//')
            listen_port=$(echo "$internal_line" | sed -n 's/.*port[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
            if [ -z "$listen_address" ]; then
                listen_address="Chua cau hinh"
                listen_port="Chua cau hinh"
            fi
        else
            listen_address="Chua cau hinh"
            listen_port="Chua cau hinh"
        fi
    else
        # Du phong: kiem tra tu netstat
        listen_port=$(netstat -tlnp 2>/dev/null | grep danted | head -1 | awk '{print $4}' | cut -d: -f2)
        if [ -z "$listen_port" ]; then
            listen_address="Khong tim thay"
            listen_port="Khong tim thay"
        else
            listen_address="0.0.0.0"
        fi
    fi

    # Dem ket noi dang hoat dong - don gian hoa
    active_connections="0"
    if command -v ss >/dev/null 2>&1; then
        conn_count=$(ss -tn 2>/dev/null | grep -E ":1080|:8080|:3128" | wc -l)
        active_connections="$conn_count"
    elif command -v netstat >/dev/null 2>&1; then
        conn_count=$(netstat -tn 2>/dev/null | grep -E ":1080|:8080|:3128" | wc -l)
        active_connections="$conn_count"
    fi

    # Ham in dong thong tin da dinh dang voi kiem soat chieu rong chinh xac
    print_info_line() {
        local label="$1"
        local value="$2"
        local color="$3"
        
        # Tinh do dai noi dung chinh xac
        local label_len=${#label}
        local value_len=${#value}
        local content_len=$((label_len + value_len + 3)) # ": " them 2, khoang trang them 1
        
        # Tong chieu rong hop la 79 ky tu (bao gom vien)
        # Vung noi dung la 78 ky tu
        local padding=$((78 - content_len))
        
        # Dam bao padding khong am
        if [ $padding -lt 0 ]; then
            padding=0
        fi
        
        printf "${CYAN}│${NC} %s: ${color}%s${NC}%*s${CYAN}│${NC}\n" "$label" "$value" $padding ""
    }

    # Tieu de
    echo -e "${CYAN}┌─ Thong Tin He Thong ─────────────────────────────────────────────────────────┐${NC}"

    # Thong tin he thong
    print_info_line "CPU Usage" "${cpu_usage}%" "${GREEN}"
    
    # Dinh dang bo nho
    memory_display="${memory_used} / ${memory_total}"
    if [[ ${#memory_display} -gt 25 ]]; then
        memory_display="${memory_used}/${memory_total}"
    fi
    print_info_line "Memory Usage" "$memory_display" "${GREEN}"
    
    print_info_line "Disk Usage" "$disk_usage" "${GREEN}"
    print_info_line "Uptime" "$uptime_info" "${GREEN}"

    # Duong phan cach
    echo -e "${CYAN}├──────────────────────────────────────────────────────────────────────────────┤${NC}"

    # Thong tin Dante
    dante_color="${GREEN}"
    if [ "$dante_status" != "Dang chay" ]; then
        dante_color="${RED}"
    fi
    print_info_line "Dante Status" "$dante_status" "$dante_color"

    autostart_color="${GREEN}"
    if [ "$auto_start_status" != "Enabled" ]; then
        autostart_color="${YELLOW}"
    fi
    print_info_line "Auto Start" "$auto_start_status" "$autostart_color"

    print_info_line "Listen Address" "$listen_address"    "${GREEN}"
    print_info_line "Listen Port" "$listen_port"    "${YELLOW}"
    print_info_line "Active Connections" "$active_connections" "${GREEN}"

    # Chan
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
}

# Ham kiem tra trang thai dich vu
check_service_status() {
    print_header
    print_section_header "Trang Thai Dich Vu & Giam Sat He Thong"
       
    # Goi ham
    show_system_info
    echo
    
    # Nhat ky gan day - Chieu rong co dinh voi goc bo tron
    echo -e "${CYAN}┌─ Nhat Ky Dich Vu Gan Day ────────────────────────────────────────────────────┐${NC}"
    
    # Tieu de nhat ky
    local log_header="5 nhat ky cuoi tu 1 gio truoc:"
    local log_header_length=$((${#log_header} + 1))
    local log_header_padding=$((78 - log_header_length))
    printf "${CYAN}│${NC} ${GRAY}%s${NC}%*s${CYAN}│${NC}\n" "$log_header" $log_header_padding ""
    
    # Hien thi nhat ky
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        if journalctl -u $DANTED_SERVICE --no-pager -n 5 --since "1 hour ago" 2>/dev/null | grep -q "."; then
            journalctl -u $DANTED_SERVICE --no-pager -n 5 --since "1 hour ago" 2>/dev/null | while read -r line; do
                # Cat cac dong nhat ky dai de phu hop trong hop
                if [[ ${#line} -gt 73 ]]; then
                    line="${line:0:70}..."
                fi
                local line_length=$((${#line} + 1))
                local line_padding=$((78 - line_length))
                printf "${CYAN}│${NC} ${GRAY}%s${NC}%*s${CYAN}│${NC}\n" "$line" $line_padding ""
            done
        else
            local no_logs="Khong tim thay nhat ky gan day"
            local no_logs_length=$((${#no_logs} + 1))
            local no_logs_padding=$((78 - no_logs_length))
            printf "${CYAN}│${NC} ${GRAY}%s${NC}%*s${CYAN}│${NC}\n" "$no_logs" $no_logs_padding ""
        fi
    else
        local log_warning="Dich vu Danted khong chay. Khong co nhat ky."
        local log_warning_length=$((${#log_warning} + 1))
        local log_warning_padding=$((78 - log_warning_length))
        printf "${CYAN}│${NC} ${YELLOW}%s${NC}%*s${CYAN}│${NC}\n" "$log_warning" $log_warning_padding ""
    fi
    
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo

    # Tuy chon dieu khien voi dinh dang hop
    echo -e "${YELLOW}┌─ Tuy Chon Dieu Khien ────────────────────────────────────────────────────────┐${NC}"

    local control_items=(
        "1. Khoi Dong Lai Dich Vu"
        "2. Dung Dich Vu"           
        "3. Thay Doi Cong"
        "4. Kiem Tra Toc Do Internet"
        "5. Nhat Ky Day Du"
        "6. Quay Lai Menu Chinh"
    )

    for item in "${control_items[@]}"; do
        local item_length=$((${#item} + 1))  # +1 cho khoang trang dau
        local item_padding=$((78 - item_length))
        printf "${YELLOW}│${NC} ${CYAN}%s${NC}%*s${YELLOW}│${NC}\n" "$item" $item_padding ""
    done

    echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    while true; do
        read -p "$(echo -e "${YELLOW}❯${NC} Chon tuy chon [1-6]: ")" choice
        
        case $choice in
            1)
                print_color $YELLOW "Dang khoi dong lai dich vu Danted..."
                if systemctl restart $DANTED_SERVICE; then
                    print_success "Dich vu da khoi dong lai thanh cong!"
                else
                    print_error "Khong the khoi dong lai dich vu!"
                fi
                sleep 2
                check_service_status
                return
                ;;
            2)
                print_color $YELLOW "Dang dung dich vu Danted..."
                if systemctl stop $DANTED_SERVICE; then
                    print_success "Dich vu da dung thanh cong!"
                else
                    print_error "Khong the dung dich vu!"
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
                test_bandwidth
                check_service_status
                return
                ;;
            5)
                print_section_header "Nhat Ky Day Du Dich Vu"
                journalctl -u $DANTED_SERVICE --no-pager -n 50
                echo
                read -p "Nhan Enter de tiep tuc..."
                check_service_status
                return
                ;;
            6)
                break
                ;;
            *)
                print_error "Tuy chon khong hop le!"
                ;;
        esac
    done
}

# Ham thay doi cong
change_port() {
    print_header
    print_section_header "Thay Doi Cong Danted"
    
    # Kiem tra neu Danted da cai dat
    if [ ! -f "$DANTED_CONFIG" ]; then
        print_error "Danted chua duoc cai dat hoac cau hinh!"
        print_warning "Vui long cai dat Danted truoc."
        echo
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    # Lay cong hien tai
    local current_port=""
    if [ -f "$DANTED_CONFIG" ]; then
        current_port=$(grep -E "^[[:space:]]*internal:" "$DANTED_CONFIG" | head -1 | sed -n 's/.*port[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
    fi
    
    if [ -z "$current_port" ]; then
        current_port="Chua cau hinh"
    fi
    
    echo -e "${CYAN}┌─ Cau Hinh Hien Tai ──────────────────────────────────────────────────────────┐${NC}"
    printf "${CYAN}${NC} Cong Hien Tai: ${YELLOW}%s${NC}%*s${CYAN}${NC}\n" "$current_port" 60 ""
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    # Lay cong moi
    while true; do
        read -p "$(echo -e "${YELLOW}❯${NC} Nhap cong moi (1-65535): ")" new_port
        
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [[ $new_port -ge 1 ]] && [[ $new_port -le 65535 ]]; then
            # Kiem tra neu cong da duoc su dung
            if netstat -tuln 2>/dev/null | grep -q ":$new_port "; then
                print_error "Cong $new_port da duoc su dung!"
                read -p "$(echo -e "${YELLOW}❯${NC} Ban co muon tiep tuc? (Y/N): ")" continue_anyway
                if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                    continue
                fi
            fi
            break
        else
            print_error "So cong khong hop le. Vui long nhap so tu 1-65535."
        fi
    done
    
    echo
    print_warning "Dieu nay se khoi dong lai dich vu Danted."
    read -p "$(echo -e "${YELLOW}❯${NC} Tiep tuc? (Y/N): ")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Thao tac da huy."
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    echo
    print_color $YELLOW "Dang thay doi cong thanh $new_port..."
    
    # Sao luu cau hinh hien tai
    cp "$DANTED_CONFIG" "${DANTED_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Lay dia chi IP hien tai
    local current_ip=""
    if [ -f "$DANTED_CONFIG" ]; then
        current_ip=$(grep -E "^[[:space:]]*internal:" "$DANTED_CONFIG" | head -1 | sed -n 's/.*internal:[[:space:]]*\([^[:space:]]*\).*/\1/p' | sed 's/port=.*//')
    fi
    
    if [ -z "$current_ip" ]; then
        current_ip="0.0.0.0"
    fi
    
    # Cap nhat file cau hinh
    sed -i "s/^[[:space:]]*internal:.*/internal: $current_ip port = $new_port/" "$DANTED_CONFIG"
    
    if [ $? -eq 0 ]; then
        print_success "Cau hinh da cap nhat thanh cong!"
        
        # Khoi dong lai dich vu
        print_color $YELLOW "Dang khoi dong lai dich vu Danted..."
        if systemctl restart $DANTED_SERVICE; then
            sleep 2
            if systemctl is-active --quiet $DANTED_SERVICE; then
                print_success "Dich vu da khoi dong lai thanh cong!"
                print_success "Cong moi: $new_port"
            else
                print_error "Dich vu khong the khoi dong voi cong moi!"
                print_warning "Dang khoi phuc cau hinh truoc..."
                cp "${DANTED_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)" "$DANTED_CONFIG"
                systemctl restart $DANTED_SERVICE
            fi
        else
            print_error "Khong the khoi dong lai dich vu!"
            print_warning "Dang khoi phuc cau hinh truoc..."
            cp "${DANTED_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)" "$DANTED_CONFIG"
        fi
    else
        print_error "Khong the cap nhat cau hinh!"
    fi
    
    echo
    read -p "Nhan Enter de tiep tuc..."
}

# Ham kiem tra bang thong
test_bandwidth() {
    clear
    print_header
    print_section_header "Kiem Tra Toc Do Internet"
    
    # Nhieu may chu kiem tra de do chinh xac cao hon
    local test_servers=(
        "http://speedtest.ftp.otenet.gr/files/test1Mb.db"
        "http://speedtest.ftp.otenet.gr/files/test10Mb.db"
        "http://ipv4.download.thinkbroadband.com/10MB.zip"
        "http://speedtest.tele2.net/1MB.zip"
    )
    
    # Ham dinh dang toc do
    format_speed() {
        local speed=$1
        if (( $(echo "$speed >= 1000" | bc -l 2>/dev/null || echo "0") )); then
            echo "$(echo "scale=2; $speed / 1000" | bc -l 2>/dev/null || echo "0") Gbps"
        else
            echo "$(echo "scale=2; $speed" | bc -l 2>/dev/null || echo "0") Mbps"
        fi
    }
    
    # Ham kiem tra mot may chu
    test_single_server() {
        local server_url=$1
        local server_name=$(echo "$server_url" | sed 's|.*//||' | sed 's|/.*||')
        
        print_color $CYAN "Dang kiem tra voi: $server_name"
        
        # Kiem tra toc do tai xuong
        local speed_result=$(curl -s -w "%{speed_download}" -o /dev/null --connect-timeout 10 --max-time 30 "$server_url" 2>/dev/null)
        
        if [[ "$speed_result" =~ ^[0-9]+\.?[0-9]*$ ]] && (( $(echo "$speed_result > 0" | bc -l 2>/dev/null || echo "0") )); then
            local speed_mbps=$(echo "scale=2; $speed_result / 1024 / 1024 * 8" | bc -l 2>/dev/null || echo "0")
            print_success "Toc do: $(format_speed $speed_mbps)"
            echo "$speed_mbps"
        else
            print_error "Khong the kiem tra voi $server_name"
            echo "0"
        fi
    }
    
    # Kiem tra ket noi truc tiep
    print_color $YELLOW "Dang kiem tra ket noi internet truc tiep..."
    print_color $YELLOW "Co the mat mot luc... Vui long doi..."
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
        print_error "Tat ca cac kiem tra toc do deu that bai!"
        print_warning "Vui long kiem tra ket noi internet cua ban."
        echo
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    # Tinh toc do trung binh
    local total_speed=0
    for speed in "${speeds[@]}"; do
        total_speed=$(echo "$total_speed + $speed" | bc -l 2>/dev/null || echo "0")
    done
    local avg_speed=$(echo "scale=2; $total_speed / $valid_tests" | bc -l 2>/dev/null || echo "0")
    
    # Hien thi ket qua
    echo -e "${CYAN}┌─ Ket Qua Kiem Tra Ket Noi Truc Tiep ─────────────────────────────────────────┐${NC}"
    printf "${CYAN}${NC} Kiem Tra Hop Le: ${GREEN}%d${NC}%*s${CYAN}${NC}\n" $valid_tests 60 ""
    printf "${CYAN}${NC} Toc Do TB:       ${GREEN}%s${NC}%*s${CYAN}${NC}\n" "$(format_speed $avg_speed)" 60 ""
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    # Hoi user co muon kiem tra proxy khong
    echo
    read -p "$(echo -e "${YELLOW}❯${NC} Ban co muon kiem tra toc do proxy? (Y/N): ")" test_proxies
    
    if [[ "$test_proxies" =~ ^[Yy]$ ]]; then
        test_proxy_speeds "$avg_speed"
    fi
    
    echo
    read -p "Nhan Enter de tiep tuc..."
}

# Ham kiem tra toc do proxy
test_proxy_speeds() {
    local direct_speed=$1
    
    print_section_header "Kiem Tra Toc Do Proxy"
    
    # Hien thi vi du dinh dang
    echo -e "${YELLOW}Dinh dang: ${WHITE}IP:CONG:TEN_DANG_NHAP:MAT_KHAU${NC}"
    echo -e "${GRAY}Vi du:${NC}"
    echo -e "  ${CYAN}100.150.200.250:30500:user1:pass123${NC}"
    echo -e "${GRAY}Nhap mot proxy moi dong, Nhan Enter 2 lan de ket thuc.${NC}"
    echo
    
    # Doc danh sach proxy su dung nhap nhieu dong
    local proxies_input
    exec 3>&1 4>&2
    proxies_input=$(read_multiline_input "Nhap danh sach proxy:" 2>&4)
    exec 3>&- 4>&-
    
    if [[ -z "$proxies_input" ]]; then
        print_error "Khong co proxy nao duoc cung cap!"
        return
    fi
    
    # Phan tich proxy
    local proxies=()
    while IFS= read -r proxy_line; do
        if [[ -n "$proxy_line" ]]; then
            proxy_line=$(echo "$proxy_line" | xargs)
            local colon_count=$(echo "$proxy_line" | tr -cd ':' | wc -c)
            if [[ $colon_count -eq 3 ]]; then
                IFS=':' read -r ip port user pass <<< "$proxy_line"
                if [[ -n "$ip" && -n "$port" && -n "$user" && -n "$pass" ]]; then
                    if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
                        # Kiem tra trung lap
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
        print_error "Khong co proxy hop le nao duoc cung cap!"
        return
    fi
    
    echo
    print_color $CYAN "Dang kiem tra ${#proxies[@]} proxy..."
    echo
    
    # May chu kiem tra cho kiem tra proxy (file nho hon de kiem tra nhanh hon)
    local proxy_test_servers=(
        "http://speedtest.ftp.otenet.gr/files/test1Mb.db"
        "http://ipv4.download.thinkbroadband.com/1MB.zip"
    )
    
    # Ham dinh dang toc do
    format_speed() {
        local speed=$1
        if (( $(echo "$speed >= 1000" | bc -l 2>/dev/null || echo "0") )); then
            echo "$(echo "scale=2; $speed / 1000" | bc -l 2>/dev/null || echo "0") Gbps"
        else
            echo "$(echo "scale=2; $speed" | bc -l 2>/dev/null || echo "0") Mbps"
        fi
    }
    
    # Ham kiem tra mot proxy
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
        
        # Kiem tra ket noi proxy truoc
        if ! timeout 10 curl -s --proxy "$curl_proxy" --connect-timeout 5 -I http://httpbin.org/ip >/dev/null 2>&1; then
            printf "${CYAN}${NC} %s %-25s ${RED}✗ KET NOI THAT BAI${NC}%*s${CYAN}${NC}\n" \
                "$progress_indicator" "$display_proxy" 30 ""
            return
        fi
        
        # Kiem tra toc do voi nhieu may chu
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
            
            # Ma mau dua tren hieu suat
            local speed_color=$GREEN
            if (( $(echo "$speed_percentage < 50" | bc -l 2>/dev/null || echo "0") )); then
                speed_color=$RED
            elif (( $(echo "$speed_percentage < 80" | bc -l 2>/dev/null || echo "0") )); then
                speed_color=$YELLOW
            fi
            
            printf "${CYAN}${NC} %s %-25s ${speed_color}%s${NC} (${speed_color}%.1f%%${NC})%*s${CYAN}${NC}\n" \
                "$progress_indicator" "$display_proxy" "$(format_speed $avg_speed)" "$speed_percentage" 15 ""
        else
            printf "${CYAN}${NC} %s %-25s ${RED}✗ KIEM TRA TOC DO THAT BAI${NC}%*s${CYAN}${NC}\n" \
                "$progress_indicator" "$display_proxy" 20 ""
        fi
    }
    
    # Hien thi tieu de ket qua
    echo -e "${CYAN}┌─ Ket Qua Kiem Tra Toc Do Proxy ──────────────────────────────────────────────┐${NC}"
    printf "${CYAN}${NC} Toc Do Truc Tiep: ${GREEN}%s${NC}%*s${CYAN}${NC}\n" "$(format_speed $direct_speed)" 60 ""
    echo -e "${CYAN}├──────────────────────────────────────────────────────────────────────────────┤${NC}"
    
    # Kiem tra tung proxy
    for i in "${!proxies[@]}"; do
        test_single_proxy "${proxies[i]}" $((i+1)) ${#proxies[@]}
    done
    
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    # Giai thich
    echo
    echo -e "${GRAY}Giai thich:${NC}"
    echo -e "  ${GREEN}Xanh${NC}: 80-100% toc do truc tiep"
    echo -e "  ${YELLOW}Vang${NC}: 50-79% toc do truc tiep"
    echo -e "  ${RED}Do${NC}: Duoi 50% toc do truc tiep"
}

# Ham cai dat Danted
install_danted() {
    print_header
    print_section_header "Cai Dat May Chu SOCKS5 Proxy Danted"    
    
    # Kiem tra neu da cai dat
    if systemctl is-active --quiet $DANTED_SERVICE 2>/dev/null; then
        print_warning "Danted da duoc cai dat va dang chay."
        echo -e "${YELLOW}Ban co the cai dat lai, nhung dieu nay se dung dich vu hien tai.${NC}"
        read -p "$(echo -e "${YELLOW}❯${NC} Ban co muon cai dat lai? (Y/N): ")" reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return
        fi
        systemctl stop $DANTED_SERVICE 2>/dev/null
        print_color $YELLOW "Dang dung dich vu Danted hien tai..."
    fi
    
    # Lay giao dien mang
    if ! get_network_interfaces; then
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    # Lay cong
    echo
    while true; do
        read -p "$(echo -e "${YELLOW}❯${NC} Nhap cong SOCKS5 (mac dinh: 1080): ")" port
        port=${port:-1080}
        if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
            if ! netstat -tuln 2>/dev/null | grep -q ":$port "; then
                SELECTED_PORT="$port"
                break
            else
                print_error "Cong $port da duoc su dung. Vui long chon cong khac."
                
            fi
        else
            print_error "So cong khong hop le. Vui long nhap so tu 1-65535."
        fi
    done
    
    echo
    print_info_box "Dang cai dat May chu SOCKS5 Proxy Danted. Vui long doi..."
    
    # Cap nhat danh sach goi
    echo -e "${GRAY}Dang cap nhat danh sach goi...${NC}"
    apt update -qq
    
    # Cai dat Danted
    echo -e "${GRAY}Dang cai dat dante-server...${NC}"
    if ! apt install -y dante-server >/dev/null 2>&1; then
        print_error "Khong the cai dat Danted!"
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    # Tao cau hinh Danted
    echo -e "${GRAY}Dang tao cau hinh...${NC}"
    cat > "$DANTED_CONFIG" << 'EOF'
# Cau hinh SOCKS5 Proxy Danted
logoutput: /var/log/danted.log
internal: SELECTED_IP_PLACEHOLDER port = SELECTED_PORT_PLACEHOLDER
external: SELECTED_IP_PLACEHOLDER

# Phuong thuc xac thuc
socksmethod: username

# Quy tac khach hang
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
}

# Quy tac SOCKS
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
    socksmethod: username
}
EOF
    
    # Thay the cac bien gia
    sed -i "s/SELECTED_IP_PLACEHOLDER/$SELECTED_IP/g" "$DANTED_CONFIG"
    sed -i "s/SELECTED_PORT_PLACEHOLDER/$SELECTED_PORT/g" "$DANTED_CONFIG"
    
    # Bat va khoi dong dich vu
    echo -e "${GRAY}Dang khoi dong dich vu...${NC}"
    systemctl enable $DANTED_SERVICE >/dev/null 2>&1
    systemctl restart $DANTED_SERVICE
    
    # Kiem tra trang thai
    sleep 2
    echo
    if systemctl is-active --quiet $DANTED_SERVICE; then
        print_success "Danted da cai dat va khoi dong thanh cong!"
        print_success "Dang nghe tren: $SELECTED_IP:$SELECTED_PORT"
        print_success "Trang thai dich vu: Hoat dong"
    else
        print_error "Khong the khoi dong dich vu Danted!"
        print_warning "Dang kiem tra nhat ky..."
        journalctl -u $DANTED_SERVICE --no-pager -n 10
    fi
    
    echo
    read -p "Nhan Enter de tiep tuc..."
}

# Ham hien thi user
show_users() {
    print_header
    print_section_header "user SOCKS5 Proxy"

    local users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            users+=("$user")
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1 | sort)

    if [[ ${#users[@]} -eq 0 ]]; then
        # Trang thai trong voi dinh dang hop dung
        echo -e "${CYAN}┌─ Danh Sach user (0 user) ────────────────────────────────────────┐${NC}"
        local warning_msg="Khong tim thay user SOCKS5 nao."
        local warning_length=$((${#warning_msg} + 1))
        local warning_padding=$((78 - warning_length))
        printf "${CYAN}│${NC} ${YELLOW}%s${NC}%*s${CYAN}│${NC}\n" "$warning_msg" $warning_padding ""
        echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    else
        # Tieu de voi so luong user
        local header_title="Danh Sach user (${#users[@]} user)"
        local header_length=${#header_title}
        local header_padding=$((77 - header_length))  # 78 - 6 (cho "─ " va " ") = 69

        printf "${CYAN}┌ %s" "$header_title"
        for ((i=0; i<$header_padding; i++)); do printf "─"; done
        printf "┐${NC}\n"

        # Hien thi user voi dinh dang dung
        for i in "${!users[@]}"; do
            local user_number=$(printf "%3d." $((i+1)))
            local user_display="$user_number ${users[i]}"
            local user_length=$((${#user_display} + 1))  # +1 cho khoang trang dau
            local user_padding=$((78 - user_length))

            printf "${CYAN}│${NC} %s%*s${CYAN}│${NC}\n" "$user_display" $user_padding ""
        done

        echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    fi

    echo
    read -p "Nhan Enter de tiep tuc..."
}

# Ham tao file cau hinh cho user
create_user_config() {
    local username=$1
    local password=$2
    
    # Dam bao thu muc cau hinh ton tai
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
        if [[ $? -ne 0 ]]; then
            print_error "Khong the tao thu muc cau hinh: $CONFIG_DIR"
            return 1
        fi
    fi
    
    if [[ -z "$SELECTED_IP" || -z "$SELECTED_PORT" ]]; then
        # Thu lay tu cau hinh hien tai
        if [[ -f "$DANTED_CONFIG" ]]; then
            internal_line=$(grep -E "^[[:space:]]*internal:" "$DANTED_CONFIG" | head -1)
            if [ -n "$internal_line" ]; then
                SELECTED_IP=$(echo "$internal_line" | sed -n 's/.*internal:[[:space:]]*\([^[:space:]]*\).*/\1/p' | sed 's/port=.*//')
                SELECTED_PORT=$(echo "$internal_line" | sed -n 's/.*port[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
            fi
        fi
    fi
    
    if [[ -z "$SELECTED_IP" || -z "$SELECTED_PORT" ]]; then
        print_error "IP va cong may chu chua duoc cau hinh. Vui long cai dat Danted truoc."
        return 1
    fi
    
    # Tao noi dung cau hinh
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
        print_error "Khong the tao file cau hinh cho user: $username"
        return 1
    fi
}

# Ham them nhieu user
add_multi_users() {
    print_header
    print_section_header "Them Nhieu user"

    echo -e "${GRAY}Nhap du lieu (Nhap 1 user moi dong, nhan Enter 2 lan de ket thuc):${NC}"
    # Doc ten user su dung nhap nhieu dong
    local usernames_input
    usernames_input=$(read_multiline_input "Nhap ten user (mot dong mot ten):")
    if [[ -z "$usernames_input" ]]; then
        print_error "Khong co ten user nao duoc cung cap!"
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    # Phan tich ten user - XAC THUC THAU LAM (KHONG CO THONG BAO LOI)
    local usernames=()
    local line_num=0
    while IFS= read -r username; do
        ((line_num++))
        # Bo qua dong trong
        [[ -z "$username" ]] && continue
        
        # Cat khoang trang
        username=$(echo "$username" | xargs)
        
        if [[ -n "$username" ]]; then
            if [[ "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                if id "$username" &>/dev/null; then
                    print_error "user '$username' da ton tai! Bo qua..."
                else
                    usernames+=("$username")
                fi
            fi
        fi
    done <<< "$usernames_input"
    
    if [[ ${#usernames[@]} -eq 0 ]]; then
        print_error "Khong co ten user hop le nao duoc cung cap!"
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    echo
    print_info_box "Dang tao ${#usernames[@]} user..."
    echo
    
    # Tao user va dat mat khau
    local created_users=()
    for username in "${usernames[@]}"; do
        echo -e "${CYAN}Dang thiet lap user: ${WHITE}$username${NC}"
        
        while true; do
            read -s -p "$(echo -e "${YELLOW}❯${NC} Dat mat khau cho '$username': ")" password
            echo
            if [[ ${#password} -ge 4 ]]; then
                read -s -p "$(echo -e "${YELLOW}❯${NC} Xac nhan mat khau cho '$username': ")" password2
                echo
                if [[ "$password" == "$password2" ]]; then
                    if useradd -r -s /bin/false "$username" 2>/dev/null; then
                        if echo "$username:$password" | chpasswd 2>/dev/null; then
                            if create_user_config "$username" "$password"; then
                                created_users+=("$username")
                                print_success "user '$username' da tao thanh cong!"
                            else
                                print_warning "user '$username' da tao nhung file cau hinh that bai!"
                                created_users+=("$username")
                            fi
                        else
                            print_error "Khong the dat mat khau cho user '$username'!"
                            userdel "$username" 2>/dev/null
                        fi
                    else
                        print_error "Khong the tao user '$username'!"
                    fi
                    break
                else
                    print_error "Mat khau khong khop cho '$username'!"
                fi
            else
                print_error "Mat khau cho '$username' phai co it nhat 4 ky tu!"
            fi
        done
        echo
    done
    
    echo
    print_success "Da tao thanh cong ${#created_users[@]} user!"
    print_success "File cau hinh da tao trong: $CONFIG_DIR/"
    
    echo
    read -p "Nhan Enter de tiep tuc..."
}

# Ham xoa user
delete_users() {
    print_header
    print_section_header "Xoa user"
    
    local users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            users+=("$user")
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1 | sort)
    
    if [[ ${#users[@]} -eq 0 ]]; then
        print_warning "Khong tim thay user SOCKS5 nao de xoa."
        read -p "Nhan Enter de tiep tuc..."
        return
    fi

    echo
    echo -e "${CYAN}┌─ user Co San De Xoa ───────────────────────────────────────────────────┐${NC}"
    for i in "${!users[@]}"; do
        local user_number=$(printf "%3d." $((i+1)))
        local user_display="$user_number ${users[i]}"
        local user_length=$((${#user_display} + 1))  # +1 cho khoang trang dau
        local user_padding=$((78 - user_length))
        
        printf "${CYAN}│${NC} %s%*s${CYAN}│${NC}\n" "$user_display" $user_padding ""
    done
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
        
    print_info_box "Nhap so thu tu user de xoa (cach nhau bang dau cach, vi du '1 3 5'):"
    read -p "$(echo -e "${YELLOW}❯${NC} Lua chon: ")" selections
    
    if [[ -z "$selections" ]]; then
        print_warning "Khong co lua chon nao."
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    local to_delete=()
    for selection in $selections; do
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#users[@]} ]]; then
            to_delete+=("${users[$((selection-1))]}")
        else
            print_error "Lua chon khong hop le: $selection"
        fi
    done
    
    if [[ ${#to_delete[@]} -eq 0 ]]; then
        print_error "Khong co user hop le nao duoc chon!"
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    echo
    print_warning "user se bi xoa:"
    for user in "${to_delete[@]}"; do
        echo -e "  ${RED}•${NC} $user"
    done
    
    echo
    read -p "$(echo -e "${RED}❯${NC} Ban co chac chan muon xoa cac user nay? (Y/N): ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Thao tac da huy."
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    echo
    print_color $YELLOW "Dang xoa user..."
    
    # Xoa user
    local deleted_count=0
    for user in "${to_delete[@]}"; do
        if userdel "$user" 2>/dev/null; then
            # Xoa file cau hinh
            rm -f "$CONFIG_DIR/$user"
            print_success "Da xoa user: $user"
            ((deleted_count++))
        else
            print_error "Khong the xoa user: $user"
        fi
    done
    
    echo
    print_success "Da xoa thanh cong $deleted_count user!"
    
    echo
    read -p "Nhan Enter de tiep tuc..."
}

# Ham kiem tra proxy
test_proxies() {
    clear
    print_header
    print_section_header "Kiem Tra Proxy"
    
    # Hien thi vi du dinh dang ro rang
    echo -e "${YELLOW}Dinh dang: ${WHITE}IP:CONG:TEN_DANG_NHAP:MAT_KHAU${NC}"
    echo -e "${GRAY}Vi du:${NC}"
    echo -e "  ${CYAN}100.150.200.250:30500:user1:pass123${NC}"
    echo -e "  ${CYAN}192.168.1.100:1080:alice:secret456${NC}"
    echo -e "${GRAY}Nhap mot proxy moi dong, Nhan Enter 2 lan de ket thuc.${NC}"
    echo
    
    # Doc danh sach proxy su dung nhap nhieu dong
    local proxies_input
    # Chuyen huong stderr de hien thi phan hoi, bat chi stdout (du lieu thuan tuy)
    exec 3>&1 4>&2
    proxies_input=$(read_multiline_input "Nhap danh sach proxy:" 2>&4)
    exec 3>&- 4>&-
    
    if [[ -z "$proxies_input" ]]; then
        print_error "Khong co proxy nao duoc cung cap!"
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    echo
    
    # Phan tich proxy voi xac thuc thau lam (khong co thong bao loi)
    local proxies=()
    local line_num=0
    local valid_count=0
    local invalid_count=0
    
    # Xu ly tung dong tu input
    while IFS= read -r proxy_line; do
        ((line_num++))
        
        # Bo qua dong trong
        if [[ -z "$proxy_line" ]]; then
            continue
        fi
        
        # Cat khoang trang
        proxy_line=$(echo "$proxy_line" | xargs)
        
        # Bo qua neu van trong sau khi cat
        if [[ -z "$proxy_line" ]]; then
            continue
        fi
        
        # Xac thuc don gian: dem dau hai cham va kiem tra dinh dang co ban
        local colon_count=$(echo "$proxy_line" | tr -cd ':' | wc -c)
        
        if [[ $colon_count -eq 3 ]]; then
            # Tach va xac thuc cac thanh phan
            IFS=':' read -r ip port user pass <<< "$proxy_line"
            
            # Kiem tra neu tat ca cac thanh phan ton tai va cong la so
            if [[ -n "$ip" && -n "$port" && -n "$user" && -n "$pass" ]]; then
                if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
                    # Kiem tra trung lap trong mang proxies
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
                        print_color $GREEN "  ✓ Hop le: $proxy_line"
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
    
    # Hien thi tom tat thay vi loi chi tiet
    if [[ $invalid_count -gt 0 ]]; then
        print_warning "Da bo qua $invalid_count proxy khong hop le"
    fi
    
    if [[ ${#proxies[@]} -eq 0 ]]; then
        print_error "Khong co proxy hop le nao duoc cung cap!"
        if [[ $invalid_count -gt 0 ]]; then
            echo -e "${GRAY}Kiem tra dinh dang proxy: IP:CONG:TEN_DANG_NHAP:MAT_KHAU${NC}"
        fi
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    echo
    print_color $CYAN "Dang kiem tra ${#proxies[@]} proxy..."
    print_color $CYAN "Vui long doi..."   
    echo
    
    local success_count=0
    local total_count=${#proxies[@]}
    
# Ket qua kiem tra proxy voi dinh dang hop dung
    echo -e "${CYAN}┌─ Ket Qua Kiem Tra Proxy ──────────────────────────────────────────────────────┐${NC}"

    for i in "${!proxies[@]}"; do
        local proxy="${proxies[i]}"
        
        # Phan tich cac thanh phan proxy
        IFS=':' read -r ip port user pass <<< "$proxy"
        
        local curl_proxy="socks5://$user:$pass@$ip:$port"
        
        # Kiem tra voi timeout
        local display_proxy="${ip}:${port}@${user}"
        if [[ ${#display_proxy} -gt 30 ]]; then
            display_proxy="${display_proxy:0:27}..."
        fi
        
        # Tao chi bao tien trinh
        local progress_indicator=$(printf "[%2d/%2d]" $((i+1)) $total_count)
        
        # Kiem tra proxy truoc
        if timeout 10 curl -s --proxy "$curl_proxy" --connect-timeout 5 -I http://httpbin.org/ip >/dev/null 2>&1; then
            local result_text="${GREEN}✓ THANH CONG${NC}"
            ((success_count++))
        else
            local result_text="${RED}✗ THAT BAI${NC}"
        fi
        
        # Tinh padding dua tren do dai van ban thuc te (khong tinh ma mau)
        local progress_len=${#progress_indicator}
        local proxy_len=${#display_proxy}
        # Do dai thuc te cua result_text khong tinh ma mau
        local result_len=10  # "✓ THANH CONG" hoac "✗ THAT BAI" deu 10 ky tu
        
        # Tong noi dung: " " + progress + " " + proxy + " " + result + " "
        local total_content_len=$((1 + progress_len + 1 + proxy_len + 1 + result_len + 1))
        local padding=$((78 - total_content_len))
        
        # In dong da dinh dang
        printf "${CYAN}${NC} %s %-30s %b%*s${CYAN}${NC}\n" \
            "$progress_indicator" "$display_proxy" "$result_text" $padding ""
        
    done

    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    local success_rate=0
    if [[ $total_count -gt 0 ]]; then
        success_rate=$((success_count * 100 / total_count))
    fi
    
    echo
    echo -e "${CYAN}┌─ Tom Tat Kiem Tra ──────────────────────────────────────────────────────────┐${NC}"

    # Tong Proxy
    local total_text="Tong Proxy: $total_count"
    local total_length=$((${#total_text} + 1))
    local total_padding=$((78 - total_length))
    printf "${CYAN}${NC} Tong Proxy:      ${WHITE}%s${NC}%*s${CYAN}${NC}\n" "$total_count" $total_padding ""

    # Thanh cong
    local success_text="Thanh cong: $success_count"
    local success_length=$((${#success_text} + 1))
    local success_padding=$((78 - success_length))
    printf "${CYAN}${NC} Thanh Cong:      ${GREEN}%s${NC}%*s${CYAN}${NC}\n" "$success_count" $success_padding ""

    # That bai
    local failed_count=$((total_count - success_count))
    local failed_text="That bai: $failed_count"
    local failed_length=$((${#failed_text} + 1))
    local failed_padding=$((78 - failed_length))
    printf "${CYAN}${NC} That Bai:        ${RED}%s${NC}%*s${CYAN}${NC}\n" "$failed_count" $failed_padding ""

    # Ti le thanh cong
    local rate_text="Ti le thanh cong: ${success_rate}%"
    local rate_length=$((${#rate_text} + 1))
    local rate_padding=$((78 - rate_length))
    printf "${CYAN}${NC} Ti Le Thanh Cong: ${YELLOW}%s%%${NC}%*s${CYAN}${NC}\n" "$success_rate" $rate_padding ""

    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    echo
    read -p "Nhan Enter de tiep tuc..."
}

# Ham go cai dat Danted
uninstall_danted() {
    print_header
    print_section_header "Go Cai Dat Danted"
    
    echo -e "${RED}┌─ CANH BAO ───────────────────────────────────────────────────────────────────┐${NC}"

    # Dong canh bao dau tien
    local warning1="Dieu nay se xoa hoan toan Danted va tat ca cau hinh!"
    local warning1_length=$((${#warning1} + 1))
    local warning1_padding=$((78 - warning1_length))
    printf "${RED}│${NC} %s%*s${RED}│${NC}\n" "$warning1" $warning1_padding ""

    # Dong canh bao thu hai
    local warning2="Tat ca user proxy va file cau hinh se bi anh huong."
    local warning2_length=$((${#warning2} + 1))
    local warning2_padding=$((78 - warning2_length))
    printf "${RED}│${NC} %s%*s${RED}│${NC}\n" "$warning2" $warning2_padding ""

    echo -e "${RED}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    echo
    read -p "$(echo -e "${RED}❯${NC} Ban co chac chan muon go cai dat Danted? (Y/N): ")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Thao tac da huy."
        read -p "Nhan Enter de tiep tuc..."
        return
    fi
    
    echo
    print_color $YELLOW "Dang go cai dat Danted..."
    
    # Dung va vo hieu hoa dich vu
    echo -e "${GRAY}Dang dung dich vu...${NC}"
    systemctl stop $DANTED_SERVICE 2>/dev/null
    systemctl disable $DANTED_SERVICE 2>/dev/null
    
    # Xoa goi
    echo -e "${GRAY}Dang xoa goi...${NC}"
    apt remove --purge -y dante-server >/dev/null 2>&1
    
    # Xoa file cau hinh
    echo -e "${GRAY}Dang xoa file cau hinh...${NC}"
    rm -f "$DANTED_CONFIG"
    rm -f /var/log/danted.log
    
    # Hoi ve cau hinh user
    if [[ -d "$CONFIG_DIR" ]] && [[ $(ls -A "$CONFIG_DIR" 2>/dev/null) ]]; then
        echo
        read -p "$(echo -e "${YELLOW}❯${NC} Ban co muon xoa tat ca file cau hinh user trong '$CONFIG_DIR'? (Y/N): ")" remove_configs
        if [[ "$remove_configs" =~ ^[Yy]$ ]]; then
            rm -rf "$CONFIG_DIR"
            print_success "File cau hinh user da xoa"
        fi
    fi
    
    # Hoi ve user
    local socks_users=()
    while IFS= read -r user; do
        if id "$user" &>/dev/null && [[ $(getent passwd "$user" | cut -d: -f7) == "/bin/false" ]]; then
            socks_users+=("$user")
        fi
    done < <(getent passwd | grep '/bin/false' | cut -d: -f1)
    
    if [[ ${#socks_users[@]} -gt 0 ]]; then
        echo
        print_warning "Tim thay ${#socks_users[@]} user SOCKS5:"
        for user in "${socks_users[@]}"; do
            echo -e "  ${YELLOW}•${NC} $user"
        done
        echo
        read -p "$(echo -e "${YELLOW}❯${NC} Ban co muon xoa tat ca user SOCKS5? (Y/N): ")" remove_users
        if [[ "$remove_users" =~ ^[Yy]$ ]]; then
            for user in "${socks_users[@]}"; do
                userdel "$user" 2>/dev/null
                print_success "Da xoa user: $user"
            done
        fi
    fi
    
    echo
    print_success "Danted da duoc go cai dat hoan toan!"
    
    echo
    read -p "Nhan Enter de tiep tuc..."
}

# Ham menu chinh
show_main_menu() {
    print_header
    print_section_header "Menu Chinh"
    
    # Hop menu voi goc bo tron
    echo -e "${YELLOW}┌─ Tuy Chon Menu ──────────────────────────────────────────────────────────────┐${NC}"
    
    # Cac muc menu voi padding dung
    local menu_items=(
        "1. Cai Dat SOCKS5 Proxy Danted"
        "2. Hien Thi user"
        "3. Them user"
        "4. Xoa user"
        "5. Kiem Tra Proxy"
        "6. Kiem Tra Trang Thai & Giam Sat"
        "7. Go Cai Dat Danted"
        "8. Thoat"
    )
    
    for item in "${menu_items[@]}"; do
        local item_length=$((${#item} + 1))  # +1 cho khoang trang dau
        local item_padding=$((78 - item_length))
        printf "${YELLOW}│${NC} ${CYAN}%s${NC}%*s${YELLOW}│${NC}\n" "$item" $item_padding ""
    done
    
    echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

# Vong lap chuong trinh chinh
main() {
    # Kiem tra neu chay voi quyen root
    if [[ $EUID -ne 0 ]]; then
        print_error "Script nay phai chay voi quyen root!"
        print_warning "Vui long chay: sudo $0"
        exit 1
    fi
    
    # Kiem tra cac lenh can thiet
    local required_commands=("curl" "netstat" "systemctl" "useradd" "userdel")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "Lenh can thiet '$cmd' khong tim thay!"
            print_warning "Vui long cai dat cac goi can thiet."
            exit 1
        fi
    done
    
    while true; do
        show_main_menu
        read -p "$(echo -e "${YELLOW}❯${NC} Chon tuy chon [1-8]: ")" choice
        
        case $choice in
            1) install_danted ;;
            2) show_users ;;
            3) add_multi_users ;;
            4) delete_users ;;
            5) test_proxies ;;
            6) check_service_status ;;
            7) uninstall_danted ;;
            8) 
                # Xoa man hinh va hien thi thong bao cam on
                clear
                print_header
                print_section_header "Cam on ban da su dung Quan ly SOCKS5 Proxy Danted!"
                echo
                exit 0
                ;;
            *) 
                print_error "Tuy chon khong hop le! Vui long chon 1-8."
                sleep 1
                ;;
        esac
    done
}

# Chay ham chinh
main "$@"