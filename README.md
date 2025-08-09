# XPChronicle
[![Version](https://img.shields.io/github/v/release/matthewschaney/XPChronicle?label=latest&style=flat-square)](https://github.com/matthewschaney/XPChronicle/releases)
[![Source on GitHub](https://img.shields.io/badge/source-github-black?logo=github&style=flat-square)](https://github.com/matthewschaney/XPChronicle)

A lightweight WoW addon (Classic, Wrath, Retail, Season of Discovery, etc.)
that tracks your experience gains and shows real‑time XP/hour together with
a fully‑customisable bar graph.

---

## Key Features
| | |
|---|---|
| **Session & Lifetime stats** | Instant XP/hour for the current session **and** all time (per‑character). |
| **Leveling Report** | A report showing leveling statistics.
| **Hourly Graph** | 2‑24 rolling “buckets” with tool‑tips and optional prediction bars. |
| **Prediction Mode** | Forecast how long to level and overlay predicted XP bars. |
| **History Window** | Scrollable log by event / hour / day with one‑click export. |
| **Options Panel** | In‑game panel (minimap → Right‑click) for colours, locks, visibility, grid‑snap, resets, more. |
| **Colour Pickers** | Separate colours for history and prediction bars – live preview. |
| **Drag‑anywhere UI** | Frames remember position, lockable via right‑click or panel. |
| **Minimap Button** | Left‑click = History, Right‑click = Options (can be hidden or locked). |
| **Zero Setup** | Log in and play – everything is recorded automatically. |

---

## Installation

<details>
<summary><strong>Manual</strong></summary>

1. Download the latest ZIP from the releases page.  
2. Extract **`XPChronicle`** to your AddOns directory:  
   • **Windows** `World of Warcraft\_classic_\Interface\AddOns\`  
   • **macOS / Linux** `World of Warcraft/_classic_/Interface/AddOns/`  
3. `/reload` or restart the game.
</details>

<details>
<summary><strong>CurseForge / Wago</strong></summary>

Search **XPChronicle** on either site and install for automatic updates.
</details>

---

## How to Use

### Heads‑up Display
* **Top line** – Session XP/hour and ETA to level  
* **Bar graph** – Recent hourly XP (blue) or future prediction (red)  
* **Hover** a bar for exact XP and timestamp

### Minimap Button
| Action | Result |
|--------|--------|
| **Drag** | Re‑position the button |
| **Left‑click** | Toggle History frame |
| **Right‑click** | Open Options panel |

### Slash Commands
| Command | What it does |
|---------|--------------|
| `/xpchron` *or* `/xpchronicle` | Show command list |
| `/xpchron options` | Open Options panel |
| `/xpchron history` | Toggle History frame |
| `/xpchron graph` | Toggle bar graph |
| `/xpchron minimap` | Show / hide minimap button |
| `/xpchron buckets <2‑24>` | Set number of graph buckets |
| `/xpchron reset` | **Full** data wipe (all chars) |

> **Tip:** Session data clears on logout; lifetime data persists.

---

## Compatibility
* Works on **Retail**, **Classic Era**, **Wrath‑Classic**, **Cataclysm‑Classic**
  and **Season of Discovery**.  
* Localised dates / times – no external libraries required.

---

## Screenshots
See the CurseForge or Wago  gallery for the latest UI shots, including Prediction Mode and the Options panel.

---

## FAQ
<details>
<summary>Does it support rested XP?</summary>

Yes. Rested XP is counted the same as normal XP – it still represents time
saved, so it belongs in the rate.
</details>

<details>
<summary>Can I reset only the current session?</summary>

Yes – click **Session Reset** in the Options panel (or just relog).
</details>

<details>
<summary>Why are my bars “snapped” to odd hours?</summary>

Use **Timelock** in the Options panel to align bucket edges to any minute of
the hour (e.g., :00).
</details>

---

## Support & Contributions
* **Bugs / ideas** – open an issue on
  [GitHub Issues](https://github.com/matthewschaney/XPChronicle/issues).
* **Pull Requests** are welcome – follow the existing Lua style
  (79‑char width, comment rulers).

---

## License
XPChronicle is released under the
[GNU GPL v3.0‑or‑later](https://www.gnu.org/licenses/gpl-3.0.html).  
See the bundled `LICENSE.md` file for full terms.
