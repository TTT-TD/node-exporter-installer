#!/bin/bash

# 获取最新的 Node Exporter 版本号
LATEST_URL=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4)

# 下载并安装 Node Exporter
echo "Downloading Node Exporter..."
wget $LATEST_URL -O node_exporter.tar.gz

echo "Installing Node Exporter..."
tar xzf node_exporter.tar.gz
cd $(tar tzf node_exporter.tar.gz | head -1 | cut -f1 -d"/")
sudo cp node_exporter /usr/local/bin/

# 创建 node_exporter 用户
sudo useradd -rs /bin/false node_exporter

# 安装 Apache utils 工具来生成 htpasswd 文件
echo "Installing apache2-utils..."
sudo apt-get update
sudo apt-get install -y apache2-utils

# 设置基本认证
read -p "Enter username for node exporter: " USERNAME
read -sp "Enter password for node exporter: " PASSWORD
echo

# 创建 htpasswd 文件并生成 bcrypt 哈希
sudo htpasswd -bnBC 10 "$USERNAME" "$PASSWORD" > /etc/node_exporter_htpasswd
# 删除文件中的额外冒号
sudo sed -i 's/^://g' /etc/node_exporter_htpasswd

# 创建 Node Exporter 服务文件
cat <<EOF | sudo tee /etc/systemd/system/jiankong.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.config.file=/etc/node_exporter.yml

[Install]
WantedBy=multi-user.target
EOF

# 创建 Node Exporter 配置文件以启用基本认证
cat <<EOF | sudo tee /etc/node_exporter.yml
basic_auth_users:
  $(cut -d ':' -f 1 /etc/node_exporter_htpasswd): $(cut -d ':' -f 2 /etc/node_exporter_htpasswd)
EOF

# 重新加载 systemd，启动并启用服务
sudo systemctl daemon-reload
sudo systemctl start jiankong.service
sudo systemctl enable jiankong.service

# 清理安装文件
cd ..
rm -rf node_exporter.tar.gz $(tar tzf node_exporter.tar.gz | head -1 | cut -f1 -d"/")

echo "Node Exporter installed and started successfully with service name jiankong.service."
echo $(curl -4 ip.sb)":9100"
