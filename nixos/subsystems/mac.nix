#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    security.apparmor.enable = true;
    security.apparmor.enableCache = false; ## Not super compatible with the Nix store.
    #TODO: Set all policies to complain... for now.
}
