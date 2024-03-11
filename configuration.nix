#!/usr/bin/nixos-rebuild
{config, pkgs, ...}:

## Upstream configurations
{
  imports = [ <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma5.nix> ];
}
