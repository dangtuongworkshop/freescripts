#!/bin/bash

#############################################################
# Script tự động cài đặt Supabase trên Ubuntu VPS
# Dành cho Amazon Lightsail hoặc bất kỳ Ubuntu VPS nào
# Tác giả: Auto-generated
# Ngày: 2025-11-08
#############################################################

set -e  # Thoát ngay khi có lỗi

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Hàm log
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   log_error "Script này cần chạy với quyền root"
   exit 1
fi

log_info "Bắt đầu cài đặt Supabase trên Ubuntu..."

# Cập nhật hệ thống
log_info "Cập nhật hệ thống..."
apt-get update -y
apt-get upgrade -y

# Cài đặt các gói cần thiết
log_info "Cài đặt các gói phụ thuộc..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    wget \
    ufw

# Cài đặt Docker
log_info "Cài đặt Docker..."
if ! command -v docker &> /dev/null; then
    # Thêm Docker GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Thêm Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Cài đặt Docker Engine
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Khởi động Docker
    systemctl start docker
    systemctl enable docker

    log_info "Docker đã được cài đặt thành công"
else
    log_warn "Docker đã được cài đặt trước đó"
fi

# Kiểm tra Docker Compose
log_info "Kiểm tra Docker Compose..."
if ! docker compose version &> /dev/null; then
    log_error "Docker Compose không được cài đặt đúng cách"
    exit 1
fi

# Tạo thư mục cho Supabase
log_info "Tạo thư mục cho Supabase..."
SUPABASE_DIR="/opt/supabase"
mkdir -p $SUPABASE_DIR
cd $SUPABASE_DIR

# Clone Supabase repository
log_info "Clone Supabase repository..."
if [ ! -d "$SUPABASE_DIR/docker" ]; then
    git clone --depth 1 https://github.com/supabase/supabase
    cd supabase/docker
else
    log_warn "Supabase repository đã tồn tại"
    cd supabase/docker
    git pull
fi

# Copy file .env mẫu
log_info "Tạo file cấu hình .env..."
cp .env.example .env

# Tạo JWT secrets và passwords ngẫu nhiên
log_info "Tạo JWT secrets và passwords..."

# Tạo JWT secret (32 ký tự ngẫu nhiên)
JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
ANON_KEY=$(docker run --rm supabase/gotrue:latest gotrue generate jwt --secret="$JWT_SECRET" --exp=315360000 --role=anon 2>/dev/null || echo "REPLACE_WITH_ANON_KEY")
SERVICE_ROLE_KEY=$(docker run --rm supabase/gotrue:latest gotrue generate jwt --secret="$JWT_SECRET" --exp=315360000 --role=service_role 2>/dev/null || echo "REPLACE_WITH_SERVICE_ROLE_KEY")

# Tạo passwords ngẫu nhiên
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/")
DASHBOARD_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/")

# Cập nhật file .env
log_info "Cập nhật cấu hình..."
sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|g" .env
sed -i "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|g" .env
sed -i "s|ANON_KEY=.*|ANON_KEY=$ANON_KEY|g" .env
sed -i "s|SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY|g" .env
sed -i "s|DASHBOARD_USERNAME=.*|DASHBOARD_USERNAME=admin|g" .env
sed -i "s|DASHBOARD_PASSWORD=.*|DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD|g" .env

# Lấy IP public của VPS
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(curl -s https://api.ipify.org)
fi

# Cập nhật SITE_URL và API_EXTERNAL_URL
sed -i "s|SITE_URL=.*|SITE_URL=http://$PUBLIC_IP:3000|g" .env
sed -i "s|API_EXTERNAL_URL=.*|API_EXTERNAL_URL=http://$PUBLIC_IP:8000|g" .env
sed -i "s|SUPABASE_PUBLIC_URL=.*|SUPABASE_PUBLIC_URL=http://$PUBLIC_IP:8000|g" .env

# Cấu hình firewall
log_info "Cấu hình firewall..."
ufw --force enable
ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
ufw allow 3000/tcp    # Supabase Studio
ufw allow 8000/tcp    # Kong API Gateway
ufw allow 5432/tcp    # PostgreSQL (nếu cần truy cập từ bên ngoài)

# Pull Docker images
log_info "Pull Docker images (có thể mất vài phút)..."
docker compose pull

# Khởi động Supabase
log_info "Khởi động Supabase..."
docker compose up -d

# Đợi các services khởi động
log_info "Đợi các services khởi động (30 giây)..."
sleep 30

# Kiểm tra trạng thái
log_info "Kiểm tra trạng thái containers..."
docker compose ps

# Tạo script systemd để tự động khởi động
log_info "Tạo systemd service..."
cat > /etc/systemd/system/supabase.service << 'EOF'
[Unit]
Description=Supabase
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/supabase/supabase/docker
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable supabase.service

# Lưu thông tin đăng nhập
log_info "Lưu thông tin cấu hình..."
cat > /root/supabase-credentials.txt << EOF
=============================================
THÔNG TIN ĐĂNG NHẬP SUPABASE
=============================================

IP Public: $PUBLIC_IP

Supabase Studio:
URL: http://$PUBLIC_IP:3000
Username: admin
Password: $DASHBOARD_PASSWORD

API Gateway:
URL: http://$PUBLIC_IP:8000

Database (PostgreSQL):
Host: $PUBLIC_IP
Port: 5432
Database: postgres
Username: postgres
Password: $POSTGRES_PASSWORD

API Keys:
ANON_KEY: $ANON_KEY
SERVICE_ROLE_KEY: $SERVICE_ROLE_KEY

JWT_SECRET: $JWT_SECRET

=============================================
File cấu hình: /opt/supabase/supabase/docker/.env
Logs: docker compose -f /opt/supabase/supabase/docker/docker-compose.yml logs
=============================================
EOF

chmod 600 /root/supabase-credentials.txt

log_info "====================================="
log_info "CÀI ĐẶT HOÀN TẤT!"
log_info "====================================="
echo ""
log_info "Supabase Studio: http://$PUBLIC_IP:3000"
log_info "API Gateway: http://$PUBLIC_IP:8000"
log_info "Username: admin"
log_info "Password: $DASHBOARD_PASSWORD"
echo ""
log_info "Thông tin chi tiết được lưu tại: /root/supabase-credentials.txt"
echo ""
log_warn "LƯU Ý:"
log_warn "1. Backup file credentials ngay!"
log_warn "2. Nên cấu hình SSL/HTTPS cho production"
log_warn "3. Đổi password mặc định sau khi đăng nhập"
log_warn "4. Hạn chế truy cập port 5432 từ bên ngoài nếu không cần thiết"
echo ""
log_info "Các lệnh hữu ích:"
echo "  - Xem logs: cd /opt/supabase/supabase/docker && docker compose logs -f"
echo "  - Dừng Supabase: systemctl stop supabase"
echo "  - Khởi động Supabase: systemctl start supabase"
echo "  - Khởi động lại: systemctl restart supabase"
echo "  - Xem trạng thái: docker compose ps"
echo ""

exit 0
