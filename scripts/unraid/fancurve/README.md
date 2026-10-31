# fancurve

An Unraid plugin that sets the speed of one PWM fan header from two temperature curves:

- The CPU curve follows the CPU package temperature (`coretemp`, "Package id 0").
- The HDD curve follows the hottest spinning hard disk.

The fan gets the higher speed of the two. Without this plugin, the BIOS controls the fans from one chip sensor or holds them at a fixed speed. Hot disks do not make the fans faster.

## How it works

`src/scripts/fancurve run` is a bash loop. Each interval (10 s by default), it reads the two temperatures, calculates the speed, and writes it to `pwmN` of the fan chip.

- The HDD temperatures come from `/var/local/emhttp/disks.ini`. Unraid polls SMART every 30 s and writes `*` for a sleeping disk, so the plugin never wakes a disk. SSDs, NVMe drives, and the USB flash drive do not count.
- The fan speeds up at once. It slows down by 5% each interval.
- If the plugin cannot read a temperature, the fan goes to 100%.
- When the daemon stops, it puts the old mode and duty back on the header, so the BIOS fan control comes back.
- At boot, this plugin installs before the IT87 driver plugin. The daemon waits until the fan chip appears.
- The plugin finds the chip by its hwmon name (`CHIP="it8*"`), not by the `hwmonN` number, because that number can change between boots.

With the default settings, each curve gives 30% at its low temperature and 100% at its high temperature:

| Curve | 30% at | 100% at |
|---|---|---|
| CPU | 50 °C | 80 °C |
| HDD | 35 °C | 45 °C |

45 °C is also the "hot" warning level of Unraid for disks (`hot="45"`, `max="55"` in `dynamix.cfg`). Thus the fans are at full speed before Unraid warns.

## Status on unraid

The plugin is installed, and the saved settings still say Disabled. To control the case fans, it must drive `pwm3` (see [Fan channels](#fan-channels)). A trial on `pwm3` worked, but it ran from `/tmp`, so each reboot ends it. After a reboot, the BIOS holds the case fans at 90% again.

To keep `pwm3` across reboots, do one of these:

- In the webGUI, open Settings > Utilities > Fan Curve. Set "Fan header" to `pwm3` and "Fan control" to Enabled. Click Apply.
- Set `SERVICE="enable"` and `PWM="pwm3"` in `src/default.cfg`. Then run `just unraid fancurve-deploy`.

## Hardware (unraid)

### Board and chip

- Unraid 7.3.4, kernel `6.18.58-Unraid`, Intel Pentium Gold 8505. Until 2026-10-31: Unraid 7.2.5, kernel `6.12.85-Unraid`.
- The board has no brand. All DMI fields show "Default string". The BIOS is AMI 5.27 from 2024-05-15.
- The ACPI DSDT has an ITE Super I/O device (`ITE8`) and `IO3B = 0x0A30`. The PNP resources reserve `0xa30-0xa3f` for its hardware monitor.
- The chip is an ITE IT8613E. With the driver below, it shows as `it8613` (at `/sys/class/hwmon/hwmon3` on 2026-10-25, at `hwmon4` on 2026-10-31).
- The `it87` driver of the Unraid kernel does not support the IT8613E. Its chip list goes from IT8603E to IT8795E, without IT8613E.

### Driver

ich777's "ITE IT87 Driver" plugin (`it87-driver.plg`, version 2024.07.10) supplies the driver. It is a build of [frankcrawford/it87](https://github.com/frankcrawford/it87).

- The plugin downloads a prebuilt package for each Unraid kernel from its GitHub releases. For `6.18.58-Unraid`, the package is `it87-20261002-6.18.58-Unraid-1.txz`.
- It keeps the packages in `/boot/config/plugins/it87-driver/packages/<kernel>/`.
- It loads the driver with `modprobe it87 ignore_resource_conflict=1`.
- After an Unraid update, the plugin must download a package for the new kernel. Until the driver loads, fancurve waits and logs `waiting for pwm3 ...`.

### Fan channels

The chip has three PWM outputs and two fan speed inputs. There is no `pwm4` or `fan4`. Another IT8613E board uses `fan4` for the CPU fan, but this board does not.

| Channel | BIOS setting | Speed input | Header |
|---|---|---|---|
| `pwm2` | mode 2 (automatic), starts at 26/255 (10%) | `fan2`, about 118 RPM at idle | CPU_FAN |
| `pwm3` | mode 1 (manual), fixed 230/255 (90%) | `fan3`, about 1870 RPM at 90% (0 RPM until 2026-10-25) | The case fans |
| `pwm5` | mode 1 (manual), fixed 127/255 (50%) | none | Not known |

How each channel was identified:

- `pwm2`: a test set it to 100% for 10 s. `fan2` went from 257 RPM to 718 RPM and was still speeding up. Then `pwm2` went back to mode 2 and duty 26.
- `pwm3`: a trial with the plugin lowered it from 90% to 30-37%. The case fans became quieter. After the reboot, they were loud again. These results come from listening, because `fan3` had no speed signal then. On 2026-10-31, `fan3` reported a speed: 1864 RPM at 90% and 1128 RPM at 51%.
- `pwm5`: not tested.

The BIOS curve on `pwm2` follows the chip sensor `temp1`, not the CPU package sensor. Its points are 30 °C (hysteresis 27 °C), 35 °C, and 80 °C, with `pwm2_auto_start=26` and `pwm2_auto_slope=36`. This is why hot disks do not make the CPU_FAN faster. `pwm3` has no curve at all, so the case fans always run at 90%.

Other chip values:

- PWM frequency: 23437 Hz on all three channels.
- `temp1`: 33 °C at idle. `temp2`: 26 °C (thermal diode, type 3). `temp3`: -128 °C, so no sensor is connected.

### Driver behavior

- At duty 255, the driver shows `pwmN_enable` as 0 ("full speed"). The fan speed does not change. At the next interval, the daemon writes mode 1 again.
- The driver refuses a duty write while the channel is in automatic mode (mode 2). When the daemon stops, it therefore writes the old duty first and the old mode second.
- On another IT8613E board, the chip took back control of the CPU fan channel under Windows ([Last-Colossi/it8613-fan-control](https://github.com/Last-Colossi/it8613-fan-control)). This did not occur here. During a 2-hour trial, `pwm3` kept the duty that the plugin set.

### Disks

- `disks.ini` has one section per disk, with `rotational`, `transport`, and `temp`. If `rotational="1"`, `transport` is not `usb`, and `temp` is a number, the plugin counts the disk. It ignores all other disks.
- Since 2026-10-31, the server has 5 SATA hard disks: parity and disk1-disk4. The NVMe pools `cache` and `array_cache` do not count.
- The flash drive shows `rotational="1"`, so the `transport="usb"` filter is necessary.
- A slot with no disk shows `temp="*"`, the same as a sleeping disk.
- The spin-down delay is 15 minutes. When all disks sleep, only the CPU curve sets the speed.

### Trial on 2026-10-25

| Time | Event |
|---|---|
| 17:45 | `just unraid fancurve-deploy` installed the plugin. It stayed disabled. |
| 17:52 | Trial on `pwm3` started: hottest HDD 36 °C, duty 37% (94/255). The duty stayed there, and the log showed no errors. |
| 19:39 | The server shut down (`system halt`). |
| 19:41 | At shutdown, the daemon got SIGTERM and put `pwm3` back in mode 1. This was the first test of the release on real hardware. |
| 19:44 | The server started again. The plugin installed and stayed disabled, so the BIOS held `pwm3` at 90%. |
| 23:00 | Trial started again: hottest HDD 33 °C, duty 30%. |

### Trial on 2026-10-31

Unraid 7.3.4 on a new install. A parity build kept all disks busy.

| Time | Event |
|---|---|
| 20:41 | `just unraid fancurve-deploy` installed the plugin. It stayed disabled. |
| 20:41 | Trial on `pwm3` started: CPU 48 °C, hottest HDD 38 °C, duty 51% (130/255). In 32 s, `fan3` went from 1864 RPM to 1128 RPM. The fans became quiet. |

## Unraid notes

These facts about Unraid 7.2.5 decide how the plugin is built:

- `/boot` is vfat with `fmask=0177`, so no file on the flash drive is executable. The install script copies `src/` into RAM and runs `chmod`. It tests for the script with `-f`, not `-x`.
- `plugin install` does not overwrite a FILE that exists, unless its SHA256 or MD5 is different. For this reason, the install script copies `src/` itself.
- `plugin install` does not install the same version again without `forced`. The deploy recipe passes `forced`.
- If an install fails at boot, Unraid moves the .plg to `/boot/config/plugins-error`. When only the daemon start fails, the install script exits 0.
- At boot, Unraid installs the .plg files in alphabetical order. `fancurve.plg` comes before `it87-driver.plg`.
- In an INLINE script, write `&` as `&amp;` and `<` as `&lt;`.
- `update.php` writes the form values to `#file`. A relative path goes under `/boot/config/plugins/`. Then it runs `#command` with the `#arg` values. `#command` must be under `/usr/local/emhttp`.
- The Apply window shows only stdout. For this reason, `die` writes to stdout and to the syslog.
- `parse_plugin_cfg` reads `default.cfg` from the plugin folder in RAM, then `/boot/config/plugins/<plugin>/<plugin>.cfg` on top. The daemon reads the two files in the same order.
- `/tmp` and `/var/log` are in RAM. The syslog of the previous boot is in `/boot/logs/syslog-previous`.

## Setup

1. Install "ITE IT87 Driver" (by ich777) from Community Applications.
2. Run `just unraid fancurve-deploy`.
3. Run `just unraid fancurve-status`. Make sure that it shows `it8613` with `pwm2`, `pwm3`, and `pwm5`.
4. In the webGUI, open Settings > Utilities > Fan Curve.
5. Set "Fan header" to `pwm3` and "Fan control" to Enabled. Click Apply.

### Trial without saved settings

A trial uses a settings file in `/tmp`. The saved settings on the flash drive do not change, and a reboot ends the trial. On Unraid, run:

```bash
printf 'SERVICE="enable"\nPWM="pwm3"\n' >/tmp/fancurve-trial.cfg
CFG=/tmp/fancurve-trial.cfg /usr/local/emhttp/plugins/fancurve/scripts/fancurve start
```

To stop the trial, run `fancurve stop`. Apply in the webGUI also stops it and starts the daemon with the saved settings.

### Find the channel of a header

The files are in the hwmon folder of the chip, for example `/sys/class/hwmon/hwmon3/`.

1. Write down the mode and duty of the channel from `just unraid fancurve-status`.
2. Write `1` to `pwmN_enable`.
3. Write `255` to `pwmN`.
4. Watch `fanN_input` for 10 s. If the header has no speed signal, listen to the fans.
5. Write the old duty to `pwmN`.
6. Write the old mode to `pwmN_enable`.

Do the steps in this order, because the driver refuses a duty write in automatic mode.

## Open items

- Save `pwm3` and Enabled (see [Status on unraid](#status-on-unraid)).
- Do a reboot with the plugin enabled. Make sure that the syslog shows `took pwm3 on it8613` after the IT87 driver loads. Only the local test covers this wait.
- Listen to the fans at idle. The 30% minimum is the default and is not tuned yet.
- Find out what `pwm5` drives.
- The local test of the daemon (32 checks against a fake hwmon tree and `disks.ini`) ran from a scratch folder. It is not in the repo.

## Update or remove

- To update, change the files here and run `just unraid fancurve-deploy` again. If the version is the same, the recipe still installs the plugin again.
- To remove, use Plugins > Installed Plugins in the webGUI. The fan header goes back to BIOS control.

## Files

- `fancurve.plg`: the install and remove scripts. It copies `src/` from the flash drive into `/usr/local/emhttp/plugins/fancurve/`.
- `src/scripts/fancurve`: the daemon and its `start`, `stop`, `restart`, `status`, and `run` commands.
- `src/FanCurve.page`: the settings page. Apply writes `/boot/config/plugins/fancurve/fancurve.cfg` and restarts the daemon.
- `src/default.cfg`: the default settings.
- `just/unraid.just`: the `fancurve-deploy` and `fancurve-status` recipes.

On Unraid, the daemon writes `/var/run/fancurve.pid` and `/var/run/fancurve.status`, and it logs to the syslog with the tag `fancurve`.
