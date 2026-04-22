#!/bin/bash
set -e

# ─────────────────────────────────────────
#  HTTPS Nginx Cleanup
#  Usage: sudo bash cleanup_https_nginx.sh
# ─────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

if [[ $EUID -ne 0 ]]; then
  error "Запустите скрипт с правами root: sudo bash $0"
fi

# ── Останавливаем nginx ───────────────────
info "Останавливаем nginx..."
systemctl stop nginx
systemctl disable nginx --quiet

# ── Удаляем конфиг ────────────────────────
info "Удаляем конфигурацию nginx..."
rm -f /etc/nginx/sites-enabled/https-check
rm -f /etc/nginx/sites-available/https-check

# ── Удаляем сертификаты ───────────────────
info "Удаляем SSL сертификаты..."
rm -rf /etc/nginx/ssl

# ── Удаляем nginx и openssl ───────────────
info "Удаляем nginx и openssl..."
apt remove -y nginx openssl
apt autoremove -y
apt purge -y nginx

echo ""
echo -e "${GREEN}✓ Готово! Всё удалено.${NC}"
