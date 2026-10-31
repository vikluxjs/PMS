#!/usr/bin/env bash
# 10-base.sh — базовые пакеты, Docker, BBR, fail2ban.

phase_base() {
  log "Установка базовых пакетов…"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq \
    nginx certbot python3-certbot-nginx \
    fail2ban curl openssl socat qrencode \
    ca-certificates gnupg uuid-runtime jq >/dev/null
  ok "Пакеты установлены."

  # --- Docker (для amnezia-wg-easy) ---
  if ! have docker; then
    log "Установка Docker…"
    curl -fsSL https://get.docker.com | sh >/dev/null 2>&1 || die "Docker не установился."
    systemctl enable --now docker >/dev/null 2>&1
  fi
  ok "Docker: $(docker --version 2>/dev/null)"

  # --- BBR + fq ---
  log "Включение BBR…"
  cat >/etc/sysctl.d/99-sovpalo.conf <<'SYS'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
SYS
  sysctl --system >/dev/null 2>&1
  ok "congestion control: $(sysctl -n net.ipv4.tcp_congestion_control)"

  # --- fail2ban (sshd) ---
  systemctl enable --now fail2ban >/dev/null 2>&1 || true
  ok "fail2ban активен."

  mkdir -p /var/www/certbot /var/www/tak-sovpalo
}
