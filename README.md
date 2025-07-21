# AverageXPClassic

A lightweight WoW Classic addon that tracks your experience gains and displays session and lifetime average XP/hour with a visual graph.

## Features

- **Session Tracking**: Shows XP/hour for your current play session
- **Lifetime Tracking**: Displays overall XP/hour across all sessions (per character)
- **Visual Graph**: Hourly XP bars showing recent performance
- **Draggable Interface**: Move the display anywhere on your screen
- **Customizable**: Adjust the number of hourly buckets (2-24 hours)

## Installation

### Manual Installation
1. Download the latest release
2. Extract the `AverageXPClassic` folder to your WoW Classic addons directory:
   - **Windows**: `World of Warcraft\_classic_\Interface\AddOns\`
   - **Mac**: `World of Warcraft/_classic_/Interface/AddOns/`
3. Restart WoW Classic or type `/reload` in-game

### CurseForge/Wago
Available on [CurseForge](#) and [Wago](#) for automatic updates.

## Usage

The addon automatically starts tracking when you log in. A small display window will appear showing:
- Current session XP/hour
- Overall lifetime XP/hour (for this character)
- Visual graph of recent hourly performance

### Commands

- `/avgxp` - Show available commands
- `/avgxp reset` - Clear all tracking data
- `/avgxp graph` - Toggle the visual graph on/off
- `/avgxp buckets <2-24>` - Set number of hourly buckets to display

### Interface

- **Drag**: Left-click and drag to move the window
- **Tooltip**: Hover over graph bars to see exact XP and time
- **Position**: Your window position is saved per character

## Compatibility

- **Classic Era** (Season of Discovery, Hardcore)
- **Wrath Classic**
- **Cataclysm Classic**

## Screenshots

*Add screenshots here showing the addon in action*

## FAQ

**Q: Does this work on retail WoW?**
A: No, this is specifically designed for WoW Classic versions.

**Q: Is the data saved when I log out?**
A: Yes, all tracking data is saved per character and persists between sessions.

**Q: Can I reset just the session data?**
A: Currently `/avgxp reset` clears all data. Session data automatically resets when you log in.

## Support

- **Issues**: Report bugs on the Github page
- **Feature Requests**: Also use GitHub Issues with the enhancement label

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Changelog

### v1.0.0 - Initial Release - Jul 20, 2025
- Initial public release
- Session and lifetime XP tracking
- Visual hourly graph
- Draggable interface
- Configurable bucket count