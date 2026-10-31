#!/usr/bin/env bash
# 50-amnezia.sh — контейнер amnezia-wg-easy (панель на localhost, WG UDP наружу).

bcrypt_hash() {
  local pw="$1"
  # 1) python3-bcrypt (как на B-KZ: $2b$12$…)
  if python3 -c "import bcrypt" 2>/dev/null; then
    P="$pw" python3 -c "import bcrypt,os;print(bcrypt.hashpw(os.environ['P'].encode(),bcrypt.gensalt(rounds=12)).decode())"
    return
  fi
  apt-get install -y -qq python3-bcrypt >/dev/null 2>&1 && \
    P="$pw" python3 -c "import bcrypt,os;print(bcrypt.hashpw(os.environ['P'].encode(),bcrypt.gensalt(rounds=12)).decode())" && return
  # 2) запасной путь: htpasswd (apache2-utils) — bcrypt $2y$
  apt-get install -y -qq apache2-utils >/dev/null 2>&1
  htpasswd -bnBC 12 "" "$pw" | tr -d ':\n' | sed 's/^\$2y/\$2a/'
}

phase_amnezia() {
  log "Разворачиваю AmneziaWG (amnezia-wg-easy)…"
  local HASH; HASH="$(bcrypt_hash "$AMNEZIA_PASS")"
  [ -n "$HASH" ] || die "Не удалось сгенерировать bcrypt-хэш пароля Amnezia."

  mkdir -p /opt/amnezia-wg-easy
  docker rm -f amnezia-wg-easy >/dev/null 2>&1 || true
  docker pull ghcr.io/w0rng/amnezia-wg-easy >/dev/null 2>&1 || warn "docker pull не удался — попробую локальный образ."
  docker run -d --name amnezia-wg-easy --restart unless-stopped \
    -e WG_HOST="$DOMAIN_PUNY" \
    -e PASSWORD_HASH="$HASH" \
    -e PORT="$AWG_UI_PORT" \
    -e WG_PORT="$WG_PORT" \
    -e LANG=ru \
    -v /opt/amnezia-wg-easy:/etc/wireguard \
    -p 127.0.0.1:${AWG_UI_PORT}:${AWG_UI_PORT}/tcp \
    -p ${WG_PORT}:${WG_PORT}/udp \
    --cap-add NET_ADMIN --cap-add SYS_MODULE \
    --sysctl net.ipv4.conf.all.src_valid_mark=1 \
    --sysctl net.ipv4.ip_forward=1 \
    ghcr.io/w0rng/amnezia-wg-easy >/dev/null || die "amnezia-wg-easy не стартовал."

  sleep 3
  docker ps --format '{{.Names}}' | grep -q amnezia-wg-easy \
    && ok "AmneziaWG запущен (UI только на 127.0.0.1:${AWG_UI_PORT}, WG UDP ${WG_PORT} наружу)." \
    || { docker logs --tail 20 amnezia-wg-easy 2>&1; die "контейнер amnezia не работает."; }
}
