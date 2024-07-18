#!/usr/bin/env nix eval -f
{config, pkgs, ...}: {
    imports = [
        ./hardware-configuration.nix ## Run `nixos-generate-config` to update this file.
        ./mounts.nix ## Overrides `hardware-configuration.nix`.  Comment to not override.
        ./boot.nix
    ];
}
