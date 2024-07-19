#!/usr/bin/env nix eval -f
{config, pkgs, lib, ...}: {
    imports = [
        ./initializations.nix
        ./hardware-configuration.nix ## Run `nixos-generate-config` to update this file.
        ./packages.nix

        ./startup/format.nix
        ./startup/mounts.nix ## Overrides `hardware-configuration.nix`.  Comment to not override.
        ./startup/boot.nix

        ./shutdown/hibernate.nix
        ./shutdown/restart.nix

        ./services/antivirus.nix
        ./services/defragment.nix
        ./services/rotational-settings.nix
        ./services/scrub.nix
        ./services/snapshots.nix
        ./services/swap.nix
    ];
}
