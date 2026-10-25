# fancurve

An Unraid plugin that sets the speed of one PWM fan header from two temperature curves:

- The CPU curve follows the CPU package temperature (`coretemp`, "Package id 0").
- The HDD curve follows the hottest spinning hard disk.

The fan gets the higher speed of the two. Without this plugin, the BIOS controls the CPU_FAN header from the CPU temperature only, so hot disks do not make the fans faster.

## How it works

`src/scripts/fancurve run` is a bash loop. Each interval (10 s by default), it reads the two temperatures, calculates the speed, and writes it to `pwmN` of the fan chip.

- The HDD temperatures come from `/var/local/emhttp/disks.ini`. Unraid polls SMART every 30 s and writes `*` for a sleeping disk, so the plugin never wakes a disk. SSDs, NVMe drives, and the USB flash drive do not count.
- The fan speeds up at once. It slows down by 5% each interval.
- If the plugin cannot read a temperature, the fan goes to 100%.
- When the daemon stops, it puts the old mode and duty back on the header, so the BIOS fan control comes back.
- At boot, this plugin installs before the IT87 driver plugin. The daemon waits until the fan chip appears.

## Hardware (jadee-server)

The board is an unbranded Pentium Gold 8505 NAS board (DMI shows "Default string"). The ACPI tables show an ITE Super I/O with its hardware monitor at `0xa30`. This board type usually has an IT8613E. The kernel `it87` driver does not support the IT8613E, so the board needs the out-of-tree driver.

The PWM channel of the CPU_FAN header is not known yet. On other IT8613E boards, `fan4`/`pwm4` is the CPU fan and `fan2`/`fan3` are case fans.

## Setup

1. Install "ITE IT87 Driver" (by ich777) from Community Applications. It downloads a prebuilt driver for the running Unraid kernel.
2. Run `just unraid fancurve-deploy`.
3. Run `just unraid fancurve-status`. Make sure that it shows a fan chip, for example `it8613`, with `pwm` and `fan` entries.
4. To find the channel of the CPU_FAN header, run `pwmconfig` on Unraid. It stops each PWM output for a short time and shows which fan reacts. Do not let it write `/etc/fancontrol`.
5. In the webGUI, open Settings > Utilities > Fan Curve. Select the fan header, set "Fan control" to Enabled, and click Apply.

## Update or remove

- To update, change the files here and run `just unraid fancurve-deploy` again. The recipe installs the plugin again, also when the version is the same.
- To remove, use Plugins > Installed Plugins in the webGUI. The fan header goes back to BIOS control.

## Files

- `fancurve.plg`: the install and remove scripts. It copies `src/` from the flash drive into `/usr/local/emhttp/plugins/fancurve/`.
- `src/scripts/fancurve`: the daemon and its `start`, `stop`, `restart`, and `status` commands.
- `src/FanCurve.page`: the settings page. Apply writes `/boot/config/plugins/fancurve/fancurve.cfg` and restarts the daemon.
- `src/default.cfg`: the default settings.
