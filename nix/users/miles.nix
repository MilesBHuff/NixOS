#!/usr/bin/env nix eval -f
#NOTE: You need to manually set a password for this user with `passwd`.
{config, pkgs, lib, var, ...}: {
    users.users.miles = {
        description = "Miles B Huff";
        isNormalUser = true;
        extraGroups = [
            "wheel"
            "networkmanager"
        ];
        packages = {};
    };
    services.displayManager.autologin = {
        enable = true;
        user = miles;
    };
}
