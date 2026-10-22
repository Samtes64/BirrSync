# Android OEM Battery Optimization Bypass Guide

In Ethiopia, many merchant gateway phones are manufactured by **Transsion (Tecno, Infinix, itel)**, **Samsung**, or **Xiaomi**. These manufacturers include aggressive proprietary background task killers that can terminate background SMS listeners after the screen is turned off for several minutes.

Follow this checklist to guarantee 24/7/365 continuous operation of BirrSync Gateway.

---

## 1. General Android Guidelines (All Devices)

1. **Disable Battery Optimization:**
   - Go to **Settings** $\rightarrow$ **Apps** $\rightarrow$ **BirrSync Agent** $\rightarrow$ **Battery**.
   - Change from *Optimized* or *Restricted* to **Unrestricted** (Don't optimize).

2. **Allow Background Data Usage:**
   - Go to **Settings** $\rightarrow$ **Apps** $\rightarrow$ **BirrSync Agent** $\rightarrow$ **Mobile Data & Wi-Fi**.
   - Enable **Background data**.
   - Enable **Unrestricted data usage** (allows sync even during Data Saver mode).

3. **Lock App in Recent Apps (App Pinning):**
   - Open BirrSync Agent.
   - Open Android Recent Apps / Multitasking overview.
   - Long press or tap the BirrSync app icon $\rightarrow$ Tap the **Lock** icon. This prevents "Clear All" from killing the process.

---

## 2. Transsion Devices (Tecno / Infinix / itel: HiOS & XOS)

Tecno and Infinix run **Phone Master / Power Marathon**, which aggressively freezes apps.

1. **Phone Master / Auto-Start Permission:**
   - Open the **Phone Master** app pre-installed on the device.
   - Go to **Toolbox** $\rightarrow$ **Auto-start management**.
   - Find **BirrSync Agent** and toggle it **ON**.

2. **Power Marathon / Battery Lab:**
   - Go to **Settings** $\rightarrow$ **Battery Lab** (or **Power Marathon**).
   - Tap **Advanced Settings** $\rightarrow$ **Battery Saver**.
   - Ensure Battery Saver is **OFF**.
   - Tap **Screen off sleep** $\rightarrow$ Turn **OFF** (prevent turning off Wi-Fi/mobile data when screen sleeps).

3. **App Freeze Protection:**
   - If Tecno **Freezer** app is active, ensure BirrSync Agent is **NOT** added to the Freezer.

---

## 3. Xiaomi / Redmi / POCO (MIUI & HyperOS)

1. **AutoStart Permission:**
   - Go to **Settings** $\rightarrow$ **Apps** $\rightarrow$ **Permissions** $\rightarrow$ **Autostart**.
   - Toggle **BirrSync Agent** to **ON**.

2. **Battery Saver Settings:**
   - Go to **Settings** $\rightarrow$ **Apps** $\rightarrow$ **Manage Apps** $\rightarrow$ **BirrSync Agent**.
   - Tap **Battery Saver** $\rightarrow$ Select **No restrictions**.

3. **Security App Optimization:**
   - Open **Security** app $\rightarrow$ Tap **Gear icon (Settings)** in top right.
   - Under **Boost Speed** $\rightarrow$ Tap **Lock apps** $\rightarrow$ Toggle **BirrSync Agent** **ON**.

---

## 4. Samsung (One UI)

1. **Never Sleeping Apps:**
   - Go to **Settings** $\rightarrow$ **Battery and device care** $\rightarrow$ **Battery**.
   - Tap **Background usage limits**.
   - Tap **Never sleeping apps**.
   - Tap **+** and add **BirrSync Agent**.

2. **Disable Adaptive Battery:**
   - Under **Battery settings** $\rightarrow$ **More battery settings**.
   - Turn **Adaptive battery** **OFF** (prevents Android from guessing when to idle the phone).

3. **Remove from Auto Optimization:**
   - Under **Device care** $\rightarrow$ **Auto optimization** $\rightarrow$ Turn **OFF** "Restart when needed".

---

## 5. Verification Checklist

After applying the above settings:
1. Lock the merchant phone screen.
2. Send a 1 ETB test Telebirr transfer from another phone.
3. Observe whether:
   - The Go server receives `POST /v1/gateway/ingest` within 2 seconds.
   - The Telegram alert fires immediately.
4. If sync is delayed until you unlock the screen, double-check **Background Data** and **Unrestricted Battery** permissions.
