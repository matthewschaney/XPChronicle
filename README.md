# AverageXPClassic
![License – GPL v3](https://raw.githubusercontent.com/matthewschaney/AverageXPClassic/main/gplv3-or-later.png)
  
[![Version](https://img.shields.io/badge/version-1.0.0-blue?style=flat-square)](https://github.com/<your‑org>/AverageXPClassic/releases/tag/v1.0.0)
[![WoW Classic 1.15.7](https://img.shields.io/badge/WoW%20Classic‑1.15.7-blue?style=flat-square)](https://worldofwarcraft.blizzard.com/)

A lightweight WoW Classic addon that tracks your experience gains and displays session and lifetime average XP/hour with a visual graph.

---

## Features
- **Session Tracking** – XP/hour for your current play session  
- **Lifetime Tracking** – Overall XP/hour across all sessions (per character)  
- **Visual Graph** – Hourly XP bars showing recent performance  
- **Draggable Interface** – Move the display anywhere on your screen  
- **Customizable** – Set 2‑24 hourly buckets

---

## Installation

### Manual
1. Download the latest release.
2. Extract the `AverageXPClassic` folder to your WoW Classic addons directory:  
   - **Windows** `World of Warcraft\_classic_\Interface\AddOns\`  
   - **macOS** `World of Warcraft/_classic_/Interface/AddOns/`
3. Restart WoW Classic or type `/reload` in‑game.

### CurseForge/Wago
Grab it on **[CurseForge](#)** or **[Wago](#)** for automatic updates.

---

## Usage

Logging in automatically starts tracking. The display shows:

- Current‑session XP/hour  
- Lifetime XP/hour (this character)  
- Graph of recent hourly performance  

### Slash Commands

| Command | Action |
|---------|--------|
| `/avgxp` | Show command list |
| `/avgxp reset` | Clear **all** tracking data |
| `/avgxp graph` | Toggle graph on/off |
| `/avgxp buckets <2‑24>` | Set number of hourly buckets |

### Interface Tips

* **Drag** – Left‑click and drag the window.  
* **Tooltip** – Hover bars for exact XP & timestamp.  
* **Position** – Saved per character.

---

## Compatibility

- **Classic Era** (Season of Discovery, Hardcore)  
- **Wrath Classic**  
- **Cataclysm Classic**

---

## Screenshots

*Add images of the display and graph here.*

---

## FAQ

**Q: Does this work on retail WoW?**  
A: No—Classic clients only.

**Q: Is data saved when I log out?**  
A: Yes, per‑character and persistent.

**Q: Can I reset just the session data?**  
A: Session resets on login; `/avgxp reset` clears everything.

---

## Support

Open issues or feature requests on the **GitHub repo**.

---

## License

Starting with **v1.0.0** (July 20 2025) this project is licensed under the  
**GNU General Public License v3.0 or later (GPL‑3.0‑or‑later)** – see the `LICENSE` file for full terms.

> **Note:** A private pre‑release commit briefly referenced the MIT License, but it was never downloaded or distributed. No public build was ever published under MIT, so the GPL‑3.0‑or‑later licence applies to *all* public versions.
