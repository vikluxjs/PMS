#!/usr/bin/env bash
# 60-harden.sh — проверка поверхности портов (скрытие уже заложено в конфиги).

phase_harden() {
  log "Проверяю внешнюю поверхность портов…"
  # Служебные порты уже слушают 127.0.0.1 (x-ui settings + nginx + docker -p 127.0.0.1).
  local pub
  pub=$(ss -tlnp 2>/dev/null | grep LISTEN | grep -vE '127\.0\.0\.(1|5)|\[::1\]' \
        | sed -E 's/.*:([0-9]+) .*/\1/' | sort -n | uniq | tr '\n' ' ')
  ok "Открыто наружу (TCP): ${pub}"
  echo "    Ожидаемо: 22 80 443 2053 2083 2087 2443 8388 8447 (+ опц. мониторинг)."

  for p in "$SUB_PORT" "$PANEL_PORT" "$SITE_PORT" "$AWG_UI_PORT"; do
    if ss -tlnp 2>/dev/null | grep -E ":$p " | grep -qvE '127\.0\.0\.1'; then
      warn "Порт $p виден НЕ только на localhost — проверь!"
    fi
  done
  ok "Служебные порты ($SUB_PORT/$PANEL_PORT/$SITE_PORT/$AWG_UI_PORT) скрыты на localhost."
  warn "ufw намеренно НЕ включаем: скрытые сервисы на 127.0.0.1, дата-порты обязаны быть открыты."
}
