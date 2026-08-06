# Yong Zhi Tong — Engineering Portfolio

Masters student in Electrical and Electronic Engineering at Imperial College London (First Class Honours, Dean’s List). I work across power electronics, embedded systems, and software — from switch-mode supplies and PCB design to Python backends and firmware. Experience includes undergraduate teaching in digital/analogue circuits, an electrical engineering internship at Technip Energies, and team projects spanning hardware, control, and full-stack development.

**Contact:** yzt24@ic.ac.uk · London, UK

---

## Projects

### Watt’s Up — Smart Grid System
**Second Year Electronics Design Project · May–Jun 2026**

DC microgrid with PV, supercapacitor storage, grid import/export, and an LED load — built with a team of 7. My focus: circuit interconnect, schematics, and LED SMPS current control.

**[Demo video](./Smart%20Grid%20Full%20Demo.mp4)** · **[Project brief](./smart_grid_project_brief.pdf)** · **[Full write-up](https://amethyst-vanilla-e4a.notion.site/Watt-s-Up-Smart-Grid-Project-57cd290cf3a283dcb5bf8151f05f89b2)**

#### Full Circuit Setup

Circuit schematic and hardware connections across five SMPS modules on a shared 10 V bus.

<p align="center">
  <img src="./smart-grid/architecture.png" alt="System architecture" width="80%" />
</p>
<p align="center">
  <img src="./smart-grid/hardware-setup.png" alt="Lab hardware setup" width="80%" />
</p>

#### LED SMPS Control

Implemented a current controller to regulate LED current to the desired value. Power is commanded via \(I_{reg} = P / V_{led}\).

<p align="center">
  <img src="./smart-grid/led-schematic.png" alt="LED driver schematic" width="48%" />
  <img src="./smart-grid/led-load.png" alt="LED load hardware" width="48%" />
</p>

#### Power Monitoring UI

Interactive dashboard for real-time power and cost. Smart dispatch optimises operating cost via import/export.

<p align="center">
  <img src="./smart-grid/dashboard.png" alt="Power monitoring dashboard" width="80%" />
</p>

---

### ELECTRO Bootcamp
**Malaysia STEM Outreach Program · Jun 2026 – Present**

Electronics bootcamp built around a Wi-Fi–controlled ESP32 RC car for high-school delivery, within a £345 budget and 3-month timeline.

- PCB design linking ESP32 I/O to a motor driver and battery power management
- Buck SMPS (MP2322) for reliable 6 V → 5 V conversion
- ESP32 SoftAP hosting an HTML/JS driving UI for mobile control
- Tool-less chassis in Fusion 360 for fast kit assembly

Firmware: [`ELECTRO Bootcamp/electro_bootcamp.ino`](./ELECTRO%20Bootcamp/electro_bootcamp.ino)

---

### Remote-Controlled Signal Detecting Rover
**First Year Electronics Design Project · May–Jun 2025**

Remote-controlled rover (team of six) with analogue front-ends for infrared, radio, ultrasound, and magnetic sensing — filters, comparators, and coil characterisation for radio sensitivity — integrated with sensor and software teammates into a working system.

---

### Revizon
**Amazon University Engagement Program · Jul–Oct 2025**

Full-stack mobile app (team of 3) for A-Level exam practice: Python FastAPI backend/API and FlutterFlow frontend with exam-style question flows.

---

## Skills

| Area | Tools |
| --- | --- |
| Programming | Python, C++, SystemVerilog, MATLAB |
| Software & EDA | LTSpice, KiCad, DIALux, LabVIEW, Quartus Prime, FastAPI, FlutterFlow |
| Languages | English, Malay, Mandarin |
