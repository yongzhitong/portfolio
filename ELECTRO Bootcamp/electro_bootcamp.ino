#include <WiFi.h>
#include <WebServer.h>

// SoftAP credentials (ESP32 will broadcast this SSID)
const char* AP_SSID     = "ESP32-Controller"; // 1–32 chars
const char* AP_PASSWORD = "12345678";         // 8–63 chars (WPA2)

// ---- Direction pins (edit as needed) ----
const uint8_t AIN1 = 21;
const uint8_t AIN2 = 22;
const uint8_t BIN1 = 19;
const uint8_t BIN2 = 18;
const uint8_t PWMA = 23;
const uint8_t PWMB = 4;

// ---- Server ----
WebServer server(80);

// ---- Direction state ----
enum Dir { NONE = 0, UP = 1, DOWN = 2, LEFT = 3, RIGHT = 4 };
volatile Dir currentDir = NONE;

// ---- PWM state (0–255) ----
volatile uint8_t pwmA = 100;
volatile uint8_t pwmB = 100;

// ---- Helpers ----
void applyPWM() {
  analogWrite(PWMA, pwmA);
  analogWrite(PWMB, pwmB);
}

// Student-editable motor direction logic (must come after Dir + pin defs)
#include "apply_direction.h"

const char PAGE_HTML[] PROGMEM = R"HTML(
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>ESP32 Arrow Control</title>
<style>
  :root {
    --btn: #1976d2;
    --btnH: #125a9d;
    --on: #43a047;
    --bg: #f7f7f7;
    --track: #cfd8dc;
    --text: #333;
  }
  * { box-sizing: border-box; }
  body {
    font-family: Arial, Helvetica, sans-serif;
    background: var(--bg);
    margin: 2rem;
    color: var(--text);
  }
  h1 { font-size: 1.3rem; margin-bottom: .8rem; }
  h2 {
    font-size: 1rem;
    font-weight: 600;
    margin: 1.6rem 0 .6rem;
    color: var(--text);
  }
  .grid {
    display: grid;
    grid-template-columns: 80px 80px 80px;
    grid-template-rows: 80px 80px 80px;
    gap: 12px;
    align-items: center;
    justify-items: center;
    width: max-content;
  }
  button {
    width: 80px; height: 80px; font-size: 2rem;
    border: none; color: #fff; background: var(--btn);
    border-radius: 8px; cursor: pointer;
    box-shadow: 0 2px 6px rgba(0,0,0,.2);
    transition: background .15s ease;
    touch-action: none;
  }
  button:active { background: var(--btnH); }
  .active { background: var(--on) !important; }
  .center { text-align: center; margin-top: 1rem; color: var(--text); }

  .speed {
    max-width: 280px;
    margin-top: .2rem;
  }
  .speed-row {
    display: flex;
    flex-direction: column;
    gap: 6px;
    margin-bottom: 1rem;
    padding: 12px 14px;
    background: #fff;
    border-radius: 8px;
    box-shadow: 0 2px 6px rgba(0,0,0,.12);
  }
  .speed-label {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: .9rem;
    gap: 10px;
  }
  input[type="number"] {
    width: 64px;
    padding: 6px 8px;
    font-size: .95rem;
    font-weight: 700;
    font-family: inherit;
    font-variant-numeric: tabular-nums;
    color: var(--btn);
    text-align: right;
    border: 1px solid #b0bec5;
    border-radius: 8px;
    background: #fff;
    outline: none;
    box-shadow: 0 1px 3px rgba(0,0,0,.08);
    -moz-appearance: textfield;
  }
  input[type="number"]::-webkit-outer-spin-button,
  input[type="number"]::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }
  input[type="number"]:focus {
    border-color: var(--btn);
    box-shadow: 0 0 0 2px rgba(25, 118, 210, .2);
  }
  input[type="range"] {
    -webkit-appearance: none;
    appearance: none;
    width: 100%;
    height: 8px;
    border-radius: 4px;
    background: var(--track);
    outline: none;
    cursor: pointer;
  }
  input[type="range"]::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    width: 22px;
    height: 22px;
    border-radius: 50%;
    background: var(--btn);
    box-shadow: 0 2px 4px rgba(0,0,0,.25);
    cursor: pointer;
    border: none;
  }
  input[type="range"]::-moz-range-thumb {
    width: 22px;
    height: 22px;
    border-radius: 50%;
    background: var(--btn);
    box-shadow: 0 2px 4px rgba(0,0,0,.25);
    cursor: pointer;
    border: none;
  }
  input[type="range"]:active::-webkit-slider-thumb { background: var(--on); }
  input[type="range"]:active::-moz-range-thumb { background: var(--on); }
</style>
</head>
<body>
  <h1>ESP32 Arrow Control</h1>
  <div class="grid">
    <div></div>
    <button id="up"    aria-label="Up">▲</button>
    <div></div>

    <button id="left"  aria-label="Left">◀</button>
    <div></div>
    <button id="right" aria-label="Right">▶</button>

    <div></div>
    <button id="down"  aria-label="Down">▼</button>
    <div></div>
  </div>
  <div class="center">Active: <strong id="state">NONE</strong></div>

  <h2>Motor Speed (PWM)</h2>
  <div class="speed">
    <div class="speed-row">
      <div class="speed-label">
        <span>Motor A</span>
        <input type="number" id="pwmANum" min="0" max="255" value="100" inputmode="numeric" aria-label="Motor A PWM value"/>
      </div>
      <input type="range" id="pwmA" min="0" max="255" value="100" aria-label="Motor A PWM"/>
    </div>
    <div class="speed-row">
      <div class="speed-label">
        <span>Motor B</span>
        <input type="number" id="pwmBNum" min="0" max="255" value="100" inputmode="numeric" aria-label="Motor B PWM value"/>
      </div>
      <input type="range" id="pwmB" min="0" max="255" value="100" aria-label="Motor B PWM"/>
    </div>
  </div>

<script>
  async function refresh() {
    try {
      const s = await fetch('/dir', { cache: 'no-store' }).then(r => r.text());
      document.getElementById('state').textContent = s;
      ['up','down','left','right'].forEach(id => {
        const el = document.getElementById(id);
        el.classList.toggle('active', s.toLowerCase() === id);
      });
    } catch (_) {
      document.getElementById('state').textContent = 'DISCONNECTED';
      ['up','down','left','right'].forEach(id => {
        document.getElementById(id).classList.remove('active');
      });
    }
  }

  function clampPwm(v) {
    v = parseInt(v, 10);
    if (isNaN(v)) return 0;
    return Math.max(0, Math.min(255, v));
  }

  function setPwmUi(a, b) {
    document.getElementById('pwmA').value = a;
    document.getElementById('pwmB').value = b;
    document.getElementById('pwmANum').value = a;
    document.getElementById('pwmBNum').value = b;
  }

  async function refreshPwm() {
    try {
      const t = await fetch('/pwm', { cache: 'no-store' }).then(r => r.text());
      const parts = t.split(',');
      if (parts.length === 2) {
        setPwmUi(clampPwm(parts[0]), clampPwm(parts[1]));
      }
    } catch (_) {}
  }

  let isHolding = false;
  let pwmTimer = null;

  async function sendDir(path) {
    try { await fetch('/' + path, { method: 'GET', cache: 'no-store' }); }
    catch (_) {}
    refresh();
  }

  function sendPwm(a, b) {
    a = clampPwm(a);
    b = clampPwm(b);
    setPwmUi(a, b);
    clearTimeout(pwmTimer);
    pwmTimer = setTimeout(async () => {
      try {
        await fetch('/pwm?a=' + a + '&b=' + b, { method: 'GET', cache: 'no-store' });
      } catch (_) {}
    }, 40);
  }

  function onSliderInput() {
    sendPwm(document.getElementById('pwmA').value, document.getElementById('pwmB').value);
  }

  function onNumberInput() {
    const aEl = document.getElementById('pwmANum');
    const bEl = document.getElementById('pwmBNum');
    // Allow clearing while typing; apply on change/blur instead
    if (aEl.value === '' || bEl.value === '') return;
    sendPwm(aEl.value, bEl.value);
  }

  function onNumberCommit() {
    const a = clampPwm(document.getElementById('pwmANum').value);
    const b = clampPwm(document.getElementById('pwmBNum').value);
    sendPwm(a, b);
  }

  function bindHold(id, path) {
    const el = document.getElementById(id);

    el.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      isHolding = true;
      try { el.setPointerCapture(e.pointerId); } catch (_) {}
      sendDir(path);
    });

    el.addEventListener('pointerup', (e) => {
      e.preventDefault();
      if (isHolding) { isHolding = false; sendDir('none'); }
    });

    el.addEventListener('pointercancel', () => { if (isHolding) { isHolding = false; sendDir('none'); } });
    el.addEventListener('pointerleave', (e) => {
      if (isHolding) { sendDir('none'); isHolding = false; }
    });

    el.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  window.addEventListener('pointerup', () => { if (isHolding) { isHolding = false; sendDir('none'); } });
  window.addEventListener('pointercancel', () => { if (isHolding) { isHolding = false; sendDir('none'); } });

  bindHold('up','up');
  bindHold('down','down');
  bindHold('left','left');
  bindHold('right','right');

  document.getElementById('pwmA').addEventListener('input', onSliderInput);
  document.getElementById('pwmB').addEventListener('input', onSliderInput);

  ['pwmANum', 'pwmBNum'].forEach(id => {
    const el = document.getElementById(id);
    el.addEventListener('input', onNumberInput);
    el.addEventListener('change', onNumberCommit);
    el.addEventListener('blur', onNumberCommit);
    el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') { e.preventDefault(); onNumberCommit(); el.blur(); }
    });
  });

  sendDir('none');
  refresh();
  refreshPwm();
</script>
</body>
</html>
)HTML";

// ---- Handlers ----
void handleRoot() {
  server.send(200, "text/html", PAGE_HTML);
}
void handleDir() {
  const char* name = "NONE";
  switch (currentDir) {
    case UP: name = "UP"; break;
    case DOWN: name = "DOWN"; break;
    case LEFT: name = "LEFT"; break;
    case RIGHT: name = "RIGHT"; break;
    default: break;
  }
  server.send(200, "text/plain", name);
}
void handleUp()    { applyDirection(UP);    server.send(200, "text/plain", "UP"); }
void handleDown()  { applyDirection(DOWN);  server.send(200, "text/plain", "DOWN"); }
void handleLeft()  { applyDirection(LEFT);  server.send(200, "text/plain", "LEFT"); }
void handleRight() { applyDirection(RIGHT); server.send(200, "text/plain", "RIGHT"); }
void handleNone()  { applyDirection(NONE);  server.send(200, "text/plain", "NONE"); }

void handlePwm() {
  // GET /pwm           -> "a,b"
  // GET /pwm?a=N&b=M   -> set and return "a,b"
  bool changed = false;
  if (server.hasArg("a")) {
    int v = server.arg("a").toInt();
    if (v < 0) v = 0;
    if (v > 255) v = 255;
    pwmA = (uint8_t)v;
    changed = true;
  }
  if (server.hasArg("b")) {
    int v = server.arg("b").toInt();
    if (v < 0) v = 0;
    if (v > 255) v = 255;
    pwmB = (uint8_t)v;
    changed = true;
  }
  if (changed) applyPWM();

  char buf[16];
  snprintf(buf, sizeof(buf), "%u,%u", (unsigned)pwmA, (unsigned)pwmB);
  server.send(200, "text/plain", buf);
}

void handleNotFound() {
  server.send(404, "text/plain", "404 Not Found");
}

// ---- Setup / Loop ----
void setup() {
  pinMode(AIN1, OUTPUT);
  pinMode(AIN2, OUTPUT);
  pinMode(BIN1, OUTPUT);
  pinMode(BIN2, OUTPUT);
  pinMode(PWMA, OUTPUT);
  pinMode(PWMB, OUTPUT);

  // Start safe: all LOW (no movement)
  digitalWrite(AIN1, LOW);
  digitalWrite(AIN2, LOW);
  digitalWrite(BIN1, LOW);
  digitalWrite(BIN2, LOW);

  applyPWM();

  Serial.begin(115200);
  delay(100);

  // Start ESP32 as Access Point
  WiFi.mode(WIFI_AP);

  // Optional static IP for AP (default is 192.168.4.1 anyway)
  IPAddress local_IP(192, 168, 4, 1);
  IPAddress gateway(192, 168, 4, 1);
  IPAddress subnet(255, 255, 255, 0);
  WiFi.softAPConfig(local_IP, gateway, subnet);

  // Start AP on channel 6, visible SSID, up to 4 clients
  bool ap_ok = WiFi.softAP(AP_SSID, AP_PASSWORD, 6, 0, 4);
  Serial.print("AP started: "); Serial.println(ap_ok ? "yes" : "no");
  Serial.print("AP SSID: "); Serial.println(AP_SSID);
  Serial.print("AP IP: "); Serial.println(WiFi.softAPIP());

  server.on("/", HTTP_GET, handleRoot);
  server.on("/dir", HTTP_GET, handleDir);
  server.on("/up", HTTP_GET, handleUp);
  server.on("/down", HTTP_GET, handleDown);
  server.on("/left", HTTP_GET, handleLeft);
  server.on("/right", HTTP_GET, handleRight);
  server.on("/none", HTTP_GET, handleNone);
  server.on("/pwm", HTTP_GET, handlePwm);
  server.onNotFound(handleNotFound);

  server.begin();
  Serial.println("HTTP server started.");
}

void loop() {
  server.handleClient();
}
