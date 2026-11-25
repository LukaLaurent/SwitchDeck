# SwitchDeck

Created by **Luka LAURENT**.

Connect to your Cisco switches and push saved port templates in a few clicks.
Save a port configuration once, for example **Wifi-Hotspot** (trunk mode with VLAN 2), then deploy it on a range of
ports or one port at a time. SwitchDeck types the commands for you.

Made for Windows 11 and Cisco Catalyst switches running IOS or IOS XE.

## Start it

Download the repository (green **Code** button, then **Download ZIP**), unzip it anywhere, and double-click
**`SwitchDeck.cmd`**.

The first time, SwitchDeck offers to install itself on the PC (it copies itself to
`%LOCALAPPDATA%\Programs\SwitchDeck`, no admin rights needed) and to add a desktop and Start menu shortcut.
You can also run it straight from the downloaded folder.

SwitchDeck runs through Windows' own PowerShell (`app\SwitchDeck.ps1` contains the whole program), so it works
even on PCs where Smart App Control blocks unsigned `.exe` files. No console window appears.

## Switches

- Add a switch with a name, a connection type, its IP or hostname and port, a username and a password.
  The password is also used as the enable secret.
- Connection types: **SSH** (the OpenSSH client built into Windows), **serial console** (USB or RJ45 console cable)
  and **lab switch**, a simulated Catalyst to try SwitchDeck without real hardware.
- Each connection opens in its own tab with a terminal: copy on select, right-click paste, Tab completion,
  `?` help and Ctrl+Shift+6, like PuTTY.
- On the first connection, SwitchDeck asks whether to read the ports from the switch (`show interfaces status`)
  or let you type them, with ranges such as `Gi1/0/1-48, Te1/1/1-4`.
- Older switches that only offer old SSH algorithms are handled automatically.

## Templates

A template is a list of interface commands, for example:

```
description Wifi-Hotspot
switchport mode trunk
switchport trunk allowed vlan 2
spanning-tree portfast trunk
no shutdown
```

Values written as `{{vlan}}` are set once in the template. `{{port}}` is replaced by each port name.
A template can reset the port first with `default interface`.
Templates can be exported one by one or all together, and imported on another PC.

## Deploy

1. **Setup**: choose the switch and the template.
2. **Ports**: click the ports on the picture of the switch, or type a range.
3. **Results**: SwitchDeck connects, types the commands and shows every port in green or red.

Advanced options: **Range** uses `interface range` (5 ranges per command, as IOS allows), **One by one** opens each
port in turn so a problem on one port does not stop the others. **Save to startup config** runs `write memory`
at the end. **Commands** shows exactly what will be sent before you deploy.

## Settings

English or Français, Light, System or Dark theme, terminal colors and text size, deploy defaults, desktop and
Start menu shortcuts, and **Uninstall**. SwitchDeck also appears in Windows Settings, Apps, after an install.

## Files

- Switches, templates and settings: `data\`
- Logs: `logs\SwitchDeck.log`

Saved passwords are encrypted with a key stored in `data\key.bin`, so the `data` folder works from any PC,
for example on a network share. Keep that folder private.

## Command line

```
powershell -ExecutionPolicy Bypass -File app\SwitchDeck.ps1 [--exit] [--uninstall] [--selftest]
```

`--exit` closes a running SwitchDeck, `--uninstall` removes it from this PC, `--selftest` runs the built-in tests
against the lab switches.

## Build

```
powershell -ExecutionPolicy Bypass -File app\build.ps1
```

This uses the C# compiler built into Windows (.NET Framework 4.8), so no SDK is needed. Sources are in `app\src\`.
The build checks that everything compiles, then writes `app\SwitchDeck.ps1` and `SwitchDeck.cmd`.

## License

MIT, see [LICENSE](LICENSE). Fonts in `assets\fonts` are under the SIL Open Font License.
