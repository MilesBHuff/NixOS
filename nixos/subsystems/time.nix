#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    time.timeZone = "America/New_York";
    services.chrony.enable = true;
    #TODO: Figure out if we need `hwclock`;  if we do, ensure that its systemd services are enabled.
}
