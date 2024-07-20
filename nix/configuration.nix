#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    system.stateVersion = "24.05"; ## The version of NixOS you are using.
    imports = [
        "./initializations.nix"
        "./hardware-configuration.nix" ## Run `nixos-generate-config` to update this file.

        "./packages/localization.nix"
        "./packages/time.nix"
        "./packages/networking.nix"
        "./packages/audio.nix"
        "./packages/printing.nix"
        "./packages/desktop.nix"
        "./packages.nix"

        "./startup/format.nix"
        "./startup/mounts.nix" ## Overrides `hardware-configuration.nix`.  Comment to not override.
        "./startup/boot.nix"

        "./shutdown/hibernate.nix"
        "./shutdown/restart.nix"

        "./units/antivirus.nix"
        "./units/defragment.nix"
        "./units/rotational-settings.nix"
        "./units/scrub.nix"
        "./units/snapshots.nix"
        "./units/swap.nix"

        "./users/miles.nix"
    ];
}
