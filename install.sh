#!/bin/bash
# ZIVPN UDP + Admin Panel One-Click Installer (3D Stylish UI & BBR Optimized)
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

echo "[0/5] System update & BBR network optimization..."
apt-get update -y
apt-get install -y sudo curl wget python3 python3-venv python3-pip sqlite3 ufw conntrack iproute2 iptables openssl iptables-persistent

# --- BBR & Network Optimization ---
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
  iptables -t nat -A POSTROUTING -o "$DEV" -j MASQUERADE
  iptables -A FORWARD -i "$DEV" -o "$DEV" -j ACCEPT
  iptables -t nat -A PREROUTING -i "$DEV" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 || true
  iptables-save > /etc/iptables/rules.v4 || true
fi

ufw allow 6000:19999/udp || true
ufw allow 5667/udp || true
ufw allow 8989/tcp || true

echo
echo "[+] ZIVPN UDP Installed with BBR & Routing Fixed."

########################################
# 2. ADMIN LOGIN & SOCIAL SETUP
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
echo "[3/5] Installing ZIVPN Admin Panel Backend..."
apt-get install -y python3-venv python3-pip 1>/dev/null 2>/dev/null || true
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
from flask import Flask, request, jsonify, send_from_directory, redirect, session

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
    days_left = (expire_at.date() - now.date()).days
    if days_left < 0: days_left = 0
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
        return jsonify({
            "telegram": data.get("telegram", ""),
            "facebook": data.get("facebook", ""),
            "messenger": data.get("messenger", ""),
            "icons": data.get("icons", {})
        })
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
    username = (data.get("username") or "").strip()
    password = (data.get("password") or "").strip()
    expire_date_str = (data.get("expire_date") or "").strip()
    hwid = (data.get("hwid") or "").strip()
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
# 4. STYLISH 3D & MOONLIGHT UI (HTML/CSS)
########################################
echo
echo "[4/5] Installing 3D Stylish Panel UI..."

# ---- login.html (3D Stylish Glow) ----
cat << 'EOF' > /usr/local/zivpn-admin/panel/login.html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>ZIVPN Admin Login</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
      background: radial-gradient(circle at top, #1e1b4b 0, #09090b 60%, #000 100%);
      color: #f4f4f5; font-family: system-ui, -apple-system, sans-serif;
    }
    .card {
      background: rgba(24, 24, 27, 0.85); border-radius: 20px; padding: 30px; width: 320px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.8), inset 0 1px 0 rgba(255, 255, 255, 0.1);
      border: 1px solid rgba(168, 85, 247, 0.3); backdrop-filter: blur(16px);
      transform: translateY(-5px); transition: all 0.3s ease;
    }
    h2 { margin: 0 0 5px; font-size: 1.6rem; text-align: center; background: linear-gradient(135deg, #38bdf8, #c084fc, #f472b6); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
    .subtitle { font-size: 0.75rem; color: #a1a1aa; text-align: center; margin-bottom: 20px; }
    label { display: block; font-size: 0.75rem; color: #d4d4d8; margin-bottom: 5px; }
    input {
      width: 100%; padding: 10px 12px; margin-bottom: 12px; background: rgba(9, 9, 11, 0.8);
      border: 1px solid rgba(168, 85, 247, 0.4); color: #fff; border-radius: 10px; box-sizing: border-box;
      outline: none; transition: border-color 0.2s;
    }
    input:focus { border-color: #38bdf8; box-shadow: 0 0 10px rgba(56, 189, 248, 0.3); }
    button {
      width: 100%; padding: 10px; border-radius: 999px; border: none; cursor: pointer;
      background: linear-gradient(135deg, #38bdf8, #8b5cf6, #ec4899); color: #fff; font-weight: bold;
      font-size: 0.95rem; box-shadow: 0 10px 20px rgba(139, 92, 246, 0.4); transition: transform 0.2s;
    }
    button:active { transform: scale(0.98); }
    .footer-social { display: flex; justify-content: center; gap: 12px; margin-top: 20px; }
    .footer-social a { width: 36px; height: 36px; border-radius: 50%; background: rgba(255,255,255,0.05); display: flex; align-items: center; justify-content: center; border: 1px solid rgba(255,255,255,0.1); }
    .footer-social img { width: 20px; height: 20px; object-fit: contain; }
  </style>
</head>
<body>
  <div class="card">
    <h2>ZIVPN Admin</h2>
    <div class="subtitle">Secure 3D Moonlight Panel</div>
    <form method="post">
      <label>Username</label>
      <input name="username" required autocomplete="off">
      <label>Password</label>
      <input name="password" type="password" required>
      <button type="submit">Login Now</button>
    </form>
    <div class="footer-social" id="login-social"></div>
  </div>
  <script>
    fetch('/api/social').then(res => res.json()).then(data => {
      const c = document.getElementById('login-social');
      const icons = data.icons || {};
      ['telegram', 'facebook', 'messenger'].forEach(k => {
        if(data[k]) {
          c.innerHTML += `<a href="${data[k]}" target="_blank"><img src="${icons[k]||''}" alt="${k}"></a>`;
        }
      });
    }).catch(e=>{});
  </script>
</body>
</html>
EOF

# ---- index.html (3D Moonlight UI, Rotating Loader, Days Left & Beautiful Layout) ----
cat << 'EOF' > /usr/local/zivpn-admin/panel/index.html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>ZIVPN Admin Panel - Moonlight 3D</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      margin: 0; padding: 20px; background: radial-gradient(circle at top, #0f172a 0, #020617 70%, #000 100%);
      color: #f1f5f9; font-family: system-ui, -apple-system, sans-serif; min-height: 100vh;
    }
    .container { max-width: 1000px; margin: 0 auto; }
    .card {
      background: rgba(15, 23, 42, 0.85); border-radius: 20px; padding: 24px;
      box-shadow: 0 20px 40px rgba(0,0,0,0.8), inset 0 1px 0 rgba(255,255,255,0.1);
      border: 1px solid rgba(56, 189, 248, 0.25); backdrop-filter: blur(16px);
      margin-bottom: 20px;
    }
    .header-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; }
    h1 { font-size: 1.5rem; margin: 0; background: linear-gradient(135deg, #38bdf8, #a855f7, #ec4899); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
    .btn {
      padding: 8px 16px; border-radius: 999px; border: none; cursor: pointer; font-weight: 600; font-size: 0.85rem;
      background: linear-gradient(135deg, #22c55e, #0ea5e9); color: #020617; box-shadow: 0 4px 12px rgba(34,197,94,0.4);
      text-decoration: none; display: inline-flex; align-items: center; gap: 6px;
    }
    .btn-danger { background: linear-gradient(135deg, #f43f5e, #e11d48); color: #fff; box-shadow: 0 4px 12px rgba(244,63,94,0.4); }
    .server-info { background: rgba(30, 41, 59, 0.6); padding: 12px 16px; border-radius: 12px; font-size: 0.85rem; margin-bottom: 15px; border: 1px solid rgba(255,255,255,0.05); }
    .form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 10px; margin-bottom: 15px; }
    input {
      width: 100%; padding: 9px 12px; background: rgba(15, 23, 42, 0.9); border: 1px solid rgba(148, 163, 184, 0.3);
      color: #fff; border-radius: 10px; box-sizing: border-box; font-size: 0.85rem; outline: none;
    }
    input:focus { border-color: #38bdf8; box-shadow: 0 0 8px rgba(56, 189, 248, 0.3); }
    .users-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px; }
    .user-card {
      background: rgba(30, 41, 59, 0.7); border-radius: 14px; padding: 14px;
      border: 1px solid rgba(148, 163, 184, 0.2); position: relative; overflow: hidden;
      box-shadow: 0 8px 20px rgba(0,0,0,0.4);
    }
    .user-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; font-weight: bold; font-size: 0.95rem; }
    /* 3D Rotating Loader */
    .loader3d {
      width: 14px; height: 14px; border-radius: 50%;
      background: conic-gradient(#38bdf8, #a855f7, #ec4899, #22c55e, #38bdf8);
      animation: spin3d 1s linear infinite; box-shadow: 0 0 8px rgba(56,189,248,0.8);
      display: inline-block; margin-right: 6px;
    }
    @keyframes spin3d { to { transform: rotate(360deg); } }
    .badge-port { font-size: 0.75rem; background: rgba(34, 197, 94, 0.2); color: #86efac; border: 1px solid #22c55e; padding: 2px 8px; border-radius: 999px; }
    .field-row { display: flex; justify-content: space-between; font-size: 0.8rem; margin: 4px 0; color: #cbd5e1; }
    .field-val { font-weight: 600; background: linear-gradient(120deg, #38bdf8, #c084fc); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
    .footer-icons { margin-top: 20px; display: flex; align-items: center; gap: 10px; font-size: 0.85rem; color: #94a3b8; }
    .footer-icons a { width: 34px; height: 34px; border-radius: 8px; background: rgba(255,255,255,0.05); display: inline-flex; align-items: center; justify-content: center; border: 1px solid rgba(255,255,255,0.1); }
    .footer-icons img { width: 20px; height: 20px; object-fit: contain; }
  </style>
</head>
<body>
  <div class="container">
    <div class="card">
      <div class="header-row">
        <h1>ZIVPN Moonlight Panel</h1>
        <a href="/logout" class="btn btn-danger">🔒 Logout</a>
      </div>
      <div class="server-info" id="server-info">Detecting server details...</div>

      <h3>Add New User</h3>
      <form onsubmit="createUser(event)">
        <div class="form-grid">
          <input id="username" placeholder="Username" required autocomplete="off">
          <input id="password" placeholder="Password" required autocomplete="off">
          <input id="expire_date" type="date" required>
          <button class="btn" type="submit">➕ Add Account</button>
        </div>
      </form>

      <h3>Active Accounts</h3>
      <div class="users-grid" id="users-wrap">
        <div style="color:#94a3b8; font-size:0.85rem;">Loading users...</div>
      </div>

      <div class="footer-icons">
        <span>Contact :</span>
        <div id="social-links" style="display:flex; gap:8px;"></div>
      </div>
    </div>
  </div>

<script>
document.getElementById('expire_date').value = new Date(Date.now() + 30*86400000).toISOString().split('T')[0];

async function fetchServer() {
  try {
    const res = await fetch('/api/server');
    const data = await res.json();
    document.getElementById('server-info').innerHTML = `<b>VPS IP:</b> ${data.ip} | <b>Panel Port:</b> ${data.panel_port} | <b>UDP Port:</b> ${data.udp_port} | <b>CPU:</b> ${data.cpu_percent}%`;
  } catch(e) {}
}

async function fetchSocial() {
  try {
    const res = await fetch('/api/social');
    const data = await res.json();
    const c = document.getElementById('social-links');
    c.innerHTML = '';
    const icons = data.icons || {};
    ['telegram', 'facebook', 'messenger'].forEach(k => {
      if(data[k]) {
        c.innerHTML += `<a href="${data[k]}" target="_blank"><img src="${icons[k]||''}" alt="${k}"></a>`;
      }
    });
  } catch(e) {}
}

async function fetchUsers() {
  try {
    const res = await fetch('/api/users');
    const data = await res.json();
    const wrap = document.getElementById('users-wrap');
    wrap.innerHTML = '';
    if(data.users.length === 0) {
      wrap.innerHTML = '<div style="color:#94a3b8; font-size:0.85rem;">No users created yet.</div>';
      return;
    }
    data.users.forEach(u => {
      wrap.innerHTML += `
        <div class="user-card">
          <div class="user-header">
            <div><span class="loader3d"></span><span>${u.username}</span></div>
            <span class="badge-port">PORT ${u.udp_port || '-'}</span>
          </div>
          <div class="field-row"><span>Password:</span><span class="field-val">${u.password}</span></div>
          <div class="field-row"><span>Day Left:</span><span class="field-val" style="color:#38bdf8;">${u.day_left} Days</span></div>
          <div class="field-row"><span>Expire Date:</span><span class="field-val">${u.expire_at}</span></div>
          <div class="field-row"><span>Status:</span><span class="field-val">${u.status}</span></div>
          <div style="margin-top:10px; text-align:right;">
            <button class="btn btn-danger" style="padding:4px 10px; font-size:0.75rem;" onclick="deleteUser(${u.id})">🗑 Delete</button>
          </div>
        </div>
      `;
    });
  } catch(e) {}
}

async function createUser(e) {
  e.preventDefault();
  const res = await fetch('/api/users', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      username: document.getElementById('username').value,
      password: document.getElementById('password').value,
      expire_date: document.getElementById('expire_date').value
    })
  });
  const data = await res.json();
  if(data.success) {
    alert('User created successfully!');
    document.getElementById('username').value = '';
    document.getElementById('password').value = '';
    fetchUsers();
  } else {
    alert(data.error || 'Failed to create user');
  }
}

async function deleteUser(id) {
  if(!confirm('Are you sure to delete this user?')) return;
  await fetch('/api/users/' + id, {method: 'DELETE'});
  fetchUsers();
}

fetchServer();
fetchSocial();
fetchUsers();
setInterval(fetchUsers, 5000);
</script>
</body>
</html>
EOF

########################################
# SYSTEMD SERVICE RESTART
########################################
echo
echo "[5/5] Restarting Services..."
systemctl daemon-reload
systemctl restart zivpn-admin.service

SERVER_IP=$(hostname -I | awk '{print $1}')

echo
echo -e "${PINK}========================================${NC}"
echo -e " ${PINK}${BOLD}ZIVPN Moonlight 3D Panel Installed${NC}"
echo -e "${PINK}----------------------------------------${NC}"
echo -e " ${PINK}VPS IP        :${NC} ${SERVER_IP}"
echo -e " ${PINK}Admin Panel   :${NC} http://${SERVER_IP}:8989"
echo -e " ${PINK}UDP Port      :${NC} 5667"
echo -e "${PINK}----------------------------------------${NC}"
echo -e " ${PINK}Admin USER    :${NC} ${ADMIN_USER}"
echo -e " ${PINK}Admin PASS    :${NC} ${ADMIN_PASS}"
echo -e " ${PINK}Script Owner By:${NC} JueHtet"
echo -e "${PINK}========================================${NC}"
