# Script Tự Động Cài Đặt Supabase trên Ubuntu VPS

Script này giúp tự động cài đặt và cấu hình Supabase (phiên bản open source) trên Ubuntu VPS, đặc biệt là Amazon Lightsail.

## Yêu Cầu Hệ Thống

- Ubuntu 20.04 LTS hoặc 22.04 LTS
- RAM tối thiểu: 2GB (khuyến nghị 4GB+)
- Disk: 20GB trở lên
- VPS có kết nối Internet

## Cách Sử Dụng Trên Amazon Lightsail

### Phương Pháp 1: User Data Script (Tự động khi tạo VPS)

1. Khi tạo instance mới trên Amazon Lightsail
2. Tại mục "Launch script" (User data), paste nội dung sau:

```bash
#!/bin/bash
curl -fsSL https://raw.githubusercontent.com/dangtuongworkshop/freescripts/main/install-supabase.sh -o /tmp/install-supabase.sh
chmod +x /tmp/install-supabase.sh
/tmp/install-supabase.sh > /var/log/supabase-install.log 2>&1
```

Hoặc upload trực tiếp file script:

```bash
#!/bin/bash
cd /tmp
cat << 'EOFSCRIPT' > install-supabase.sh
# (Paste toàn bộ nội dung file install-supabase.sh vào đây)
EOFSCRIPT
chmod +x install-supabase.sh
./install-supabase.sh > /var/log/supabase-install.log 2>&1
```

### Phương Pháp 2: Chạy Thủ Công Sau Khi Tạo VPS

1. SSH vào VPS:
```bash
ssh ubuntu@YOUR_VPS_IP
```

2. Tải script:
```bash
wget https://raw.githubusercontent.com/dangtuongworkshop/freescripts/main/install-supabase.sh
# Hoặc
curl -O https://raw.githubusercontent.com/dangtuongworkshop/freescripts/main/install-supabase.sh
```

3. Phân quyền và chạy:
```bash
chmod +x install-supabase.sh
sudo ./install-supabase.sh
```

## Script Sẽ Tự Động

1. ✅ Cập nhật hệ thống Ubuntu
2. ✅ Cài đặt Docker và Docker Compose
3. ✅ Clone Supabase repository từ GitHub
4. ✅ Tạo JWT secrets và passwords ngẫu nhiên
5. ✅ Cấu hình file .env tự động
6. ✅ Thiết lập firewall (UFW)
7. ✅ Pull tất cả Docker images cần thiết
8. ✅ Khởi động Supabase
9. ✅ Tạo systemd service để tự động khởi động
10. ✅ Lưu thông tin đăng nhập vào `/root/supabase-credentials.txt`

## Sau Khi Cài Đặt

### Truy cập Supabase

- **Supabase Studio**: `http://YOUR_VPS_IP:3000`
- **API Gateway**: `http://YOUR_VPS_IP:8000`
- **PostgreSQL**: `YOUR_VPS_IP:5432`

### Xem Thông Tin Đăng Nhập

```bash
sudo cat /root/supabase-credentials.txt
```

### Xem Logs Cài Đặt

```bash
cat /var/log/supabase-install.log
```

### Xem Logs Supabase

```bash
cd /opt/supabase/supabase/docker
docker compose logs -f
```

## Quản Lý Supabase

### Khởi động
```bash
sudo systemctl start supabase
# Hoặc
cd /opt/supabase/supabase/docker && docker compose up -d
```

### Dừng
```bash
sudo systemctl stop supabase
# Hoặc
cd /opt/supabase/supabase/docker && docker compose down
```

### Khởi động lại
```bash
sudo systemctl restart supabase
```

### Xem trạng thái
```bash
cd /opt/supabase/supabase/docker
docker compose ps
```

## Cấu Hình Amazon Lightsail Networking

Sau khi cài đặt, cần mở các port sau trong Lightsail Networking:

1. Vào instance > Networking tab
2. Thêm các firewall rules:
   - SSH: TCP 22
   - HTTP: TCP 80
   - HTTPS: TCP 443
   - Supabase Studio: TCP 3000
   - API Gateway: TCP 8000
   - PostgreSQL (optional): TCP 5432

## Cấu Hình Domain và SSL (Khuyến nghị)

### Sử dụng Nginx Reverse Proxy + Let's Encrypt

1. Cài đặt Nginx và Certbot:
```bash
sudo apt install nginx certbot python3-certbot-nginx -y
```

2. Tạo cấu hình Nginx cho Supabase Studio:
```bash
sudo nano /etc/nginx/sites-available/supabase
```

Nội dung:
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

server {
    listen 80;
    server_name api.your-domain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

3. Kích hoạt và cấu hình SSL:
```bash
sudo ln -s /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
sudo certbot --nginx -d your-domain.com -d api.your-domain.com
```

4. Cập nhật `.env`:
```bash
cd /opt/supabase/supabase/docker
sudo nano .env
```

Thay đổi:
```
SITE_URL=https://your-domain.com
API_EXTERNAL_URL=https://api.your-domain.com
SUPABASE_PUBLIC_URL=https://api.your-domain.com
```

5. Khởi động lại:
```bash
sudo systemctl restart supabase
```

## Bảo Mật

### Khuyến nghị:

1. **Đổi passwords mặc định** ngay sau khi đăng nhập lần đầu
2. **Backup file credentials**:
   ```bash
   sudo cp /root/supabase-credentials.txt ~/supabase-backup.txt
   ```
3. **Hạn chế truy cập PostgreSQL** từ bên ngoài nếu không cần:
   ```bash
   sudo ufw delete allow 5432/tcp
   ```
4. **Sử dụng SSL/HTTPS** cho production
5. **Thường xuyên backup database**
6. **Cập nhật hệ thống định kỳ**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## Backup và Restore

### Backup Database

```bash
cd /opt/supabase/supabase/docker
docker compose exec db pg_dumpall -U postgres > backup_$(date +%Y%m%d).sql
```

### Restore Database

```bash
cd /opt/supabase/supabase/docker
cat backup_YYYYMMDD.sql | docker compose exec -T db psql -U postgres
```

## Gỡ Cài Đặt

```bash
cd /opt/supabase/supabase/docker
sudo docker compose down -v
sudo systemctl disable supabase
sudo rm /etc/systemd/system/supabase.service
sudo systemctl daemon-reload
sudo rm -rf /opt/supabase
```

## Xử Lý Sự Cố

### Services không khởi động
```bash
cd /opt/supabase/supabase/docker
docker compose logs
```

### Không truy cập được Studio
- Kiểm tra firewall: `sudo ufw status`
- Kiểm tra containers: `docker compose ps`
- Kiểm tra logs: `docker compose logs studio`

### Out of memory
- Tăng RAM của VPS hoặc thêm swap:
```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Hỗ Trợ

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase GitHub](https://github.com/supabase/supabase)
- [Docker Documentation](https://docs.docker.com/)

## License

MIT License
