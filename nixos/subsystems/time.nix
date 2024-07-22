#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    time.timeZone = "America/New_York";
    services.chrony.enable = true;
    #TODO: Disable RTC-related settings in Chrony if the system lacks an RTC (like Raspberry Pi 4s)
    #TODO: Create directories needed by `/etc/chrony/chrony.conf`.
    #TODO: Figure out if we need `hwclock`;  if we do, ensure that its systemd services are enabled.
}
