#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    time.timeZone = "America/New_York";
    services.chrony.enable = true;
    config = ''
## Servers (tried in order, not randomly; they should be ordered by ping, and the closest ones should have `prefer`.)
server virginia.time.system76.com nts iburst burst prefer
server     ohio.time.system76.com nts iburst burst
server   oregon.time.system76.com nts iburst burst

## Directories
dumpdir    /var/lib/chrony/dump/
logdir     /var/log/chrony/logs/
ntsdumpdir /var/lib/chrony/ntsdump/
ntskeydir  /var/lib/chrony/ntskeys/

## Files
driftfile   /var/lib/chrony/drift
# hwclockfile /etc/adjtime
ntsca       /etc/ssl/certs/ca-bundle.crt #NOTE: Differs by distro
rtcfile     /var/lib/chrony/rtc

## Serve time even if not synchronized to any NTP servers
allow

## Enable the monitoring command, allowing `chronyc tracking` & `chronyc sources` to work.
cmdallow all

## Save measurements and statistics on close
dumponexit

## Keep chronyd from swapping out of memory
lock_all

## What to log
# log all

## Allow the system clock to be stepped in the first four updates (which matches how many tries a burst does) if its offset is larger than 0.1 seconds (fast-enough that it shouldn't really be noticeable to users)
makestep 0.1 4

## Overwrite RTC only if it goes above a difference threshold.
rtcautotrim

## Timezones
rtconutc ## Whether the RTC is UTC (It should be unless you're dual-booting Windows, in which case you should tell Windows that RTC is UTC, and also disable time syncing in Windows.)
leapsectz right/UTC ## Make chrony use UTC for leap seconds.

## Attempt to account for various sources of delays
hwtimestamp * ## Delays in networking
tempcomp      ## Relationship between software clock errors and temperature sensors
    '';
    #TODO: Figure out if we need `hwclock`;  if we do, ensure that its systemd services are enabled.
}
