#!/usr/bin/env nix eval -f
{config, pkgs, lib, ...}: {
    imports = [
        ./initializations.nix
        ./hardware-configuration.nix ## Run `nixos-generate-config` to update this file.
        ./format.nix
        ./mounts.nix ## Overrides `hardware-configuration.nix`.  Comment to not override.
        ./boot.nix
    ];
}
