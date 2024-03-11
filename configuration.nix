#!/usr/bin/nixos-rebuild
{config, pkgs, ...}:

{
  ## Upstream configurations
  imports = [
    ./hardware-configuration.nix ## Run `nixos-generate-config` to update this file.
  ];
}
