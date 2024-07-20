#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    system.stateVersion = "24.05"; ## The version of NixOS you are using.
    imports = [
        "./initializations.nix"
        "./hardware-configuration.nix" ## Run `nixos-generate-config` to update this file.

        "./subsystems/localization.nix"
        "./subsystems/time.nix"
        "./subsystems/networking.nix"
        "./subsystems/audio.nix"
        "./subsystems/printing.nix"
        "./subsystems/desktop.nix"
        "./subsystems/packages.nix"

        "./startup/format.nix"
        "./startup/mounts.nix" ## Overrides `hardware-configuration.nix`.  Comment to not override.
        "./startup/boot.nix"

        "./users/miles.nix"

        "./actions/hibernate.nix"
        "./actions/restart.nix"

        "./units/antivirus.nix"
        "./units/defragment.nix"
        "./units/rotational-settings.nix"
        "./units/scrub.nix"
        "./units/snapshots.nix"
        "./units/swap.nix"
    ];
}
