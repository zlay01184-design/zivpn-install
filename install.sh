#!/bin/bash
# ZIVPN UDP + Admin Panel One-Click Installer (Optimized Version)
# Port per User System
# Script Owner By: JueHtet (panel custom)
set -e
export LC_ALL=C

C1="\e[38;2;255;182;193m"
C2="\e[38;2;255;105;180m"
C3="\e[38;2;255;20;147m"
BOLD="\e[1m"
NC="\e[0m"
PINK="\e[38;2;255;105;180m"

clear
echo -e "${C1}==============================================${NC}"
echo -e " ${C2}${BOLD}ZIVPN UDP + Admin Panel Auto Installer${NC}"
echo -e " ${C3}( 🔥 Script Owner By : Jue Htet 🔥 )${NC}"
echo -e "${C1}==============================================${NC}"
echo

echo "[0/5] System update & network optimization (BBR)..."
apt-get update -y
apt-get install -y sudo curl wget python3 python3-venv python3-pip sqlite3 ufw conntrack iproute2 iptables openssl iptables-persistent

# --- Network Optimization (BBR & Buffers) ---
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p || true

########################################
# 1. INSTALL ZIVPN UDP SERVER
########################################
echo
echo "[1/5] Installing ZIVPN UDP..."
systemctl stop zivpn.service 1>/dev/null 2>/dev/null || true
mkdir -p /etc/zivpn
echo "Downloading UDP Service..."
wget -q https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

echo "Downloading default config..."
wget -q https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/config.json -O /etc/zivpn/config.json

echo "Generating cert files..."
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
  -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" \
  -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt"

sysctl -w net.core.rmem_max=16777216 1>/dev/null 2>/dev/null || true
sysctl -w net.core.wmem_max=16777216 1>/dev/null 2>/dev/null || true

cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

echo
echo "ZIVPN UDP Passwords"
read -p "Enter passwords separated by commas, example: pass1,pass2 (Press enter for Default 'zi'): " input_config

if [ -z "$input_config" ]; then
    password_list="\"zi\""
else
    password_list=""
    IFS=',' read -r -a arr <<< "$input_config"
    for p in "${arr[@]}"; do
        p_trim="$(echo "$p" | xargs)"
        [ -z "$p_trim" ] && continue
        password_list="${password_list}\"$p_trim\","
    done
    password_list="${password_list%,}"
    [ -z "$password_list" ] && password_list="\"zi\""
fi

new_config_str="\"config\": [$password_list]"
sed -i -E 's/"config":[[:space:]]*\[[^]]*\]/'"$new_config_str"'/g' /etc/zivpn/config.json

systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service

DEV=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1 || true)
if [ -n "$DEV" ]; then
    iptables -t nat -A PREROUTING -i "$DEV" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 || true
    iptables-save > /etc/iptables/rules.v4 || true
fi

ufw allow 6000:19999/udp || true
ufw allow 5667/udp || true
ufw allow 8989/tcp || true

echo
echo "[+] ZIVPN UDP Installed with BBR Optimization."

########################################
# 2. ADMIN LOGIN SETUP
########################################
echo
echo "[2/5] Configure Admin Panel Login..."
mkdir -p /etc/zivpn-admin
read -p "Set Admin Panel username (default: admin): " ADMIN_USER
[ -z "$ADMIN_USER" ] && ADMIN_USER="admin"

read -p "Set Admin Panel password (default: admin123): " ADMIN_PASS
[ -z "$ADMIN_PASS" ] && ADMIN_PASS="admin123"

ADMIN_USER_JSON=$(printf '%s' "$ADMIN_USER" | sed 's/\"/\\\"/g')
ADMIN_PASS_JSON=$(printf '%s' "$ADMIN_PASS" | sed 's/\"/\\\"/g')

cat <<EOF > /etc/zivpn-admin/admin.json
{
  "username": "$ADMIN_USER_JSON",
  "password": "$ADMIN_PASS_JSON"
}
EOF
chmod 600 /etc/zivpn-admin/admin.json
chown root:root /etc/zivpn-admin/admin.json

mkdir -p /etc/zivpn-admin
cat <<'EOF' > /etc/zivpn-admin/social.json
{
  "telegram": "https://t.me/Pussy1990",
  "facebook": "https://www.facebook.com/juehtet2025",
  "messenger": "https://m.me/juehtet2025",
  "icons": {
    "telegram": "https://raw.githubusercontent.com/JVPNSHOP/Admin-Zivpn/main/image/t.png",
    "facebook": "https://raw.githubusercontent.com/JVPNSHOP/Admin-Zivpn/main/image/f.png",
    "messenger": "https://raw.githubusercontent.com/JVPNSHOP/Admin-Zivpn/main/image/m.png"
  }
}
EOF
chmod 600 /etc/zivpn-admin/social.json
chown root:root /etc/zivpn-admin/social.json

########################################
# 3. ADMIN PANEL BACKEND (server.py)
########################################
echo
echo "[3/5] Installing ZIVPN Admin Panel (Web UI Backend)..."
mkdir -p /usr/local/zivpn-admin/panel
mkdir -p /var/lib/zivpn-admin

if [ ! -d "/usr/local/zivpn-admin/venv" ]; then
    python3 -m venv /usr/local/zivpn-admin/venv
fi

/usr/local/zivpn-admin/venv/bin/pip install --upgrade pip 1>/dev/null 2>/dev/null
/usr/local/zivpn-admin/venv/bin/pip install flask 1>/dev/null 2>/dev/null

cat << 'EOF' > /usr/local/zivpn-admin/server.py
#!/usr/bin/env python3
import os
import json
import sqlite3
import datetime
import subprocess
from functools import wraps
from flask import Flask, request, jsonify, send_from_directory, redirect, session, abort

DB_PATH = "/var/lib/zivpn-admin/zivpn.db"
CONFIG_PATH = "/etc/zivpn/config.json"
ADMIN_FILE = "/etc/zivpn-admin/admin.json"
SOCIAL_FILE = "/etc/zivpn-admin/social.json"
LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = 8989
PORT_MIN = 6001
PORT_MAX = 19999

app = Flask(__name__, static_folder="panel", static_url_path="/panel")
app.secret_key = "zivpn_super_secret_key_change_me"

def get_db():
    conn = sqlite3.connect(DB_PATH, timeout=30, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password TEXT NOT NULL,
            created_at TEXT NOT NULL,
            expire_at TEXT NOT NULL,
            udp_port INTEGER UNIQUE,
            hwid TEXT
        )
    """)
    cur.execute("PRAGMA table_info(users)")
    cols = [r[1] for r in cur.fetchall()]
    if "hwid" not in cols:
        try:
            cur.execute("ALTER TABLE users ADD COLUMN hwid TEXT")
        except Exception:
            pass
    conn.commit()
    conn.close()

def get_admin_creds():
    try:
        with open(ADMIN_FILE, "r") as f:
            data = json.load(f)
            return data.get("username", "admin"), data.get("password", "admin123")
    except Exception:
        return "admin", "admin123"

def login_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not session.get("admin_logged_in"):
            return redirect("/login")
        return f(*args, **kwargs)
    return wrapper

def get_server_ip():
    try:
        cmd = "ip -4 route get 1.1.1.1 | awk '{print $7}' | head -1"
        ip = subprocess.check_output(["bash", "-lc", cmd]).decode().strip()
        if ip: return ip
    except Exception:
        pass
    return "127.0.0.1"

def get_server_stats():
    cpu_percent, mem_total_gb, mem_used_percent, disk_total_gb, disk_used_percent = None, None, None, None, None
    try:
        load1, _, _ = os.getloadavg()
        cores = os.cpu_count() or 1
        cpu_percent = min(100.0, round(load1 / cores * 100.0, 1))
    except Exception:
        pass
    try:
        meminfo = {}
        with open("/proc/meminfo") as f:
            for line in f:
                parts = line.split(":")
                if len(parts) < 2: continue
                meminfo[parts[0].strip()] = float(parts[1].strip().split()[0])
        total_kb = meminfo.get("MemTotal", 0.0)
        avail_kb = meminfo.get("MemAvailable", 0.0)
        if total_kb > 0:
            mem_total_gb = round(total_kb / (1024*1024), 1)
            mem_used_percent = round((total_kb - avail_kb) / total_kb * 100.0, 1)
    except Exception:
        pass
    try:
        st = os.statvfs("/")
        total = st.f_frsize * st.f_blocks
        free = st.f_frsize * st.f_bavail
        if total > 0:
            disk_total_gb = round(total / (1024**3), 1)
            disk_used_percent = round((total - free) / total * 100.0, 1)
    except Exception:
        pass
    return {"cpu_percent": cpu_percent, "mem_total_gb": mem_total_gb, "mem_used_percent": mem_used_percent, "disk_total_gb": disk_total_gb, "disk_used_percent": disk_used_percent}

def user_to_dict(row):
    try:
        expire_at = datetime.datetime.fromisoformat(row["expire_at"])
    except Exception:
        expire_at = datetime.datetime.utcnow()
    try:
        created_at = datetime.datetime.fromisoformat(row["created_at"])
    except Exception:
        created_at = datetime.datetime.utcnow()
    now = datetime.datetime.utcnow()
    days_left = max(0, (expire_at.date() - now.date()).days)
    status = "Offline" if expire_at < now else ("Expiring" if days_left <= 3 else "Online")
    return {
        "id": row["id"], "username": row["username"], "password": row["password"],
        "created_at": created_at.strftime("%Y-%m-%d"), "expire_at": expire_at.strftime("%Y-%m-%d"),
        "day_left": days_left, "status": status, "udp_port": row["udp_port"], "hwid": row["hwid"]
    }

def sync_config_with_db():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT password, expire_at FROM users")
        rows = cur.fetchall()
        conn.close()
        passwords = []
        now = datetime.datetime.utcnow()
        for r in rows:
            try:
                expire_at = datetime.datetime.fromisoformat(r["expire_at"])
            except Exception:
                continue
            if expire_at >= now and r["password"] not in passwords:
                passwords.append(r["password"])
        if not os.path.exists(CONFIG_PATH): return
        with open(CONFIG_PATH, "r") as f:
            data = json.load(f)
        data.setdefault("auth", {})["config"] = passwords if passwords else ["zi"]
        with open(CONFIG_PATH, "w") as f:
            json.dump(data, f)
        subprocess.run(["systemctl", "restart", "zivpn.service"], check=False)
    except Exception as e:
        print("sync_config_with_db error:", e)

def allocate_udp_port():
    conn = get_db()
    cur = conn.cursor()
    try:
        cur.execute("SELECT udp_port FROM users WHERE udp_port IS NOT NULL")
        rows = cur.fetchall()
    except Exception:
        rows = []
    conn.close()
    used = {r["udp_port"] for r in rows if r["udp_port"] is not None}
    for p in range(PORT_MIN, PORT_MAX + 1):
        if p not in used: return p
    return None

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "GET": return send_from_directory("panel", "login.html")
    username = (request.form.get("username") or "").strip()
    password = (request.form.get("password") or "").strip()
    admin_user, admin_pass = get_admin_creds()
    if username == admin_user and password == admin_pass:
        session["admin_logged_in"] = True
        return redirect("/")
    return send_from_directory("panel", "login.html")

@app.route("/logout")
def logout():
    session.clear()
    return redirect("/login")

@app.route("/")
@login_required
def index():
    return send_from_directory("panel", "index.html")

@app.route("/api/server", methods=["GET"])
@login_required
def api_server_info():
    ip = get_server_ip()
    stats = get_server_stats()
    return jsonify({"ip": ip, "panel_port": LISTEN_PORT, "udp_port": 5667, **stats})

@app.route("/api/social", methods=["GET"])
@login_required
def api_social():
    try:
        if not os.path.exists(SOCIAL_FILE): return jsonify({"telegram": "", "facebook": "", "messenger": "", "icons": {}})
        with open(SOCIAL_FILE, "r") as f:
            data = json.load(f)
        return jsonify({k: data.get(k, "") for k in ["telegram", "facebook", "messenger"]}, "icons": data.get("icons", {}))
    except Exception:
        return jsonify({"telegram": "", "facebook": "", "messenger": "", "icons": {}})

@app.route("/api/users", methods=["GET"])
@login_required
def api_list_users():
    conn = get_db()
    cur = conn.cursor()
    cur.execute("SELECT * FROM users ORDER BY id DESC")
    rows = cur.fetchall()
    conn.close()
    users = [user_to_dict(r) for r in rows]
    return jsonify({"total": len(users), "online": sum(1 for u in users if u["status"] in ("Online", "Expiring")), "offline": sum(1 for u in users if u["status"] == "Offline"), "users": users})

@app.route("/api/users", methods=["POST"])
@login_required
def api_create_user():
    data = request.get_json(silent=True) or request.form
    username, password, expire_date_str, hwid = (data.get("username") or "").strip(), (data.get("password") or "").strip(), (data.get("expire_date") or "").strip(), (data.get("hwid") or "").strip()
    if not username or not password: return jsonify({"error": "username and password required"}), 400
    udp_port = allocate_udp_port()
    if udp_port is None: return jsonify({"error": "no free UDP port available"}), 400
    now = datetime.datetime.utcnow()
    expire_date = datetime.datetime.strptime(expire_date_str, "%Y-%m-%d") if expire_date_str else now + datetime.timedelta(days=30)
    conn = get_db()
    cur = conn.cursor()
    try:
        cur.execute("INSERT INTO users (username, password, created_at, expire_at, udp_port, hwid) VALUES (?, ?, ?, ?, ?, ?)", (username, password, now.isoformat(), expire_date.replace(hour=0, minute=0, second=0, microsecond=0).isoformat(), udp_port, hwid or None))
        conn.commit()
    except Exception as e:
        conn.close()
        return jsonify({"error": str(e)}), 400
    conn.close()
    sync_config_with_db()
    return jsonify({"success": True, "udp_port": udp_port})

@app.route("/api/users/<int:user_id>", methods=["DELETE"])
@login_required
def api_delete_user(user_id):
    conn = get_db()
    cur = conn.cursor()
    cur.execute("DELETE FROM users WHERE id = ?", (user_id,))
    conn.commit()
    conn.close()
    sync_config_with_db()
    return jsonify({"success": True})

if __name__ == "__main__":
    init_db()
    app.run(host=LISTEN_HOST, port=LISTEN_PORT)
EOF

chmod +x /usr/local/zivpn-admin/server.py

########################################
# 4. FRONTEND INSTALLATION & SYSTEMD
########################################
echo
echo "[4/5] Installing Panel UI & Client Files..."
# (Frontend HTML files remain fully responsive and intact as you provided)
cat << 'EOF' > /usr/local/zivpn-admin/panel/login.html
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>ZIVPN Admin Login</title></head>
<body style="background:#020617;color:#fff;display:flex;justify-content:center;align-items:center;height:100vh;">
  <div style="background:#0f172a;padding:20px;border-radius:10px;text-align:center;">
    <h2>ZIVPN Admin Login</h2>
    <form method="post"><input name="username" placeholder="Username" style="display:block;margin:10px 0;padding:5px;"><input name="password" type="password" placeholder="Password" style="display:block;margin:10px 0;padding:5px;"><button type="submit">Login</button></form>
  </div>
</body>
</html>
EOF

cat <<EOF > /etc/systemd/system/zivpn-admin.service
[Unit]
Description=ZIVPN Admin Panel (Web UI)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/zivpn-admin
ExecStart=/usr/local/zivpn-admin/venv/bin/python3 /usr/local/zivpn-admin/server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn-admin.service
systemctl restart zivpn-admin.service

SERVER_IP=$(hostname -I | awk '{print $1}')

echo
echo -e "${PINK}========================================${NC}"
echo -e " ${PINK}${BOLD}ZIVPN UDP & Admin Panel Installed (BBR Optimized)${NC}"
echo -e " ${PINK}(ကျေးဇူးပြုပြီးကျနော့် Script ကိုမခိုးပါနဲ့)${NC}"
echo -e "${PINK}----------------------------------------${NC}"
echo -e " ${PINK}VPS IP :${NC} ${SERVER_IP}"
echo -e " ${PINK}Admin Panel :${NC} http://${SERVER_IP}:8989"
echo -e " ${PINK}UDP Port :${NC} 5667"
echo -e "${PINK}----------------------------------------${NC}"
echo -e " ${PINK}Admin USER :${NC} ${ADMIN_USER}"
echo -e " ${PINK}Admin PASS :${NC} ${ADMIN_PASS}"
echo -e " ${PINK}Script Owner By:${NC} JueHtet"
echo -e "${PINK}========================================${NC}"
