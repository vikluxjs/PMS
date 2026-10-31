#!/usr/bin/env bash
# 20-cert.sh — bootstrap nginx на :80 и выпуск сертификата Let's Encrypt (webroot).

phase_cert() {
  log "Bootstrap nginx :80 для ACME…"
  rm -f /etc/nginx/sites-enabled/default
  cat >/etc/nginx/sites-available/tak-bootstrap.conf <<NG
server {
    listen 80; listen [::]:80;
    server_name ${DOMAIN_PUNY};
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 404; }
}
NG
  ln -sf /etc/nginx/sites-available/tak-bootstrap.conf /etc/nginx/sites-enabled/tak-bootstrap.conf
  nginx -t && systemctl reload nginx || die "nginx bootstrap не прошёл."

  if [ -f "$CERT_FULL" ]; then
    ok "Сертификат уже есть ($CERT_FULL) — пропускаю выпуск."
  else
    log "Выпуск сертификата Let's Encrypt для ${DOMAIN_PUNY}…"
    certbot certonly --webroot -w /var/www/certbot -d "${DOMAIN_PUNY}" \
      --email "${LE_EMAIL}" --agree-tos --non-interactive --no-eff-email \
      || die "certbot не выпустил сертификат. Проверь, что DNS A/AAAA указывают на сервер и :80 доступен снаружи."
    ok "Сертификат выпущен."
  fi

  # deploy-hook'и: после продления — перечитать nginx и x-ui
  mkdir -p /etc/letsencrypt/renewal-hooks/deploy
  cat >/etc/letsencrypt/renewal-hooks/deploy/reload-services.sh <<'HK'
#!/usr/bin/env bash
systemctl reload nginx 2>/dev/null || true
systemctl restart x-ui 2>/dev/null || true
HK
  chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-services.sh
  systemctl enable --now certbot.timer >/dev/null 2>&1 || true
  ok "Автопродление включено (certbot.timer)."
}
