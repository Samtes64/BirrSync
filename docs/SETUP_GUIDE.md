# BirrSync Gateway: Setup & Deployment Guide

This guide details how to set up, configure, and operate the complete BirrSync payment gateway ecosystem for Ethiopian mobile money (Telebirr and CBE Birr).

---

## 1. System Overview

```
                      +----------------------------------+
                      |   Merchant Dedicated Android     |
                      |  Phone with Telebirr / CBE SIM   |
                      +-----------------+----------------+
                                        |
                          Intercept SMS | Foreground Service
                          Verify Hash   | Local SQLite Queue
                                        v
                      +----------------------------------+
                      |          flutter (App)           |
                      +-----------------+----------------+
                                        |
                   HTTPS POST /ingest   | HMAC-SHA256 Signed
                   X-Gateway-Signature  | Anti-Replay skew <= 120s
                                        v
                      +----------------------------------+
                      |     BirrSync Server (Go binary)  |
                      |       (sub-millisecond latency)  |
                      +--------+----------------+--------+
                               |                |
                     Atomic    |                | Push Alerts
                   Claim Tx    |                | (Telegram Bot)
                               v                v
                      +----------------+   +-------------------+
                      | PostgreSQL DB  |   | Telegram Channel  |
                      +----------------+   +-------------------+
                               ^
                               | POST /v1/payments/verify
                               | (atomic SELECT FOR UPDATE)
                      +--------+-----------------------+
                      |  Your Applications / SaaS      |
                      |  (Mobile Apps, Web Subscriptions)|
                      +--------------------------------+
```

---

## 2. Server Deployment (Go + PostgreSQL)

### Option A: Quickstart with Docker Compose (Recommended)

1. Clone or copy the `BirrSync` repository to your Linux server (Ubuntu/Debian, VPS, AWS EC2, or DigitalOcean droplet):
   ```bash
   cd server
   ```

2. Configure environment variables in `.env` (or pass directly in `docker-compose.yml`):
   ```bash
   PORT=8080
   DATABASE_URL=postgres://postgres:password@postgres:5432/birrsync?sslmode=disable
   DEFAULT_GATEWAY_ID=gateway_agent_01
   DEFAULT_GATEWAY_SECRET=YOUR_SUPER_SECURE_HMAC_SECRET_KEY
   ALLOWED_TIME_SKEW_SECS=120
   TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrSTUvwxyz
   TELEGRAM_CHAT_ID=-1001234567890
   ```

3. Launch the stack:
   ```bash
   docker compose up -d --build
   ```

4. Verify health:
   ```bash
   curl http://localhost:8080/healthz
   ```
   Expected response:
   ```json
   {
     "status": "healthy",
     "service": "birrsync-gateway",
     "version": "2.0.0",
     "database": "connected",
     "timestamp": "2026-10-22T09:45:00Z"
   }
   ```

### Option B: Bare-Metal / Systemd Binary

1. Install Go 1.22+ and PostgreSQL 14+.
2. Build the stripped Go binary:
   ```bash
   cd server
   CGO_ENABLED=0 go build -ldflags="-w -s" -o /usr/local/bin/birrsync-server .
   ```
3. Create a systemd service file `/etc/systemd/system/birrsync.service`:
   ```ini
   [Unit]
   Description=BirrSync Gateway Engine
   After=network.target postgresql.service

   [Service]
   Type=simple
   User=www-data
   Restart=always
   RestartSec=5s
   Environment="PORT=8080"
   Environment="DATABASE_URL=postgres://birrsync_user:secure_pwd@127.0.0.1:5432/birrsync?sslmode=disable"
   Environment="DEFAULT_GATEWAY_ID=gateway_agent_01"
   Environment="DEFAULT_GATEWAY_SECRET=YOUR_SUPER_SECURE_HMAC_SECRET_KEY"
   ExecStart=/usr/local/bin/birrsync-server

   [Install]
   WantedBy=multi-user.target
   ```
4. Start and enable:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now birrsync
   ```

---

## 3. Flutter Gateway Agent Setup

1. Open `flutter` in your development environment.
2. Build the Android release APK:
   ```bash
   cd flutter
   flutter build apk --release
   ```
3. Transfer and install the APK (`build/app/outputs/flutter-apk/app-release.apk`) to your dedicated merchant phone.
4. Launch **BirrSync Agent** and grant all required permissions:
   - **SMS:** Required to read incoming 127 / CBE receipts.
   - **Notifications:** Required to maintain the persistent sticky foreground service.
   - **Battery Optimization Exemption:** Critical to prevent Android OEMs from killing the background listener (see `docs/OEM_BATTERY_GUIDE.md`).
5. Open the **Settings** screen in the agent:
   - **Server Base URL:** e.g., `https://gateway.yourdomain.com` (or LAN IP for local testing)
   - **Gateway ID:** `gateway_agent_01` (must match server configuration)
   - **Gateway Secret:** `YOUR_SUPER_SECURE_HMAC_SECRET_KEY`
6. Tap **"Test Connection"** to verify server connectivity and HMAC validation.
7. Tap **"Start Foreground Service"**. You will see the persistent low-priority notification: *"BirrSync Gateway Running - Waiting for incoming payment receipts..."*.

---

## 4. Setting Up Telegram Instant Alerts

1. Talk to `@BotFather` on Telegram and create a new bot using `/newbot`. Note the API Token.
2. Create a private channel or group for merchant notifications.
3. Add your bot as an Administrator to that channel.
4. Obtain the Chat ID (using `@userinfobot` or forwarding a message to `https://api.telegram.org/bot<TOKEN>/getUpdates`).
5. Set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` on your Go server.
6. Whenever an SMS arrives, an alert is delivered instantly:
   ```text
   🔔 TELEBIRR Payment Received
   💰 Amount: ETB 490.00
   👤 Sender: Abebe Kebede (2519****4819)
   🔖 Txn ID: DJD1R7KTJJ
   🕒 Time: 2026-10-22 12:45:00
   ```

---

## 5. Integrating Payment Verification in Client Apps

### Workflow

1. User in your app wants to purchase ETB 490.00 subscription.
2. Instruct the user:
   - Transfer ETB 490.00 to merchant Telebirr number: `0911XXXXXX`.
   - Deep link button: `<a href="telebirr://">Open Telebirr</a>`.
   - Ask user to enter their transaction code (e.g., `DJD1R7KTJJ`) OR their paying phone number (`0911223344`).
3. Your client app calls your backend, or queries BirrSync verify endpoint directly:

#### Method 1: Verification by Transaction ID (Exact Match)
```bash
curl -X POST https://gateway.yourdomain.com/v1/payments/verify \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_id": "DJD1R7KTJJ",
    "expected_amount": 490.00,
    "app_id": "com.myapp.android",
    "user_id": "usr_99812"
  }'
```

#### Method 2: Verification by Phone Number (Last 4 Digits Match)
```bash
curl -X POST https://gateway.yourdomain.com/v1/payments/verify \
  -H "Content-Type: application/json" \
  -d '{
    "sender_phone": "0911224819",
    "expected_amount": 490.00,
    "max_age_minutes": 15,
    "app_id": "com.myapp.android",
    "user_id": "usr_99812"
  }'
```

#### Successful JSON Response (HTTP 200)
```json
{
  "verified": true,
  "transaction_id": "DJD1R7KTJJ",
  "provider": "TELEBIRR",
  "amount": 490.00,
  "sender_name": "Abebe Kebede",
  "masked_phone": "2519****4819",
  "paid_at": "2026-10-22T09:40:12Z",
  "claimed_at": "2026-10-22T09:42:01Z"
}
```

*Note: Once claimed, the transaction status in the database is atomically locked to `CLAIMED` via `SELECT ... FOR UPDATE`, preventing any duplicate claims.*
