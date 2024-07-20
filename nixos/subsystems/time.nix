#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    time.timeZone = "America/New_York";
    environment.systemPackages = environment.systemPackages ++ [
        #TODO: Add chrony
    ];
    #TODO: Set up NTS
}
