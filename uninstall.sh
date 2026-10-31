#!/usr/bin/env bash
# uninstall.sh — снести стек, установленный sovpalo-kit. Сертификаты LE НЕ трогает.
set -uo pipefail
[ "$(id -u)" = "0" ] || { echo "Запускать от root."; exit 1; }

read -rp "Снести 3x-ui, nginx-конфиг и контейнер AmneziaWG? [y/N]: " yn
[[ "$yn" =~ ^[Yy]$ ]] || { echo "Отменено."; exit 0; }

echo "[*] Останавливаю и удаляю x-ui…"
systemctl stop x-ui 2>/dev/null || true
/usr/local/x-ui/x-ui uninstall 2>/dev/null || true
rm -rf /usr/local/x-ui /etc/x-ui

echo "[*] Удаляю контейнер AmneziaWG…"
docker rm -f amnezia-wg-easy 2>/dev/null || true
# том /opt/amnezia-wg-easy оставляю (там ключи/клиенты); удалить вручную при желании.

echo "[*] Убираю nginx-конфиги кита…"
rm -f /etc/nginx/sites-enabled/tak.conf /etc/nginx/sites-available/tak.conf \
      /etc/nginx/sites-enabled/tak-bootstrap.conf /etc/nginx/sites-available/tak-bootstrap.conf \
      /etc/nginx/conf.d/ws_upgrade.conf
systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true

echo "[+] Готово. Сертификаты LE и том Amnezia оставлены намеренно."
