#!/bin/bash

# Test script để kiểm tra việc trích xuất port và IP từ file cấu hình danted

echo "Testing port and IP extraction from danted config..."

# Tạo file test config
cat > /tmp/test_danted.conf << 'EOF'
# Test config
logoutput: /var/log/danted.log
internal: 192.168.1.100 port = 1080
external: 192.168.1.100

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

echo "Test config created:"
cat /tmp/test_danted.conf
echo

# Test extraction methods
echo "=== Testing extraction methods ==="

# Method 1: Old method (problematic)
echo "Old method (problematic):"
old_ip=$(grep -E "^[[:space:]]*internal:" /tmp/test_danted.conf | head -1 | awk '{print $2}' | sed 's/port=.*//')
old_port=$(grep -E "^[[:space:]]*internal:" /tmp/test_danted.conf | head -1 | awk '{print $2}' | sed 's/.*port=//')
echo "IP: '$old_ip'"
echo "Port: '$old_port'"
echo

# Method 2: New method (fixed)
echo "New method (fixed):"
internal_line=$(grep -E "^[[:space:]]*internal:" /tmp/test_danted.conf | head -1)
echo "Internal line: '$internal_line'"
new_ip=$(echo "$internal_line" | sed -n 's/.*internal:[[:space:]]*\([^[:space:]]*\).*/\1/p' | sed 's/port=.*//')
new_port=$(echo "$internal_line" | sed -n 's/.*port[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
echo "IP: '$new_ip'"
echo "Port: '$new_port'"
echo

# Test with different format
echo "=== Testing with different format ==="
cat > /tmp/test_danted2.conf << 'EOF'
# Test config 2
logoutput: /var/log/danted.log
internal:0.0.0.0 port=8080
external:0.0.0.0
EOF

echo "Test config 2:"
cat /tmp/test_danted2.conf
echo

internal_line2=$(grep -E "^[[:space:]]*internal:" /tmp/test_danted2.conf | head -1)
echo "Internal line: '$internal_line2'"
new_ip2=$(echo "$internal_line2" | sed -n 's/.*internal:[[:space:]]*\([^[:space:]]*\).*/\1/p' | sed 's/port=.*//')
new_port2=$(echo "$internal_line2" | sed -n 's/.*port[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
echo "IP: '$new_ip2'"
echo "Port: '$new_port2'"
echo

# Cleanup
rm -f /tmp/test_danted.conf /tmp/test_danted2.conf
echo "Test completed!" 