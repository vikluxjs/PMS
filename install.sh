#!/usr/bin/env bash
# sovpalo-kit — установка всего VPN-стека (3x-ui 7-proto + Reality + nginx на 443
# + AmneziaWG + скрытие служебных портов) одной командой.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/<USER>/sovpalo-kit/main/install.sh)
#
# Переменные можно задать заранее (иначе спросит интерактивно):
#   DOMAIN= LE_EMAIL= PANEL_USER= PANEL_PASS= AMNEZIA_PASS= N_CLIENTS= FORCE=1
set -Eeuo pipefail

# ---------- где лежат файлы кита ----------
SELF="${BASH_SOURCE[0]:-$0}"
SELF_DIR="$(cd "$(dirname "$SELF")" 2>/dev/null && pwd || true)"

if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/lib/common.sh" ]; then
  KIT_DIR="$SELF_DIR"
else
  # запущено через процесс-подстановку (curl | bash) — подтянем репозиторий
  REPO="${SOVPALO_REPO:-https://github.com/vikluxjs/PMS}"
  BRANCH="${SOVPALO_BRANCH:-main}"
  KIT_DIR="/opt/sovpalo-kit"
  command -v git >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y -qq git; }
  if [ -d "$KIT_DIR/.git" ]; then git -C "$KIT_DIR" pull --ff-only || true
  else git clone --depth 1 -b "$BRANCH" "$REPO" "$KIT_DIR"; fi
  exec bash "$KIT_DIR/install.sh" "$@"
fi
export KIT_DIR

# ---------- подключаем модули ----------
# shellcheck source=/dev/null
source "$KIT_DIR/lib/common.sh"
for m in 00-preflight 10-base 20-cert 30-xui 40-nginx 50-amnezia 60-harden 90-summary; do
  source "$KIT_DIR/lib/$m.sh"
done

trap 'die "Ошибка на строке $LINENO. Смотри вывод выше."' ERR

echo
echo "  ┌──────────────────────────────────────────────┐"
echo "  │  SOVPALO-KIT · развёртывание VPN-стека на 443  │"
echo "  └──────────────────────────────────────────────┘"
echo

phase_preflight
phase_base
phase_cert
phase_xui
phase_nginx
phase_amnezia
phase_harden
phase_summary

echo
ok "Установка завершена. Доступы выше и в /root/credentials.txt."
