#!/usr/bin/env python3
# build_xui.py — разворачивает golden-шаблон инбаундов в x-ui.db со свежими секретами.
# Запускается при ОСТАНОВЛЕННОМ x-ui. Параметры — из переменных окружения.
import os, sys, json, sqlite3, subprocess, secrets, base64, time, uuid, random

DB      = os.environ.get("XUI_DB", "/etc/x-ui/x-ui.db")
TMPL    = os.environ["INBOUNDS_TEMPLATE"]
XRAY    = os.environ.get("XRAY_BIN", "/usr/local/x-ui/bin/xray-linux-amd64")
DOMAIN  = os.environ["DOMAIN_PUNY"]
N       = int(os.environ.get("N_CLIENTS", "1"))
NAMES   = [s for s in os.environ.get("CLIENT_NAMES", "").split(",") if s]
PANEL_PORT = os.environ.get("PANEL_PORT", "43753")
SUB_PORT   = os.environ.get("SUB_PORT", "2096")
PANEL_SEG  = os.environ["PANEL_PATH_SEG"]
CERT_FULL  = os.environ["CERT_FULL"]
CERT_KEY   = os.environ["CERT_KEY"]
NOW = int(time.time() * 1000)

def reality_keypair():
    # xray x25519 печатает приватный ключ в строке 'PrivateKey:' и ПУБЛИЧНЫЙ —
    # в строке 'Password:' (в свежих сборках xray публичный ключ переименован).
    # Возвращаем пару (priv, pub): pub идёт клиенту в pbk=.
    out = subprocess.check_output([XRAY, "x25519"], text=True)
    priv = pub = None
    for line in out.splitlines():
        low = line.lower()
        if "private" in low:
            priv = line.split(":", 1)[1].strip()
        elif "password" in low or "public" in low:
            pub = line.split(":", 1)[1].strip()
    if not priv or not pub:
        raise RuntimeError("не распарсил xray x25519 (нужны priv+pub):\n" + out)
    return priv, pub

def short_ids():
    ids = [""]
    for ln in (2, 4, 6, 8, 12, 16):
        ids.append(secrets.token_hex(ln // 2))
    random.shuffle(ids)
    return ids

def rand_path(n=11):   return "/" + secrets.token_hex(n)
def rand_svc(n=5):     return secrets.token_hex(n)
def ss_key():          return base64.b64encode(os.urandom(16)).decode()
def sub_id():          return secrets.token_hex(8)              # 16 hex-символов
def trojan_pw():       return secrets.token_urlsafe(16)

def sub_token(o, dom):
    if isinstance(o, str):  return o.replace("__DOMAIN__", dom)
    if isinstance(o, list): return [sub_token(x, dom) for x in o]
    if isinstance(o, dict): return {k: sub_token(v, dom) for k, v in o.items()}
    return o

def client_names():
    if NAMES: return NAMES[:N] + [f"user{i+1}" for i in range(len(NAMES), N)]
    return [f"user{i+1}" for i in range(N)]

def make_client(tmpl_client, proto, name, subid):
    c = json.loads(json.dumps(tmpl_client))          # глубокая копия
    c["email"]   = name
    c["subId"]   = subid
    c["enable"]  = True
    c["created_at"] = NOW; c["updated_at"] = NOW
    if "id" in c:        c["id"] = str(uuid.uuid4())
    if "password" in c:
        if proto == "shadowsocks": c["password"] = ss_key()
        elif proto == "trojan":    c["password"] = trojan_pw()
        else:                      c["password"] = trojan_pw()
    return c

def main():
    tmpl = json.load(open(TMPL, encoding="utf-8"))
    db = sqlite3.connect(DB)
    cur = db.cursor()

    # ---- settings (key/value upsert) ----
    def setv(k, v):
        if cur.execute("update settings set value=? where key=?", (v, k)).rowcount == 0:
            cur.execute("insert into settings(key,value) values(?,?)", (k, v))
    for k, v in {
        "webBasePath": f"/{PANEL_SEG}/", "webPort": PANEL_PORT, "webListen": "127.0.0.1",
        "webCertFile": CERT_FULL, "webKeyFile": CERT_KEY,
        "subEnable": "true", "subPort": SUB_PORT, "subListen": "127.0.0.1",
        "subPath": "/sub/", "subJsonPath": "/json/", "subURI": f"https://{DOMAIN}",
        "subCertFile": CERT_FULL, "subKeyFile": CERT_KEY, "subEncrypt": "true",
    }.items():
        setv(k, v)

    # ---- чистим старые инбаунды/статистику (идемпотентность) ----
    cur.execute("delete from inbounds")
    cur.execute("delete from client_traffics")

    names = client_names()
    built = []
    for t in tmpl:
        proto = t["protocol"]
        st = sub_token(t["settings"], DOMAIN)
        ss = sub_token(t["stream_settings"], DOMAIN)
        sn = sub_token(t["sniffing"], DOMAIN) if t["sniffing"] else None

        # свежие секреты транспорта
        if ss.get("security") == "reality":
            priv, pub = reality_keypair()
            ss["realitySettings"]["privateKey"] = priv
            ss["realitySettings"]["shortIds"] = short_ids()
            # публичный ключ в клиентскую часть → попадает в подписку как pbk=
            ss["realitySettings"].setdefault("settings", {})["publicKey"] = pub
        if "wsSettings" in ss and "path" in ss["wsSettings"]:
            ss["wsSettings"]["path"] = rand_path()
        if "xhttpSettings" in ss and "path" in ss["xhttpSettings"]:
            ss["xhttpSettings"]["path"] = rand_path()
        if "grpcSettings" in ss and "serviceName" in ss["grpcSettings"]:
            ss["grpcSettings"]["serviceName"] = rand_svc()
        if proto == "shadowsocks" and "password" in st:
            st["password"] = ss_key()

        # клиенты
        tmpl_client = st["clients"][0]
        clients = []
        for nm in names:
            sid = subids.setdefault(nm, sub_id())
            # email обязан быть глобально уникальным в x-ui → дискриминируем портом
            # инбаунда; subId общий на юзера, поэтому /sub/<subId> по-прежнему
            # собирает все протоколы в одну подписку.
            clients.append(make_client(tmpl_client, proto, f"{nm}-{t['port']}", sid))
        st["clients"] = clients

        cur.execute(
            "insert into inbounds(user_id,up,down,total,all_time,remark,enable,expiry_time,"
            "listen,port,protocol,settings,stream_settings,tag,sniffing) "
            "values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (t.get("user_id", 1), 0, 0, 0, 0, t.get("remark", ""), 1, 0,
             t.get("listen", ""), t["port"], proto,
             json.dumps(st, ensure_ascii=False), json.dumps(ss, ensure_ascii=False),
             t["tag"], json.dumps(sn, ensure_ascii=False) if sn else None))
        inbound_id = cur.lastrowid
        for c in clients:
            cur.execute(
                "insert into client_traffics(inbound_id,enable,email,up,down,all_time,"
                "expiry_time,total,reset) values(?,?,?,?,?,?,?,?,?)",
                (inbound_id, 1, c["email"], 0, 0, 0, 0, 0, 0))
        built.append({"port": t["port"], "protocol": proto})

    db.commit(); db.close()

    # карта клиентов для итоговой выжимки
    out = {"domain": DOMAIN, "clients": [{"name": nm, "subId": subids[nm],
            "sub_url": f"https://{DOMAIN}/sub/{subids[nm]}"} for nm in names],
           "inbounds": built}
    json.dump(out, open("/root/.sovpalo_build.json", "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print(f"[build_xui] inbounds={len(built)} clients={len(names)}")

subids = {}
if __name__ == "__main__":
    main()
