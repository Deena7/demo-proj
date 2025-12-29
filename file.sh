#!/bin/bash

set -e

### VARIABLES ###
SONAR_VERSION="24.12.0.100206"
SONAR_REAL_DIR="/opt/sonarqube-${SONAR_VERSION}"
SONAR_INSTALL_DIR="/opt/sonarqube"

SONAR_USER="sonar"
SONAR_GROUP="sonar"

POSTGRES_DB="sonarqube"
POSTGRES_USER="sonar"
POSTGRES_PASSWORD="Admin123"

SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}"

### CHECK ROOT ###
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo"
  exit 1
fi

echo "🚀 Starting SonarQube installation..."

### UPDATE SYSTEM ###
apt update -y && apt upgrade -y

### INSTALL REQUIRED PACKAGES ###
apt install -y \
  openjdk-17-jdk \
  postgresql \
  postgresql-contrib \
  unzip \
  wget \
  python3-psycopg2

### START POSTGRESQL ###
systemctl enable postgresql
systemctl start postgresql

### CREATE POSTGRES USER & DB ###
sudo -u postgres psql <<EOF
DO
\$do\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${POSTGRES_USER}') THEN
      CREATE ROLE ${POSTGRES_USER} LOGIN PASSWORD '${POSTGRES_PASSWORD}';
   END IF;
END
\$do\$;

CREATE DATABASE ${POSTGRES_DB} OWNER ${POSTGRES_USER};
EOF

### CREATE SONAR USER & GROUP ###
if ! getent group ${SONAR_GROUP} >/dev/null; then
  groupadd ${SONAR_GROUP}
fi

if ! id ${SONAR_USER} >/dev/null 2>&1; then
  useradd -m -d /home/${SONAR_USER} -s /bin/bash -g ${SONAR_GROUP} ${SONAR_USER}
fi

### DOWNLOAD SONARQUBE ###
cd /tmp
wget -q ${SONAR_URL}

### EXTRACT SONARQUBE ###
unzip -o ${SONAR_ZIP} -d /opt/

### CREATE SYMLINK ###
ln -sfn ${SONAR_REAL_DIR} ${SONAR_INSTALL_DIR}

### CHANGE OWNERSHIP ###
chown -R ${SONAR_USER}:${SONAR_GROUP} ${SONAR_REAL_DIR}

### CONFIGURE SONARQUBE DB ###
SONAR_PROP="${SONAR_INSTALL_DIR}/conf/sonar.properties"

sed -i "s|^#sonar.jdbc.username=.*|sonar.jdbc.username=${POSTGRES_USER}|" $SONAR_PROP
sed -i "s|^#sonar.jdbc.password=.*|sonar.jdbc.password=${POSTGRES_PASSWORD}|" $SONAR_PROP
sed -i "s|^#sonar.jdbc.url=.*|sonar.jdbc.url=jdbc:postgresql://localhost:5432/${POSTGRES_DB}|" $SONAR_PROP

### CREATE SYSTEMD SERVICE ###
cat <<EOF >/etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=network.target postgresql.service

[Service]
Type=forking
ExecStart=${SONAR_INSTALL_DIR}/bin/linux-x86-64/sonar.sh start
ExecStop=${SONAR_INSTALL_DIR}/bin/linux-x86-64/sonar.sh stop
User=${SONAR_USER}
Group=${SONAR_GROUP}
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

### START SONARQUBE ###
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

### STATUS ###
systemctl status sonarqube --no-pager

echo "✅ SonarQube installed successfully!"
echo "🌐 Access: http://<server-ip>:9000"
echo "🔑 Default login: admin / admin"
