#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    security.apparmor.enable = false; ## Should not enable without profiles. NixOS provides none by default.
    security.apparmor.enableCache = false; ## Not super compatible with the Nix store.
    security.apparmor.killUnconfinedConfinables = true; ## Helps ensure that AppArmor is always enforced.
    #NOTE: Enforcement is configured per-policy.
}
