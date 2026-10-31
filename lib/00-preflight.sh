#!/usr/bin/env bash
# 00-preflight.sh — проверки окружения и сбор параметров (интерактивно).

phase_preflight() {
  need_root
  have apt-get || die "Поддерживается только Debian/Ubuntu (apt)."
  have curl || { apt-get update -qq && apt-get install -y -qq curl; }
  have openssl || apt-get install -y -qq openssl
  have python3 || apt-get install -y -qq python3

  IP4="$(server_ip4)"; [ -n "$IP4" ] || warn "Не удалось определить публичный IP."
  log "Публичный IP сервера: ${IP4:-неизвестен}"

  # --- домен ---
  if [ -z "${DOMAIN:-}" ]; then
    read -rp "Домен (например так-совпало.рф): " DOMAIN
  fi
  [ -n "$DOMAIN" ] || die "Домен обязателен."
  DOMAIN_PUNY="$(to_punycode "$DOMAIN")"
  log "Домен: $DOMAIN  (punycode: $DOMAIN_PUNY)"

  # --- проверка DNS A -> наш IP ---
  local a; a="$(dns_a "$DOMAIN_PUNY")"
  if [ -z "$a" ]; then
    warn "Домен $DOMAIN_PUNY пока не резолвится. Сертификат LE не выпустится."
  elif [ -n "$IP4" ] && [ "$a" != "$IP4" ]; then
    warn "A-запись $DOMAIN_PUNY = $a, а IP сервера = $IP4 (не совпадают)."
  else
    ok "DNS A указывает на этот сервер ($a)."
  fi
  if [ "${FORCE:-0}" != "1" ] && { [ -z "$a" ] || { [ -n "$IP4" ] && [ "$a" != "$IP4" ]; }; }; then
    read -rp "Продолжить несмотря на DNS? [y/N]: " yn
    [[ "$yn" =~ ^[Yy]$ ]] || die "Прервано. Сначала настройте A (и AAAA) на $IP4, затем повторите."
  fi

  # --- email для Let's Encrypt ---
  [ -n "${LE_EMAIL:-}" ] || read -rp "Email для Let's Encrypt: " LE_EMAIL
  [ -n "$LE_EMAIL" ] || die "Email обязателен."

  # --- доступ к панели 3x-ui ---
  [ -n "${PANEL_USER:-}" ] || read -rp "Логин панели 3x-ui [admin]: " PANEL_USER
  PANEL_USER="${PANEL_USER:-admin}"
  [ -n "${PANEL_PASS:-}" ] || read -rsp "Пароль панели 3x-ui [enter=сгенерировать]: " PANEL_PASS; echo
  PANEL_PASS="${PANEL_PASS:-$(rand_pass 18 20)}"

  # --- пароль панели AmneziaWG ---
  [ -n "${AMNEZIA_PASS:-}" ] || read -rsp "Пароль панели AmneziaWG [enter=сгенерировать]: " AMNEZIA_PASS; echo
  AMNEZIA_PASS="${AMNEZIA_PASS:-$(rand_pass 18 20)}"

  # --- число стартовых клиентов (подписок) ---
  [ -n "${N_CLIENTS:-}" ] || read -rp "Сколько клиентов (подписок) создать сразу? [1]: " N_CLIENTS
  N_CLIENTS="${N_CLIENTS:-1}"

  # --- фиксированные/служебные (localhost-only) ---
  PANEL_PORT="${PANEL_PORT:-43753}"
  SUB_PORT="${SUB_PORT:-2096}"
  SITE_PORT="${SITE_PORT:-8443}"     # nginx за Reality dest
  AWG_UI_PORT="${AWG_UI_PORT:-51821}"
  WG_PORT="${WG_PORT:-51820}"

  # --- секретные пути ---
  PANEL_PATH_SEG="${PANEL_PATH_SEG:-$(rand_hex 12)}"   # без слешей
  AWG_PATH_SEG="${AWG_PATH_SEG:-$(rand_hex 12)}"

  CERT_DIR="/etc/letsencrypt/live/${DOMAIN_PUNY}"
  CERT_FULL="${CERT_DIR}/fullchain.pem"
  CERT_KEY="${CERT_DIR}/privkey.pem"

  export DOMAIN DOMAIN_PUNY LE_EMAIL PANEL_USER PANEL_PASS AMNEZIA_PASS N_CLIENTS \
         PANEL_PORT SUB_PORT SITE_PORT AWG_UI_PORT WG_PORT \
         PANEL_PATH_SEG AWG_PATH_SEG CERT_DIR CERT_FULL CERT_KEY IP4
  ok "Параметры собраны."
}
