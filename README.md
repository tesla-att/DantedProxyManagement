# Danted SOCKS5 Proxy Manager v1.0

A professional SOCKS5 Proxy Server management tool written in Bash for Ubuntu systems, utilizing Dante SOCKS server.

## 📋 Table of Contents

- [Features](#-features)
- [System Requirements](#-system-requirements) 
- [Installation](#-installation)
- [Usage](#-usage)
- [Main Functions](#-main-functions)
- [Directory Structure](#-directory-structure)
- [Configuration](#-configuration)
- [Monitoring & Status Check](#-monitoring--status-check)
- [Troubleshooting](#-troubleshooting)
- [Security](#-security)
- [FAQ](#-faq)
- [Contributing](#-contributing)

## 🚀 Features

### Basic Management
- ✅ **Automatic installation** of Dante SOCKS5 server
- ✅ **Intuitive menu interface** with colorful output
- ✅ **User management** (add/delete/list users)
- ✅ **Automatic configuration** of network interface and port
- ✅ **Complete uninstallation** when no longer needed

### Monitoring & Testing
- 📊 **System information display** (CPU, RAM, disk usage)
- 🔍 **Real-time Dante service monitoring**
- 📜 **Detailed service logs** viewing
- 🌐 **Internet bandwidth testing**
- 🧪 **Proxy testing** with multiple servers

### Automation
- ⚙️ **Automatic V2Ray/Xray config generation** for each user
- 🔄 **Easy service restart/stop** functionality
- 📂 **Config file management** in separate directory
- 🛡️ **Automatic input validation**

## 🔧 System Requirements

### Operating System
- **Ubuntu 18.04+** (recommended)
- **Debian 9+** (may work)

### Required Software
- `curl` - for connectivity testing
- `netstat` - for port checking
- `systemctl` - for service management
- `useradd/userdel` - for user management
- `bc` - for calculations (auto-installed if needed)

### Access Requirements
- **Root privileges** (sudo or root user)
- **Network access** for downloading packages

### System Resources
- **RAM**: Minimum 512MB (recommended 1GB+)
- **Disk**: Minimum 100MB free space
- **CPU**: Any x86_64 CPU

## 📥 Installation

### Method 1: Direct Download
```bash
# Download script
wget https://raw.githubusercontent.com/ndn8144/DantedProxyManagement/refs/heads/main/dantedManager.sh

# Make executable
chmod +x dantedManager.sh

# Run script
sudo ./dantedManager.sh
```

### Method 2: Clone Repository
```bash
# Clone repository
git clone https://github.com/ndn8144/DantedProxyManagement.git

# Enter directory
cd DantedProxyManagement

# Make executable
chmod +x dantedManager.sh

# Run script
sudo ./dantedManager.sh
```

### Method 3: Direct Execution
```bash
# Run script directly from internet
curl -sSL https://raw.githubusercontent.com/ndn8144/DantedProxyManagement/refs/heads/main/dantedManager.sh | sudo bash
```

## 📘 Usage

### Starting the Script
```bash
sudo ./dantedManager.sh
```

After starting, you'll see the main menu with 8 options:

```
┌─ Menu Options ───────────────────────────────────────────────────────────────┐
│ 1. Install Danted SOCKS5 Proxy                                               │
│ 2. Show Users                                                                │
│ 3. Add Users                                                                 │
│ 4. Delete Users                                                              │
│ 5. Test Proxies                                                              │
│ 6. Check Status & Monitoring                                                 │
│ 7. Uninstall Danted                                                          │
│ 8. Exit                                                                      │
└──────────────────────────────────────────────────────────────────────────────┘
```

## 🛠️ Main Functions

### 1. Install Danted SOCKS5 Proxy
**Purpose**: Install and configure Dante SOCKS5 server for the first time.

**Process**:
1. Select network interface (displays list of available IPs)
2. Enter port for SOCKS5 (default: 1080)
3. Script will automatically:
   - Update package list
   - Install `dante-server`
   - Create configuration file `/etc/danted.conf`
   - Enable and start service
   - Check status

**Example generated configuration**:
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
**Purpose**: Display list of all existing SOCKS5 users.

**Information displayed**:
- Sequential number
- Username
- Total user count

**User filtering**: Only shows users with `/bin/false` shell (users created for SOCKS5)

### 3. Add Users
**Purpose**: Add new users for SOCKS5 proxy.

**Features**:
- **Bulk user addition**: Enter list of usernames, one per line
- **Automatic validation**: Check username format, duplicates
- **Password creation**: Enter and confirm password for each user
- **Config file generation**: Automatically create V2Ray/Xray config file for each user

**Input format**:
```
# Enter usernames (one per line)
user1
user2
user3

# Press Enter twice to finish
```

**Generated config file**: `configFiles/[username]` (JSON format for V2Ray/Xray)

### 4. Delete Users
**Purpose**: Remove unnecessary SOCKS5 users.

**Features**:
- Display list of deletable users
- Select multiple users at once (space-separated numbers)
- Confirmation before deletion
- Remove both system user and config file

**Example**: Enter `1 3 5` to delete users #1, #3, and #5

### 5. Test Proxies
**Purpose**: Check operational status of proxies.

**Features**:
- **Test multiple proxies simultaneously**
- **Automatic format validation**
- **Real-time results** with progress indicator
- **Statistics**: Total proxies, successful, failed, success rate

**Input format**:
```
IP:PORT:USERNAME:PASSWORD

# Examples:
100.150.200.250:30500:user1:pass123
192.168.1.100:1080:alice:secret456
```

**Example output**:
```
┌─ Proxy Test Results ─────────────────────────────────────────────────────────┐
│ [ 1/ 3] 100.150.200.250:30500@user1    ✓ SUCCESS                             │
│ [ 2/ 3] 192.168.1.100:1080@alice       ✗ FAILED                              │
│ [ 3/ 3] 10.0.0.1:8080@bob              ✓ SUCCESS                             │
└──────────────────────────────────────────────────────────────────────────────┘

┌─ Test Summary ───────────────────────────────────────────────────────────────┐
│ Total Proxies:   3                                                           │
│ Successful:      2                                                           │
│ Failed:          1                                                           │
│ Success Rate:    66%                                                         │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 6. Check Status & Monitoring
**Purpose**: Monitor system and Dante service.

**Information displayed**:

#### System Information:
- **CPU Usage**: Percentage of CPU currently in use
- **Memory**: RAM used/total
- **Disk Usage**: Percentage of disk space used
- **Uptime**: System uptime

#### Dante Information:
- **Dante Status**: Running/Stopped/Failed
- **Auto-start Status**: Enabled/Disabled
- **Listen Address**: IP:Port currently listening
- **Active Connections**: Current connection count

#### Recent Service Logs:
- Last 5 log entries from the past hour

#### Control Options:
1. **Restart Service**: Restart Dante service
2. **Stop Service**: Stop Dante service  
3. **View Full Logs**: View last 50 log entries
4. **Test Internet Bandwidth**: Check network speed
5. **Back to Main Menu**: Return to main menu

### 7. Uninstall Danted
**Purpose**: Completely uninstall Dante and clean the system.

**Process**:
1. **Warning**: Display warning about complete removal
2. **Confirmation**: Require user confirmation
3. **Stop service**: Stop and disable Dante service
4. **Remove package**: Uninstall `dante-server`
5. **Clean config**: Remove configuration file `/etc/danted.conf`
6. **Optional cleanup**:
   - Ask whether to remove user config files
   - Ask whether to remove SOCKS5 users

### 8. Exit
Exit the script with a thank you message.

## 📁 Directory Structure

```
/
├── etc/
│   └── danted.conf                 # Main Dante configuration file
├── var/log/
│   └── danted.log                  # Dante service log file
└── [script_directory]/
    ├── dantedManager.sh            # Main script
    └── configFiles/                # Directory containing config files
        ├── user1                   # V2Ray/Xray config for user1
        ├── user2                   # V2Ray/Xray config for user2
        └── ...
```

## ⚙️ Configuration

### Dante Configuration File (`/etc/danted.conf`)

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

### V2Ray/Xray Configuration File (Example)
Each user will have a separate config file in `configFiles/[username]`:

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

## 📊 Monitoring & Status Check

### Checking Service Status
```bash
# Check status
sudo systemctl status danted

# View real-time logs
sudo journalctl -u danted -f

# Check listening port
sudo netstat -tlnp | grep danted
```

### Checking System Users
```bash
# View SOCKS5 user list
getent passwd | grep '/bin/false'

# Check specific user
id [username]
```

### Checking Connections
```bash
# Check active connections
sudo ss -tn | grep :[PORT]

# Test proxy with curl
curl --proxy socks5://username:password@server_ip:port http://httpbin.org/ip
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Service Won't Start
**Symptoms**: Dante service failed to start
```bash
# Check logs
sudo journalctl -u danted --no-pager -n 20

# Check configuration
sudo danted -f /etc/danted.conf -v
```

**Solutions**:
- Verify IP address in config is correct
- Check for port conflicts
- Verify config file syntax

#### 2. Port Already in Use
**Symptoms**: Port already in use error
```bash
# Check which process is using the port
sudo lsof -i :[PORT]
sudo netstat -tlnp | grep :[PORT]
```

**Solutions**:
- Choose a different port
- Kill the process using the port (if safe)

#### 3. Authentication Failed
**Symptoms**: Client can't connect with username/password

**Check**:
```bash
# Check if user exists
id [username]

# Check password (try to login)
su - [username]  # Should fail with /bin/false shell
```

**Solutions**:
- Recreate user with new password
- Verify Dante config has correct authentication method

#### 4. Can't Download Packages
**Symptoms**: apt update/install failed

**Solutions**:
```bash
# Update package list
sudo apt update

# Fix broken packages
sudo apt --fix-broken install

# Retry with verbose output
sudo apt install -y dante-server -v
```

### Debug Mode

To run Dante in debug mode:
```bash
# Stop service first
sudo systemctl stop danted

# Run manually with debug
sudo danted -f /etc/danted.conf -d
```

## 🔒 Security

### Security Recommendations

#### 1. Firewall Configuration
```bash
# Only allow SOCKS5 port
sudo ufw allow [SOCKS5_PORT]/tcp

# Allow port for SSH 
# Default port is 22
sudo ufw allow 22 

# Block all other ports (optional)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
```

#### 2. Strong Passwords
- Use passwords with at least 8 characters
- Combine uppercase, lowercase, numbers, and special characters
- Avoid personal information

#### 3. Regular Monitoring
- Check logs regularly
- Monitor active connections
- Update system frequently

#### 4. Access Control
```bash
# Limit access from specific IP (in danted.conf)
client pass {
    from: 192.168.1.0/24 to: 0.0.0.0/0
    log: error connect disconnect
}
```

### Backup and Restore

#### Backup Configuration
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

### Q: Does the script work on CentOS/RHEL?
**A**: The script is designed for Ubuntu/Debian. To run on CentOS/RHEL, you need to modify some commands:
- `apt` → `yum` or `dnf`
- Package names may differ
- Service management is similar

### Q: Can I change the port after installation?
**A**: Yes, by:
1. Edit `/etc/danted.conf`
2. Change the port number
3. Restart service: `sudo systemctl restart danted`

### Q: What's the maximum number of users I can create?
**A**: There's no hard limit, it depends on:
- System resources (RAM, CPU)
- Network bandwidth
- Concurrent connections limit

### Q: What format are the config files?
**A**: JSON format for V2Ray/Xray clients. Can be imported directly into compatible clients.

### Q: How do I backup all configurations?
**A**: 
```bash
# Create simple backup script
#!/bin/bash
mkdir -p backup/$(date +%Y%m%d)
cp /etc/danted.conf backup/$(date +%Y%m%d)/
cp -r configFiles backup/$(date +%Y%m%d)/
getent passwd | grep '/bin/false' > backup/$(date +%Y%m%d)/users.txt
```

### Q: Dante service crashes frequently?
**A**: Check:
- System resources (RAM, CPU)
- Log files for error messages
- Network configuration
- Concurrent connections limit

### Q: Can I use it with IPv6?
**A**: Yes, configure in `danted.conf`:
```bash
# IPv6 support
internal: [IPv6_ADDRESS] port = [PORT]
external: [IPv6_ADDRESS]
```

## 🤝 Contributing

### Reporting Bugs
1. Open an issue on GitHub
2. Provide information:
   - OS version
   - Error messages
   - Steps to reproduce
   - Expected vs actual behavior

### Feature Requests
1. Check existing issues first
2. Describe the use case in detail
3. Suggest implementation approach

### Pull Requests
1. Fork the repository
2. Create a feature branch
3. Commit changes with clear messages
4. Submit pull request with description

### Development Setup
```bash
# Clone repo
git clone https://github.com/ndn8144/DantedProxyManagement.git

# Create test environment
vagrant up  # If Vagrantfile exists

# Test script
sudo bash dantedManager.sh
```

---

## 📞 Support

- **GitHub Issues**: [Report bugs/feature requests](https://github.com/ndn8144/DantedProxyManagement/issues)
- **Email**: [Contact maintainer]
- **Telegram**: [Support group]

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙏 Credits

- **Dante SOCKS server**: [Inferno Nettverk A/S](https://www.inet.no/dante/)
- **V2Ray/Xray config**: Compatible with V2Ray and Xray clients
- **Contributors**: All those who have contributed to this project

---

**⚠️ Disclaimer**: This script is provided "as-is" without warranty. Use at your own responsibility and comply with local laws.