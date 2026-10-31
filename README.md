# sovpalo-kit

Разворачивает весь наш VPN-стек на чистом Ubuntu/Debian **одной командой**:

- **3x-ui** (Xray) с **7 протоколами**: VLESS-Reality (443), VLESS-WS, VLESS-XHTTP-Reality,
  VMess-WS, Trojan-TCP, Trojan-gRPC, Shadowsocks-2022 — каждый на своём порту (резервы против DPI).
- **nginx на 443** за Reality-`dest`: сайт-заглушка `/`, подписка `/sub/`, панели по **секретным путям**.
- **AmneziaWG** (amnezia-wg-easy), панель только на localhost.
- **Let's Encrypt** + автопродление, **BBR**, **fail2ban**.
- Служебные порты (панели, подписка, nginx) скрыты на `127.0.0.1` — наружу только
  `22, 80, 443` + VPN-порты + `51820/udp`.

## Запуск

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vikluxjs/PMS/main/install.sh)
```

Скрипт **интерактивно** спросит домен, email для LE, логин/пароль панели и число клиентов.
Всё остальное (ключи Reality, UUID, пароли, subId, секретные пути) — **генерируется само**.

Либо без вопросов — через переменные:

```bash
DOMAIN=так-совпало.рф LE_EMAIL=you@mail.com N_CLIENTS=3 \
bash <(curl -fsSL https://raw.githubusercontent.com/vikluxjs/PMS/main/install.sh)
```

## Установка из приватного репозитория

Пока репозиторий **приватный**, анонимный `curl` к `raw.githubusercontent.com` отдаёт 404 —
нужен **GitHub-токен** (PAT с правом `repo` / `Contents: Read`). В ките секретов нет, поэтому
проще всего сделать репо **публичным** (Settings → General → Danger Zone → Change visibility),
тогда работает обычный однострочник выше. Если же хочешь оставить приватным:

**Способ 1 — клонировать с токеном (рекомендуется):**

```bash
PAT=ghp_xxxxxxxxxxxxxxxxxxxx          # твой токен
git clone https://$PAT@github.com/vikluxjs/PMS.git /opt/sovpalo-kit
bash /opt/sovpalo-kit/install.sh      # видит локальный lib/ и не клонирует повторно
```

**Способ 2 — однострочник с токеном:**

```bash
PAT=ghp_xxxxxxxxxxxxxxxxxxxx
SOVPALO_REPO="https://$PAT@github.com/vikluxjs/PMS" \
bash <(curl -fsSL -H "Authorization: token $PAT" \
  https://raw.githubusercontent.com/vikluxjs/PMS/main/install.sh)
```

`curl` тянет `install.sh` с токеном в заголовке, а `SOVPALO_REPO` с тем же токеном нужен, чтобы
скрипт смог до-клонировать остальные файлы (`lib/`, `templates/`) на сервере.

> ⚠️ Токен попадёт в историю shell и в `/opt/sovpalo-kit/.git/config` (remote с токеном в URL).
> После установки почисти: `history -c` и
> `git -C /opt/sovpalo-kit remote set-url origin https://github.com/vikluxjs/PMS.git`.
> Выдавай токену минимум прав и отзови после использования.

## ⚠️ Предусловие: DNS

Сертификат Let's Encrypt не выпустится, пока домен не указывает на сервер.
**Сначала** заведи A (и желательно AAAA) на IP сервера, **потом** запускай. Скрипт проверит
резолвинг и предупредит.

## Что вводится / что генерируется

| Вводишь | Генерируется автоматически |
|---|---|
| домен, email LE | Reality-пары ключей, shortId |
| логин/пароль панели (или авто) | UUID / пароли клиентов, subId |
| пароль Amnezia (или авто) | секретные пути панелей, пути WS/gRPC/XHTTP, ключ SS-2022 |
| число клиентов | bcrypt-хэш пароля Amnezia |

После установки все доступы — в консоли и в **`/root/credentials.txt`** (chmod 600).

## Структура

```
install.sh              оркестратор (сам подтянет репо при запуске через curl|bash)
lib/common.sh           помощники и генераторы секретов
lib/00-preflight.sh     проверки + сбор параметров
lib/10-base.sh          пакеты, Docker, BBR, fail2ban
lib/20-cert.sh          Let's Encrypt (webroot)
lib/30-xui.sh           установка 3x-ui + наполнение БД
lib/build_xui.py        разворачивает golden-шаблон инбаундов со свежими секретами
lib/40-nginx.sh         vhost: заглушка + /sub/ + секретные пути панелей
lib/50-amnezia.sh       контейнер amnezia-wg-easy
lib/60-harden.sh        проверка поверхности портов
lib/90-summary.sh       карта доступов
templates/              tak.conf.tpl, ws_upgrade.conf, index.html, inbounds_template.json
uninstall.sh            снос стека (сертификаты и том Amnezia не трогает)
config.env.example      шаблон переменных
```

`templates/inbounds_template.json` — «золотой» шаблон 7 инбаундов, снятый с рабочего сервера;
**секретов в нём нет** (домен и все ключи заменены токенами и генерируются при установке).

## Безопасность репозитория

В репозитории **нет ни одного секрета** — ни ключей, ни паролей, ни subId, ни реального домена.
Можно держать публичным. `curl | bash` под root — доверие к репо; это твой репозиторий.

## Пере-установка / идемпотентность

Повторный запуск безопасен: инбаунды пересобираются, nginx-конфиг перезаписывается.
Пароли/ключи при повторе будут **новые** (если не задать прежние через переменные).

## Проверено на

Ubuntu 24.04 / 26.04, 3x-ui `v2.8.10` (Xray 26.2.x). Для другой версии 3x-ui сверь схему
таблицы `inbounds` (см. `lib/build_xui.py`).
