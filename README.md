# levelplay-hud-linux

Linux driver for the pump display on the **Levelplay Combat Liquid 360 HUD**
AIO cooler. CyberPowerPC prebuilts list it as a "LEVELPLAY HUD 360MM ARGB 2.6"
DIGITAL DISPLAY AIO LIQUID CPU COOLING SYSTEM".

On Windows the round 2.6" display shows CPU temperature, power, clock and load,
fed by Levelplay's "Combat HUD" driver. On Linux nothing drives it, so it stays
dark. This is a small Python service that drives it instead.

The USB device looks like this in `lsusb`:

```
ID 0145:1001 Unknown USB Display
```

with manufacturer string `HWCX` and product string `USB Display`.

## What it shows

| Display field | Source on Linux |
|---|---|
| CPU temperature | `k10temp` Tctl (AMD), `zenpower`, or `coretemp` package (Intel) |
| CPU power (W) | RAPL package energy counter (`/sys/class/powercap/intel-rapl:0`) |
| CPU clock (MHz) | highest current core frequency (cpufreq) |
| CPU load (%) | `/proc/stat` |

The display updates every 2 seconds by default. Temperature and clock are
averaged over 4 samples, and load and power cover the whole 2 seconds. The
Windows driver updates twice a second, which is a lot of flicker for something
in the corner of your eye. Set `HUD_INTERVAL` in the service file to change it.

The temperature's tenths digit comes from the display firmware: the host only
sends whole degrees, on Windows too.

## Install

Requires Python 3 and systemd. There are no other dependencies.

```sh
git clone https://github.com/slogonomo/levelplay-hud-linux
cd levelplay-hud-linux
sudo ./install.sh
```

This installs `/usr/local/bin/levelplay-hud` and
`/etc/systemd/system/levelplay-hud.service` and starts the service. It runs as
root because the RAPL power counter is root-only on current kernels. The
service finds the display by USB ID and reconnects after unplugs and
suspend/resume.

Check that it found the display:

```sh
systemctl status levelplay-hud    # look for "connected to /dev/hidrawN"
```

Remove it:

```sh
sudo ./install.sh uninstall
```

## Tested on

- Levelplay Combat Liquid 360 HUD, in a CyberPowerPC prebuilt
- Arch Linux (Omarchy), kernel 7.2, AMD Ryzen 9 9900X3D, MSI PRO B850-P WIFI

Other displays from the same vendor family probably speak the same protocol
but use other USB IDs (see [PROTOCOL.md](PROTOCOL.md)). If you have one, try
changing `VID_PID` at the top of `levelplay-hud`. Issues and reports are
welcome.

## How it works

[PROTOCOL.md](PROTOCOL.md) documents the USB protocol: a checksummed handshake,
then a fixed-layout status packet. It was worked out from the behaviour of
Levelplay's Windows driver (Combat-HUD-Driver V2.6) for interoperability. This
repository contains no Levelplay or HWCX code.

## License

MIT. See [LICENSE](LICENSE).

Not affiliated with Levelplay, HWCX or CyberPowerPC.
