# Danted SOCKS5 Proxy Manager v1.0

Một công cụ quản lý SOCKS5 Proxy Server chuyên nghiệp được viết bằng Bash cho hệ thống Ubuntu, sử dụng Dante SOCKS server.

## 📋 Mục lục

- [Tính năng](#-tính-năng)
- [Yêu cầu hệ thống](#-yêu-cầu-hệ-thống) 
- [Cài đặt](#-cài-đặt)
- [Sử dụng](#-sử-dụng)
- [Các chức năng chính](#-các-chức-năng-chính)
- [Cấu trúc thư mục](#-cấu-trúc-thư-mục)
- [Cấu hình](#-cấu-hình)
- [Kiểm tra và giám sát](#-kiểm-tra-và-giám-sát)
- [Khắc phục sự cố](#-khắc-phục-sự-cố)
- [Bảo mật](#-bảo-mật)
- [FAQ](#-faq)
- [Đóng góp](#-đóng-góp)

## 🚀 Tính năng

### Quản lý cơ bản
- ✅ **Cài đặt tự động** Dante SOCKS5 server
- ✅ **Giao diện menu** trực quan với màu sắc
- ✅ **Quản lý người dùng** (thêm/xóa/xem danh sách)
- ✅ **Cấu hình tự động** network interface và port
- ✅ **Gỡ cài đặt hoàn toàn** khi không cần thiết

### Giám sát và kiểm tra
- 📊 **Hiển thị thông tin hệ thống** (CPU, RAM, disk usage)
- 🔍 **Giám sát trạng thái service** Dante real-time
- 📜 **Xem logs** chi tiết của service
- 🌐 **Kiểm tra tốc độ mạng** và bandwidth
- 🧪 **Test proxy** với nhiều server

### Tự động hóa
- ⚙️ **Tạo file cấu hình** V2Ray/Xray tự động cho từng user
- 🔄 **Restart/stop service** dễ dàng
- 📂 **Quản lý file cấu hình** trong thư mục riêng biệt
- 🛡️ **Validation** dữ liệu đầu vào tự động

## 🔧 Yêu cầu hệ thống

### Hệ điều hành
- **Ubuntu 18.04+** (được khuyến nghị)
- **Debian 9+** (có thể hoạt động)

### Phần mềm cần thiết
- `curl` - để test connectivity
- `netstat` - để kiểm tra port
- `systemctl` - để quản lý service
- `useradd/userdel` - để quản lý user
- `bc` - để tính toán (tự động cài đặt nếu cần)

### Quyền truy cập
- **Root privileges** (sudo hoặc root user)
- **Network access** để download packages

### Tài nguyên hệ thống
- **RAM**: Tối thiểu 512MB (khuyến nghị 1GB+)
- **Disk**: Tối thiểu 100MB trống
- **CPU**: Bất kỳ CPU x86_64

## 📥 Cài đặt

### Cách 1: Download trực tiếp
```bash
# Download script
wget https://raw.githubusercontent.com/ndn8144/DantedProxyManagement/refs/heads/main/dantedManager.sh

# Cấp quyền thực thi
chmod +x dantedManager.sh

# Chạy script
sudo ./dantedManager.sh
```

### Cách 2: Clone repository
```bash
# Clone repository
git clone https://github.com/ndn8144/DantedProxyManagement.git

# Di chuyển vào thư mục
cd DantedProxyManagement

# Cấp quyền thực thi
chmod +x dantedManager.sh

# Chạy script
sudo ./dantedManager.sh
```

### Cách 3: Chạy trực tiếp
```bash
# Chạy script trực tiếp từ internet
curl -sSL https://raw.githubusercontent.com/ndn8144/DantedProxyManagement/refs/heads/main/dantedManager.sh | sudo bash
```

## 📘 Sử dụng

### Khởi động script
```bash
sudo ./dantedManager.sh
```

Sau khi khởi động, bạn sẽ thấy menu chính với 8 tùy chọn:

```
┌─ Menu Options ───────────────────────────────────────────────────────────────┐
│ 1. Install Danted SOCKS5 Proxy                                              │
│ 2. Show Users                                                                │
│ 3. Add Users                                                                 │
│ 4. Delete Users                                                              │
│ 5. Test Proxies                                                              │
│ 6. Check Status & Monitoring                                                 │
│ 7. Uninstall Danted                                                          │
│ 8. Exit                                                                      │
└──────────────────────────────────────────────────────────────────────────────┘
```

## 🛠️ Các chức năng chính

### 1. Install Danted SOCKS5 Proxy
**Mục đích**: Cài đặt và cấu hình Dante SOCKS5 server lần đầu.

**Quy trình**:
1. Chọn network interface (hiển thị danh sách IP available)
2. Nhập port cho SOCKS5 (mặc định: 1080)
3. Script sẽ tự động:
   - Update package list
   - Cài đặt `dante-server`
   - Tạo file cấu hình `/etc/danted.conf`
   - Enable và start service
   - Kiểm tra trạng thái

**Ví dụ cấu hình được tạo**:
```bash
# /etc/danted.conf
logoutput: /var/log/danted.log
internal: 192.168.1.100 port = 1080
external: 192.168.1.100

socksmethod: username

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
    socksmethod: username
}
```

### 2. Show Users
**Mục đích**: Hiển thị danh sách tất cả user SOCKS5 hiện có.

**Thông tin hiển thị**:
- Số thứ tự
- Tên user
- Tổng số user

**Lọc user**: Chỉ hiển thị user có shell `/bin/false` (user được tạo cho SOCKS5)

### 3. Add Users
**Mục đích**: Thêm user mới cho SOCKS5 proxy.

**Tính năng**:
- **Thêm nhiều user cùng lúc**: Nhập danh sách username, mỗi dòng một user
- **Validation tự động**: Kiểm tra format username, duplicate
- **Tạo mật khẩu**: Nhập và xác nhận mật khẩu cho từng user
- **Tạo config file**: Tự động tạo file cấu hình V2Ray/Xray cho từng user

**Format input**:
```
# Nhập username (một dòng một user)
user1
user2
user3

# Nhấn Enter 2 lần để kết thúc
```

**File config được tạo**: `configFiles/[username]` (format JSON cho V2Ray/Xray)

### 4. Delete Users
**Mục đính**: Xóa user SOCKS5 không cần thiết.

**Tính năng**:
- Hiển thị danh sách user có thể xóa
- Chọn nhiều user cùng lúc (space-separated numbers)
- Xác nhận trước khi xóa
- Xóa cả system user và config file

**Ví dụ**: Nhập `1 3 5` để xóa user số 1, 3, và 5

### 5. Test Proxies
**Mục đích**: Kiểm tra tình trạng hoạt động của các proxy.

**Tính năng**:
- **Test nhiều proxy cùng lúc**
- **Validation format** tự động
- **Hiển thị kết quả** real-time với progress indicator
- **Thống kê**: Tổng số proxy, successful, failed, success rate

**Format input**:
```
IP:PORT:USERNAME:PASSWORD

# Ví dụ:
100.150.200.250:30500:user1:pass123
192.168.1.100:1080:alice:secret456
```

**Output ví dụ**:
```
┌─ Proxy Test Results ─────────────────────────────────────────────────────────┐
│ [ 1/ 3] 100.150.200.250:30500@user1    ✓ SUCCESS                           │
│ [ 2/ 3] 192.168.1.100:1080@alice       ✗ FAILED                            │
│ [ 3/ 3] 10.0.0.1:8080@bob              ✓ SUCCESS                           │
└──────────────────────────────────────────────────────────────────────────────┘

┌─ Test Summary ───────────────────────────────────────────────────────────────┐
│ Total Proxies:   3                                                          │
│ Successful:      2                                                          │
│ Failed:          1                                                          │
│ Success Rate:    66%                                                        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 6. Check Status & Monitoring
**Mục đích**: Giám sát hệ thống và service Dante.

**Thông tin hiển thị**:

#### System Information:
- **CPU Usage**: Phần trăm CPU đang sử dụng
- **Memory**: RAM used/total
- **Disk Usage**: Phần trăm disk đã sử dụng
- **Uptime**: Thời gian hệ thống đã chạy

#### Dante Information:
- **Dante Status**: Running/Stopped/Failed
- **Auto-start Status**: Enabled/Disabled
- **Listen Address**: IP:Port đang listen
- **Active Connections**: Số kết nối hiện tại

#### Recent Service Logs:
- 5 log entries gần nhất trong 1 giờ qua

#### Control Options:
1. **Restart Service**: Khởi động lại Dante service
2. **Stop Service**: Dừng Dante service  
3. **View Full Logs**: Xem 50 log entries gần nhất
4. **Test Internet Bandwidth**: Kiểm tra tốc độ mạng
5. **Back to Main Menu**: Quay lại menu chính

### 7. Uninstall Danted
**Mục đích**: Gỡ cài đặt hoàn toàn Dante và làm sạch hệ thống.

**Quy trình**:
1. **Cảnh báo**: Hiển thị warning về việc xóa hoàn toàn
2. **Xác nhận**: Yêu cầu confirm từ user
3. **Stop service**: Dừng và disable Dante service
4. **Remove package**: Gỡ cài đặt `dante-server`
5. **Clean config**: Xóa file cấu hình `/etc/danted.conf`
6. **Optional cleanup**:
   - Hỏi có xóa user config files không
   - Hỏi có xóa SOCKS5 users không

### 8. Exit
Thoát khỏi script với thông báo cảm ơn.

## 📁 Cấu trúc thư mục

```
/
├── etc/
│   └── danted.conf                 # File cấu hình chính của Dante
├── var/log/
│   └── danted.log                  # Log file của Dante service
└── [script_directory]/
    ├── dantedManager.sh            # Script chính
    └── configFiles/                # Thư mục chứa config files
        ├── user1                   # Config V2Ray/Xray cho user1
        ├── user2                   # Config V2Ray/Xray cho user2
        └── ...
```

## ⚙️ Cấu hình

### File cấu hình Dante (`/etc/danted.conf`)

```bash
# Log output
logoutput: /var/log/danted.log

# Internal interface (server listening)
internal: [SERVER_IP] port = [PORT]

# External interface (outgoing connections)  
external: [SERVER_IP]

# Authentication method
socksmethod: username

# Client access rules
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
}

# SOCKS proxy rules
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
    socksmethod: username
}
```

### File cấu hình V2Ray/Xray (ví dụ)
Mỗi user sẽ có một file config riêng trong `configFiles/[username]`:

```json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "socks",
      "port": 10808,
      "listen": "127.0.0.1",
      "protocol": "mixed"
    }
  ],
  "outbounds": [
    {
      "tag": "proxy-1",
      "protocol": "socks",
      "settings": {
        "servers": [
          {
            "address": "[SERVER_IP]",
            "port": [PORT],
            "users": [
              {
                "user": "[USERNAME]",
                "pass": "[PASSWORD]"
              }
            ]
          }
        ]
      }
    }
  ]
}
```

## 📊 Kiểm tra và giám sát

### Kiểm tra trạng thái service
```bash
# Kiểm tra trạng thái
sudo systemctl status danted

# Xem logs real-time
sudo journalctl -u danted -f

# Kiểm tra port đang listen
sudo netstat -tlnp | grep danted
```

### Kiểm tra user system
```bash
# Xem danh sách user SOCKS5
getent passwd | grep '/bin/false'

# Kiểm tra user cụ thể
id [username]
```

### Kiểm tra kết nối
```bash
# Kiểm tra active connections
sudo ss -tn | grep :[PORT]

# Test proxy bằng curl
curl --proxy socks5://username:password@server_ip:port http://httpbin.org/ip
```

## 🔧 Khắc phục sự cố

### Lỗi thường gặp

#### 1. Service không start được
**Triệu chứng**: Dante service failed to start
```bash
# Kiểm tra logs
sudo journalctl -u danted --no-pager -n 20

# Kiểm tra cấu hình
sudo danted -f /etc/danted.conf -v
```

**Giải pháp**:
- Kiểm tra IP address trong config có đúng không
- Kiểm tra port có bị conflict không
- Kiểm tra syntax của config file

#### 2. Port đã được sử dụng
**Triệu chứng**: Port already in use
```bash
# Kiểm tra process đang dùng port
sudo lsof -i :[PORT]
sudo netstat -tlnp | grep :[PORT]
```

**Giải pháp**:
- Chọn port khác
- Kill process đang dùng port (nếu an toàn)

#### 3. Authentication failed
**Triệu chứng**: Client không thể connect với username/password

**Kiểm tra**:
```bash
# Kiểm tra user có tồn tại không
id [username]

# Kiểm tra password (thử đăng nhập)
su - [username]  # Should fail với /bin/false shell
```

**Giải pháp**:
- Tạo lại user với password mới
- Kiểm tra config Dante có đúng authentication method

#### 4. Không thể download packages
**Triệu chứng**: apt update/install failed

**Giải pháp**:
```bash
# Update package list
sudo apt update

# Fix broken packages
sudo apt --fix-broken install

# Retry với verbose
sudo apt install -y dante-server -v
```

### Debug mode

Để chạy Dante ở debug mode:
```bash
# Stop service trước
sudo systemctl stop danted

# Chạy manual với debug
sudo danted -f /etc/danted.conf -d
```

## 🔒 Bảo mật

### Khuyến nghị bảo mật

#### 1. Firewall configuration
```bash
# Chỉ cho phép port SOCKS5
sudo ufw allow [SOCKS5_PORT]/tcp

# Chặn tất cả port khác (tùy chọn)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
```

#### 2. Strong passwords
- Sử dụng mật khẩu ít nhất 8 ký tự
- Kết hợp chữ hoa, chữ thường, số và ký tự đặc biệt
- Không sử dụng thông tin cá nhân

#### 3. Regular monitoring
- Kiểm tra logs định kỳ
- Monitor active connections
- Update system thường xuyên

#### 4. Access control
```bash
# Giới hạn access từ specific IP (trong danted.conf)
client pass {
    from: 192.168.1.0/24 to: 0.0.0.0/0
    log: error connect disconnect
}
```

### Backup và restore

#### Backup cấu hình
```bash
# Backup Dante config
sudo cp /etc/danted.conf /etc/danted.conf.backup

# Backup user configs
tar -czf configFiles_backup.tar.gz configFiles/

# Backup user accounts
getent passwd | grep '/bin/false' > socks_users_backup.txt
```

#### Restore
```bash
# Restore Dante config
sudo cp /etc/danted.conf.backup /etc/danted.conf

# Restore user configs
tar -xzf configFiles_backup.tar.gz

# Restart service
sudo systemctl restart danted
```

## ❓ FAQ

### Q: Script có hoạt động trên CentOS/RHEL không?
**A**: Script được thiết kế cho Ubuntu/Debian. Để chạy trên CentOS/RHEL, cần modify một số commands:
- `apt` → `yum` hoặc `dnf`
- Package name có thể khác
- Service management tương tự

### Q: Có thể thay đổi port sau khi cài đặt không?
**A**: Có, bằng cách:
1. Edit `/etc/danted.conf`
2. Thay đổi port number
3. Restart service: `sudo systemctl restart danted`

### Q: Maximum số user có thể tạo?
**A**: Không có giới hạn cứng, phụ thuộc vào:
- System resources (RAM, CPU)
- Network bandwidth
- Concurrent connections limit

### Q: Config files ở định dạng gì?
**A**: JSON format cho V2Ray/Xray client. Có thể import trực tiếp vào các client tương thích.

### Q: Làm sao để backup toàn bộ cấu hình?
**A**: 
```bash
# Tạo script backup đơn giản
#!/bin/bash
mkdir -p backup/$(date +%Y%m%d)
cp /etc/danted.conf backup/$(date +%Y%m%d)/
cp -r configFiles backup/$(date +%Y%m%d)/
getent passwd | grep '/bin/false' > backup/$(date +%Y%m%d)/users.txt
```

### Q: Dante service bị crash thường xuyên?
**A**: Kiểm tra:
- System resources (RAM, CPU)
- Log files cho error messages
- Network configuration
- Concurrent connections limit

### Q: Có thể sử dụng với IPv6 không?
**A**: Có, cần cấu hình trong `danted.conf`:
```bash
# IPv6 support
internal: [IPv6_ADDRESS] port = [PORT]
external: [IPv6_ADDRESS]
```

## 🤝 Đóng góp

### Báo cáo lỗi
1. Mở issue trên GitHub
2. Cung cấp thông tin:
   - OS version
   - Error messages
   - Steps to reproduce
   - Expected vs actual behavior

### Đề xuất tính năng
1. Kiểm tra existing issues trước
2. Mô tả chi tiết use case
3. Đề xuất implementation approach

### Pull requests
1. Fork repository
2. Tạo feature branch
3. Commit changes với clear messages
4. Submit pull request với description

### Development setup
```bash
# Clone repo
git clone https://github.com/ndn8144/DantedProxyManagement.git

# Create test environment
vagrant up  # Nếu có Vagrantfile

# Test script
sudo bash dantedManager.sh
```

---

## 📞 Hỗ trợ

- **GitHub Issues**: [Report bugs/feature requests](https://github.com/ndn8144/DantedProxyManagement/issues)
- **Email**: [Contact maintainer]
- **Telegram**: [Support group]

---

## 📄 License

MIT License - xem file [LICENSE](LICENSE) để biết chi tiết.

---

## 🙏 Credits

- **Dante SOCKS server**: [Inferno Nettverk A/S](https://www.inet.no/dante/)
- **V2Ray/Xray config**: Tương thích với V2Ray và Xray clients
- **Contributors**: Tất cả những người đã đóng góp cho project

---

**⚠️ Disclaimer**: Script này được cung cấp "as-is" không có bảo hành. Sử dụng với trách nhiệm của bạn và tuân thủ luật pháp địa phương.