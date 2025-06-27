#!/bin/bash
# User management & proxy test script

function hien_thi_user() {
    echo "Danh sach user:"
    awk -F: '($3 < 1000 && $7 == "/bin/false") {print $1}' /etc/passwd
}

function them_user() {
    echo "=============================================================="
    echo "Co the nhap nhieu user, moi ten mot dong. Nhan Enter 2 lan de ket thuc."
    usernames=""
    while true; do
        read line
        if [ -z "$line" ]; then
            break
        fi
        usernames="$usernames $line"
    done

    for username in $usernames; do
        if [ -z "$username" ]; then
            continue
        fi
        if id "$username" &>/dev/null; then
            echo "User $username da ton tai! Bo qua."
        else
            useradd -r -s /bin/false "$username"
            if [ $? -eq 0 ]; then
                echo "Da tao user $username."
            else
                echo "Loi khi tao user $username."
            fi
        fi
    done
}

function xoa_user() {
    mapfile -t DANH_SACH_USER < <(awk -F: '($3 < 1000 && $7 == "/bin/false") {print $1}' /etc/passwd)

    if [ ${#DANH_SACH_USER[@]} -eq 0 ]; then
        echo "Khong tim thay user nao!"
        return
    fi

    echo "Danh sach user:"
    for i in "${!DANH_SACH_USER[@]}"; do
        printf "%2d. %s\n" $((i+1)) "${DANH_SACH_USER[$i]}"
    done
    read -p "Nhap so thu tu user ban muon xoa: " num

    if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#DANH_SACH_USER[@]} )); then
        USER_CAN_XOA="${DANH_SACH_USER[$((num-1))]}"
        read -p "Ban co chac muon xoa user '$USER_CAN_XOA'? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            deluser --remove-home "$USER_CAN_XOA"
            echo "Da xoa user $USER_CAN_XOA."
        else
            echo "Da huy xoa."
        fi
    else
        echo "So thu tu khong hop le."
    fi
}

function test_proxy() {
    echo "Paste danh sach proxy (1 proxy 1 dong, nhan Enter 2 lan de ket thuc):"
    proxies=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        proxies+=("$(echo "$line" | xargs)")
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

while true; do
    echo ""
    echo "============ User & Proxy Manager ============"
    echo "1. Hien thi danh sach user"
    echo "2. Them user moi"
    echo "3. Xoa user"
    echo "4. Test hang loat proxy"
    echo "5. Thoat"
    read -p "Chon chuc nang [1-5]: " choice

    case $choice in
        1) hien_thi_user ;;
        2) them_user ;;
        3) xoa_user ;;
        4) test_proxy ;;
        5) exit 0 ;;
        *) echo "Lua chon khong hop le!" ;;
    esac
done
