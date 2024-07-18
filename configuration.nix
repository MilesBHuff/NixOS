#!/usr/bin/env nix eval -f
{config, pkgs, ...}: {
    imports = [
        ./hardware-configuration.nix ## Run `nixos-generate-config` to update this file.
        ./mounts/pc.nix ## Overrides `hardware-configuration.nix`.  Comment to not override.  Otherwise, choose the `mounts/*.nix` file pertaining to your use-case.
        ./boot.nix
    ];
}
