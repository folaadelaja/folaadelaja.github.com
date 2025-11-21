#!/usr/bin/env bash
set -euo pipefail

# Variables
SYSLOG_FILE="/var/log/syslog-ng/network.log"
SYSLOG_CONF="/etc/syslog-ng/syslog-ng.conf"
LOGROTATE_CONF="/etc/logrotate.d/syslog-ng-network"
LISTEN_IP="0.0.0.0"
UDP_PORT=514
TCP_PORT=514

echo "Updating package lists…"
apt update

echo "Installing syslog-ng and logrotate…"
DEBIAN_FRONTEND=noninteractive apt install -y syslog-ng logrotate

echo "Backing up original syslog-ng configuration…"
cp "${SYSLOG_CONF}" "${SYSLOG_CONF}.bak"

echo "Creating syslog-ng configuration…"
cat > "${SYSLOG_CONF}" <<EOF
@version: 3.5

source s_local { system(); internal(); };

source s_network {
    udp(ip("${LISTEN_IP}") port(${UDP_PORT}));
    tcp(ip("${LISTEN_IP}") port(${TCP_PORT}));
};

destination d_netlogs {
    file("${SYSLOG_FILE}"
         log_fifo_size(1000)
         flags(no-parse));
};

log {
    source(s_network);
    destination(d_netlogs);
};
EOF

echo "Setting up log directory and permissions…"
mkdir -p "$(dirname ${SYSLOG_FILE})"
touch "${SYSLOG_FILE}"
chown syslog:adm "${SYSLOG_FILE}"
chmod 640 "${SYSLOG_FILE}"

echo "Creating logrotate configuration for syslog-ng network log…"
cat > "${LOGROTATE_CONF}" <<EOF
${SYSLOG_FILE} {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 syslog adm
    postrotate
        /bin/systemctl reload syslog-ng > /dev/null 2>&1 || true
    endscript
}
EOF

echo "Configuring firewall…"
if command -v ufw >/dev/null 2>&1; then
    ufw allow ${UDP_PORT}/udp
    ufw allow ${TCP_PORT}/tcp
else
    echo "ufw not found – skipping firewall rule creation."
fi

echo "Restarting syslog-ng…"
systemctl enable syslog-ng
systemctl restart syslog-ng

echo "Setup complete!"
echo "Syslog-ng is listening on ${LISTEN_IP}:${UDP_PORT}/UDP and ${TCP_PORT}/TCP."
echo "Logs will be stored in: ${SYSLOG_FILE}"
echo "Logs will be rotated daily, retaining 7 compressed files."
