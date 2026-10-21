# Levelplay HUD display protocol (HWCX 0145:1001)

These notes come from studying Levelplay's Windows driver, Combat-HUD-Driver
V2.6. That driver is a .NET service plus a native `TempComm.dll` (HWCX,
v1.1.0.3) that does the USB I/O. Each item below is marked as **tested** (seen
working on real hardware with this project) or **vendor code** (what the
Windows driver does, not independently checked).

## Device

- USB `0145:1001`, manufacturer `HWCX`, product `USB Display`, bcdDevice 1.00
- One HID interface: interrupt IN EP 0x81 and interrupt OUT EP 0x03, both 64
  bytes, 1 ms interval
- Report descriptor (31 bytes): one 64-byte input report and one 64-byte
  output report, no report IDs

```
05 01 09 00 a1 01 15 00 25 ff 19 01 29 08 95 40
75 08 81 02 19 01 29 08 95 40 75 08 91 02 c0
```

- The device sends nothing unless the host writes to it.

## Framing

Offsets below are into a **65-byte buffer whose byte 0 is the report ID
(0x00)**. That is what Windows `WriteFile` sends, and on Linux you write the
same 65 bytes to `/dev/hidrawN`. Reads on Linux return 64 bytes without the
report ID, so prepend a 0x00 to keep the same offsets.

## Handshake (cmd 0x01): tested

The Windows driver sends this when the device appears, and only sends data
after a valid reply.

1. Fill all 65 bytes with random values.
2. Set `buf[0..4] = 00 01 00 00 00`.
3. Pick a random 16-bit `k` and store it big-endian in `buf[5..6]`.
4. Store this big-endian in `buf[11..12]`:
   `k ^ ((((buf[7] + buf[9]) << 8) + buf[8] + buf[10]) & 0xFFFF)`
5. `buf[63] = XOR over i = 0..59 of (i * buf[1 + i]) & 0xFF`
6. `buf[64] = (sum over i = 0..62 of i * buf[1 + i]) & 0xFF`

Then read one 64-byte report and prepend 0x00 to get `resp`. The reply is valid
if all of these hold:

- `resp[5..6]` (big-endian) == `((buf[9] << 8) | buf[10]) ^ ((((buf[5] + buf[7]) << 8) + buf[8] + buf[6]) & 0xFFFF)`
- `resp[63]` and `resp[64]` pass the same two checksums as above, computed
  over `resp`

The display passes all three checks every time. Whether the firmware refuses
data packets without a handshake is untested. A related Xigmatek project skips
it for this vendor ID.

## Status packet (cmd 0x02)

Zero the buffer, then fill in the fields. Multi-byte values are big-endian.
There is no checksum. The Windows driver sends one every 500 ms. This project
sends one every 2 s, and the display stays lit.

| Offset | Field | Status |
|---|---|---|
| 0 | 0x00 (report ID) | tested |
| 1 | 0x02 (command) | tested |
| 2 | CPU temperature, whole °C | tested (the display adds its own tenths digit) |
| 3 | GPU temperature, °C | vendor code |
| 4, 5, 6 | hour, minute, second | vendor code |
| 7 | milliseconds / 10 | vendor code |
| 8, 9 | year / 100, year % 100 (e.g. 20, 26) | vendor code |
| 10, 11 | month, day | vendor code |
| 12 | day of week, Sunday = 0 | vendor code |
| 13 | CPU load, % | tested |
| 14-15 | CPU clock, MHz | tested |
| 16 | GPU load, % | vendor code |
| 17-18 | GPU clock, MHz | vendor code |
| 19 | 0 | vendor code |
| 20 | memory used, % | vendor code (not shown on this model) |
| 21-22 | 0 | vendor code |
| 23 | 0 | vendor code |
| 24 | disk load, % | vendor code |
| 25-26 | CPU fan, RPM | vendor code |
| 27, 28 | CPU voltage: whole volts, hundredths | vendor code |
| 29-30 | CPU package power, W × 10 | tested |
| 31-32 | GPU fan, RPM | vendor code |
| 33-34 | GPU voltage | vendor code |
| 35-36 | GPU power | vendor code |
| 37-40 | 0 | vendor code |
| 41-44 | network upload, u32 | vendor code |
| 45-48 | network download, u32 | vendor code |
| 49 | display mode (the service always sends 0) | tested: 0x00-0x04 and 0x80-0x83 change nothing on the Levelplay HUD |
| 50-64 | 0 | |

The Levelplay HUD shows CPU temperature, power, clock and load, plus a bar
meter and an arc gauge driven from those values. The other fields are sent by
the shared vendor code and may be used by sibling products.

The DLL's `SetDisplayMode(a, mode)` export stores `mode` in byte 49, setting
bit 7 when `a` is 0. The Levelplay service never calls it, and the CyberPower
logo and the layout stayed the same with every value tried. The byte is
probably meant for sibling products.

On a failed write the vendor code reopens the device and retries, up to 15
times with 20 ms between tries.

## Related devices

The same vendor code serves several brands and picks the USB ID by service
name. These devices probably use the same or a similar protocol. Only
0145:1001 is tested.

| Vendor service name | USB ID(s) |
|---|---|
| SystemTemperatureMonitoring (Levelplay HUD) | 0145:1001 |
| LK Digital Display (Xigmatek LK 360 Digital) | 0145:1005 |
| XKWHardwareServices | 12b7:1001 |
| SLAYERCPULiveTemperature | 2c65:1001 |
| RM-Hardware | 2c65:1000 |
| ZALMAN-CTM | 1c57:3ed1, 1c57:4b8f, 1c57:3a7f |
| ZALMAN-TDM | 1c57:3ed2, 1c57:3ed6 |

For the Xigmatek variant, see the C# project
[NovaFemme/LK-360-Digital-AIO-Display](https://github.com/NovaFemme/LK-360-Digital-AIO-Display).
