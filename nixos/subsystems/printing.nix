#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    services.printing.enable = true;
    environment.systemPackages = environment.systemPackages ++ [
        #TODO: Add chrony
    ];
    #TODO: Set up NTS
}
