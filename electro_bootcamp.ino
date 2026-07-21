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

// ---- Helpers ----
void applyDirection(Dir d) {
  currentDir = d;
  if (d == UP) {
    digitalWrite(AIN2, HIGH);
    digitalWrite(AIN1, LOW);
    digitalWrite(BIN2, LOW);
    digitalWrite(BIN1, HIGH);
  } else if (d == DOWN) {
    digitalWrite(AIN2, LOW);
    digitalWrite(AIN1, HIGH);A
    digitalWrite(BIN2, HIGH);
    digitalWrite(BIN1, LOW);
  } else if (d == LEFT) {
    digitalWrite(AIN2, HIGH);
    digitalWrite(AIN1, LOW);
    digitalWrite(BIN2, HIGH);
    digitalWrite(BIN1, LOW);
  } else if (d == RIGHT) {
    digitalWrite(AIN2, LOW);
    digitalWrite(AIN1, HIGH);
    digitalWrite(BIN2, LOW);
    digitalWrite(BIN1, HIGH);
  } else {
    // NONE: stop both sides
    digitalWrite(AIN2, LOW);
    digitalWrite(AIN1, LOW);
    digitalWrite(BIN2, LOW);
    digitalWrite(BIN1, LOW);
  }
}

const char PAGE_HTML[] PROGMEM = R"HTML(
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>ESP32 Arrow Control</title>
<style>
  :root { --btn: #1976d2; --btnH: #125a9d; --on: #43a047; --bg: #f7f7f7; }
  body { font-family: Arial, sans-serif; background: var(--bg); margin: 2rem; }
  h1 { font-size: 1.3rem; margin-bottom: .8rem; }
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
    touch-action: none; /* important for pointer events */
  }
  button:active { background: var(--btnH); }
  .active { background: var(--on) !important; }
  .center { text-align: center; margin-top: 1rem; color: #333; }
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

  let isHolding = false;

  async function sendDir(path) {
    try { await fetch('/' + path, { method: 'GET', cache: 'no-store' }); }
    catch (_) {}
    refresh();
  }

  function bindHold(id, path) {
    const el = document.getElementById(id);

    el.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      isHolding = true;
      try { el.setPointerCapture(e.pointerId); } catch (_) {}
      sendDir(path); // press -> set direction
    });

    // Release on the button
    el.addEventListener('pointerup', (e) => {
      e.preventDefault();
      if (isHolding) { isHolding = false; sendDir('none'); }
    });

    // If the press is canceled or pointer leaves while pressed, also send none
    el.addEventListener('pointercancel', () => { if (isHolding) { isHolding = false; sendDir('none'); } });
    el.addEventListener('pointerleave', (e) => {
      // If leaving while pressed, most browsers keep pressure > 0 briefly
      if (isHolding) { sendDir('none'); isHolding = false; }
    });

    // Prevent context menu on long-press
    el.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  // Global release (in case pointer is released outside the button)
  window.addEventListener('pointerup', () => { if (isHolding) { isHolding = false; sendDir('none'); } });
  window.addEventListener('pointercancel', () => { if (isHolding) { isHolding = false; sendDir('none'); } });

  bindHold('up','up');
  bindHold('down','down');
  bindHold('left','left');
  bindHold('right','right');

  // Ensure NONE at load
  sendDir('none');
  refresh();
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
// NEW: set NONE when no button is held
void handleNone()  { applyDirection(NONE);  server.send(200, "text/plain", "NONE"); }

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

  // Set initial PWM duty (adjust as needed)
  analogWrite(PWMA, 100);
  analogWrite(PWMB, 100);

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
  server.on("/none", HTTP_GET, handleNone); // for release = NONE
  server.onNotFound(handleNotFound);

  // ... your server.on(...) routes ...
  server.begin();
  Serial.println("HTTP server started.");
}

void loop() {
  server.handleClient();
}