#!/bin/bash
set -e

# ─────────────────────────────────────────
#  HTTPS Nginx Setup — Self-signed cert
#  Usage: sudo bash setup_https_nginx.sh
# ─────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Права root ───────────────────────────
if [[ $EUID -ne 0 ]]; then
  error "Запустите скрипт с правами root: sudo bash $0"
fi

# ── Определяем IP сервера ─────────────────
info "Определяем внешний IP сервера..."
SERVER_IP=$(curl -s --max-time 5 ifconfig.me \
         || curl -s --max-time 5 api.ipify.org \
         || curl -s --max-time 5 icanhazip.com)

[[ -z "$SERVER_IP" ]] && error "Не удалось определить внешний IP. Проверьте интернет-соединение."
info "Внешний IP сервера: ${SERVER_IP}"

# ── Устанавливаем зависимости ─────────────
info "Устанавливаем nginx и openssl..."
apt update -qq && apt install -y nginx openssl

# ── Генерируем сертификат ─────────────────
SSL_DIR="/etc/nginx/ssl"
info "Создаём директорию для сертификатов: ${SSL_DIR}"
mkdir -p "$SSL_DIR"

info "Генерируем self-signed сертификат..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${SSL_DIR}/selfsigned.key" \
  -out    "${SSL_DIR}/selfsigned.crt" \
  -subj   "/CN=${SERVER_IP}" \
  -addext "subjectAltName=IP:${SERVER_IP}"

chmod 600 "${SSL_DIR}/selfsigned.key"
info "Сертификат создан."

# ── Nginx конфиг ─────────────────────────
CONF_FILE="/etc/nginx/sites-available/https-check"
info "Записываем конфигурацию nginx..."

cat > "$CONF_FILE" <<EOF
server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     ${SSL_DIR}/selfsigned.crt;
    ssl_certificate_key ${SSL_DIR}/selfsigned.key;

    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    location / {
        default_type text/plain;
        return 200 "OK — HTTPS is working\n";
    }

    location /health {
        access_log off;
        default_type application/json;
        return 200 '{"status":"ok","ip":"${SERVER_IP}"}';
    }
}
EOF

# ── Активируем сайт ───────────────────────
ln -sf "$CONF_FILE" /etc/nginx/sites-enabled/https-check
rm -f /etc/nginx/sites-enabled/default

# ── Проверяем и запускаем ─────────────────
info "Проверяем конфигурацию nginx..."
nginx -t || error "Ошибка в конфигурации nginx"

info "Перезапускаем nginx..."
systemctl restart nginx
systemctl enable nginx --quiet

# ── Итог ──────────────────────────────────
echo ""
echo -e "${GREEN}✓ Готово! HTTPS сервер запущен.${NC}"
echo ""
echo "  Проверка:"
echo "    curl -k https://${SERVER_IP}"
echo "    curl -k https://${SERVER_IP}/health"
echo ""
warn "Браузер покажет предупреждение о сертификате — это нормально для self-signed."
