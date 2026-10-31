#!/usr/bin/env bash
# 90-summary.sh — итоговая карта доступов (в консоль и в /root/credentials.txt).

phase_summary() {
  local f=/root/credentials.txt
  {
    echo "==================================================================="
    echo " SOVPALO-KIT — доступы (создано $(date '+%Y-%m-%d %H:%M %Z'))"
    echo " Домен: ${DOMAIN}  (punycode ${DOMAIN_PUNY})   IP: ${IP4}"
    echo "==================================================================="
    echo
    echo "[ Панель 3x-ui ]"
    echo "  URL:    https://${DOMAIN_PUNY}/${PANEL_PATH_SEG}/"
    echo "  Логин:  ${PANEL_USER}"
    echo "  Пароль: ${PANEL_PASS}"
    echo
    echo "[ Панель AmneziaWG ]  (заходить СО СЛЕШОМ на конце)"
    echo "  URL:    https://${DOMAIN_PUNY}/${AWG_PATH_SEG}/"
    echo "  Пароль: ${AMNEZIA_PASS}"
    echo "  (прямой :${AWG_UI_PORT} только localhost; фолбэк: ssh -L ${AWG_UI_PORT}:127.0.0.1:${AWG_UI_PORT} root@${IP4})"
    echo
    echo "[ Подписки 3x-ui ]"
    if [ -f /root/.sovpalo_build.json ]; then
      python3 - <<'PY'
import json
d=json.load(open("/root/.sovpalo_build.json"))
for c in d["clients"]:
    print(f"  {c['name']:<20} {c['sub_url']}")
PY
    fi
    echo
    echo "[ Открытые порты наружу ]"
    echo "  22(SSH) 80(ACME+redirect) 443(Reality+всё служебное)"
    echo "  VPN: 2053 2083 2087 2443 8388 8447 ; UDP ${WG_PORT}(AmneziaWG)"
    echo
    echo "[ Прочее ]"
    echo "  Сертификат LE: /etc/letsencrypt/live/${DOMAIN_PUNY}/ (автопродление certbot.timer)"
    echo "  x-ui БД: /etc/x-ui/x-ui.db ; бэкапы: /etc/x-ui/x-ui.db.kit.bak.*"
    echo "==================================================================="
  } | tee "$f"
  chmod 600 "$f"
  ok "Готово. Доступы сохранены в ${f} (chmod 600)."
}
