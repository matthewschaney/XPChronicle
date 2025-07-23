# XPChronicle
[![Version](https://img.shields.io/github/v/release/matthewschaney/XPChronicle?label=latest&style=flat-square)](https://github.com/matthewschaney/XPChronicle/releases)
[![Source on GitHub](https://img.shields.io/badge/source-github-black?logo=github&style=flat-square)](https://github.com/matthewschaney/XPChronicle)

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
2. Extract the `XPChronicle` folder to your WoW Classic addons directory:  
   - **Windows** `World of Warcraft\_classic_\Interface\AddOns\`  
   - **macOS** `World of Warcraft/_classic_/Interface/AddOns/`
3. Restart WoW Classic or type `/reload` in‑game.

### CurseForge / Wago
Grab it on **[CurseForge](https://www.curseforge.com/wow/addons/xpchronicle)** or **[Wago](https://addons.wago.io/addons/xpchronicle)** for automatic updates.

---

## Usage

Logging in automatically starts tracking. The display shows:

- Current‑session XP/hour  
- Lifetime XP/hour (this character)  
- Graph of recent hourly performance  

### Slash Commands

| Command                             | Action                            |
|-------------------------------------|-----------------------------------|
| `/xpchronicle` **or** `/xpchron`    | Show command list                 |
| `/xpchronicle reset`                | Clear **all** tracking data       |
| `/xpchronicle graph`                | Toggle graph on/off               |
| `/xpchronicle minimap`              | Toggle minimap button             |
| `/xpchronicle buckets <2‑24>`       | Set number of hourly buckets      |

### Interface Tips

* **Drag** – Left‑click and drag the window.  
* **Tooltip** – Hover bars for exact XP & timestamp.  
* **Position** – Saved per character.

---

## Compatibility

All versions of WoW.

---

## Screenshots
Additional in‑game screenshots are available in the CurseForge gallery.

---

## FAQ

**Q: Does this work on retail WoW?**  
A: Yes, this addon runs on all versions of WoW.

**Q: Is data saved when I log out?**  
A: Yes, per‑character and persistent.

**Q: Can I reset just the session data?**  
A: Session resets on login; `/xpchron reset` clears everything.

---

## Support

Found a bug or have a feature request? Open an issue on the **[GitHub repository](https://github.com/matthewschaney/XPChronicle/issues)**.

---

## License

Starting with **v1.0.0** (July 20 2025) this project is licensed under the  
**GNU General Public License v3.0 or later (GPL‑3.0‑or‑later)** – see the `LICENSE` file for full terms.

> **Note:** A private pre‑release commit briefly referenced the MIT License, but it was never downloaded or distributed. No public build was ever published under MIT, so the GPL‑3.0‑or‑later licence applies to *all* public versions.

