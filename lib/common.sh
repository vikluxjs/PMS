#!/usr/bin/env bash
# common.sh — общие помощники для sovpalo-kit. Подключается через `source`.

set -o pipefail

# ---------- вывод ----------
c_reset='\033[0m'; c_g='\033[32m'; c_y='\033[33m'; c_r='\033[31m'; c_b='\033[36m'
log()  { echo -e "${c_b}[*]${c_reset} $*"; }
ok()   { echo -e "${c_g}[+]${c_reset} $*"; }
warn() { echo -e "${c_y}[!]${c_reset} $*"; }
die()  { echo -e "${c_r}[x]${c_reset} $*" >&2; exit 1; }

# ---------- проверки ----------
need_root() { [ "$(id -u)" = "0" ] || die "Запускать от root."; }
have()      { command -v "$1" >/dev/null 2>&1; }

# ---------- генераторы секретов ----------
rand_hex()  { openssl rand -hex "${1:-12}"; }
rand_path() { echo "/$(openssl rand -hex "${1:-10}")"; }
rand_pass() { openssl rand -base64 "${1:-18}" | tr -d '/+=' | cut -c1-"${2:-20}"; }
gen_uuid()  { if have uuidgen; then uuidgen; else cat /proc/sys/kernel/random/uuid; fi; }
ss2022_key(){ openssl rand -base64 16; }   # ключ для 2022-blake3-aes-128-gcm (16 байт)

# punycode: принимает кириллицу или готовый xn--, возвращает ASCII (IDNA)
to_punycode() {
  python3 - "$1" <<'PY'
import sys
d=sys.argv[1].strip().strip('.')
try:
    print(d.encode('idna').decode())
except Exception:
    print(d)
PY
}

# публичный IPv4 сервера
server_ip4() {
  local ip
  ip=$(curl -fsS4 --max-time 8 https://api.ipify.org 2>/dev/null) \
    || ip=$(curl -fsS4 --max-time 8 https://ifconfig.me 2>/dev/null) \
    || ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
  echo "$ip"
}

# A-запись домена (первый адрес)
dns_a() {
  python3 - "$1" <<'PY'
import socket,sys
try:
    print(socket.gethostbyname(sys.argv[1]))
except Exception:
    print("")
PY
}
