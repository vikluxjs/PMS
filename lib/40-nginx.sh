#!/usr/bin/env bash
# 40-nginx.sh — полный vhost: заглушка + подписка + секретные пути панелей (всё на 443 через Reality dest).

phase_nginx() {
  log "Разворачиваю nginx-конфиг (консолидация на 443)…"
  install -m 644 "${KIT_DIR}/templates/ws_upgrade.conf" /etc/nginx/conf.d/ws_upgrade.conf

  # заглушка сайта
  sed "s/__DOMAIN__/${DOMAIN_PUNY}/g" "${KIT_DIR}/templates/index.html" > /var/www/tak-sovpalo/index.html

  # рендер vhost
  sed -e "s/__DOMAIN__/${DOMAIN_PUNY}/g" \
      -e "s/__SITE_PORT__/${SITE_PORT}/g" \
      -e "s/__SUB_PORT__/${SUB_PORT}/g" \
      -e "s/__PANEL_PORT__/${PANEL_PORT}/g" \
      -e "s/__AWG_UI_PORT__/${AWG_UI_PORT}/g" \
      -e "s/__PANEL_SEG__/${PANEL_PATH_SEG}/g" \
      -e "s/__AWG_SEG__/${AWG_PATH_SEG}/g" \
      "${KIT_DIR}/templates/tak.conf.tpl" > /etc/nginx/sites-available/tak.conf

  ln -sf /etc/nginx/sites-available/tak.conf /etc/nginx/sites-enabled/tak.conf
  rm -f /etc/nginx/sites-enabled/tak-bootstrap.conf /etc/nginx/sites-enabled/default

  nginx -t || die "nginx -t не прошёл."
  # ПОЛНЫЙ restart (reload НЕ перепривязывает сокет 0.0.0.0->127.0.0.1 на том же порту)
  systemctl restart nginx || die "nginx не перезапустился."
  ok "nginx сконфигурирован (сайт :${SITE_PORT} только на 127.0.0.1)."
}
