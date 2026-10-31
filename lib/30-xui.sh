#!/usr/bin/env bash
# 30-xui.sh — установка 3x-ui (pinned) и наполнение БД golden-шаблоном.

XUI_VERSION="${XUI_VERSION:-v2.8.10}"   # зафиксировано под проверенную схему БД

phase_xui() {
  if [ ! -f /usr/local/x-ui/x-ui ]; then
    log "Установка 3x-ui ${XUI_VERSION}…"
    # официальный установщик MHSanaei, неинтерактивно, с версией
    bash <(curl -Ls "https://raw.githubusercontent.com/MHSanaei/3x-ui/${XUI_VERSION}/install.sh") "${XUI_VERSION}" \
      </dev/null >/tmp/xui_install.log 2>&1 || { tail -30 /tmp/xui_install.log; die "3x-ui не установился."; }
  else
    ok "3x-ui уже установлен — пропускаю установку, обновлю конфиг."
  fi
  [ -f /etc/x-ui/x-ui.db ] || die "x-ui.db не найден после установки."

  log "Останавливаю x-ui и наполняю БД…"
  systemctl stop x-ui 2>/dev/null || true
  cp /etc/x-ui/x-ui.db "/etc/x-ui/x-ui.db.kit.bak.$(date +%s)"

  INBOUNDS_TEMPLATE="${KIT_DIR}/templates/inbounds_template.json" \
  XRAY_BIN="/usr/local/x-ui/bin/xray-linux-amd64" \
  DOMAIN_PUNY="$DOMAIN_PUNY" N_CLIENTS="$N_CLIENTS" CLIENT_NAMES="${CLIENT_NAMES:-}" \
  PANEL_PORT="$PANEL_PORT" SUB_PORT="$SUB_PORT" PANEL_PATH_SEG="$PANEL_PATH_SEG" \
  CERT_FULL="$CERT_FULL" CERT_KEY="$CERT_KEY" \
    python3 "${KIT_DIR}/lib/build_xui.py" || die "build_xui.py упал."

  # логин/пароль/порт/base-path — через родной CLI (корректный хэш пароля)
  /usr/local/x-ui/x-ui setting -username "$PANEL_USER" -password "$PANEL_PASS" >/dev/null 2>&1 \
    && ok "Учётка панели задана через x-ui CLI." \
    || warn "x-ui CLI не принял username/password — проверь вручную (данные в итоге ниже)."
  /usr/local/x-ui/x-ui setting -port "$PANEL_PORT" >/dev/null 2>&1 || true
  /usr/local/x-ui/x-ui setting -webBasePath "/$PANEL_PATH_SEG/" >/dev/null 2>&1 || true

  systemctl enable x-ui >/dev/null 2>&1 || true
  systemctl restart x-ui
  sleep 4
  systemctl is-active --quiet x-ui && ok "x-ui запущен." || { journalctl -u x-ui --no-pager -n 20; die "x-ui не поднялся."; }

  # sanity: xray-конфиг сгенерился с нашими инбаундами
  local n; n=$(python3 -c "import json;print(len([i for i in json.load(open('/usr/local/x-ui/bin/config.json'))['inbounds'] if i.get('protocol')!='tunnel']))" 2>/dev/null || echo 0)
  ok "Активных инбаундов в xray: $n"
  [ "$n" -ge 7 ] || warn "Ожидали 7 инбаундов, получили $n — проверь панель."
}
