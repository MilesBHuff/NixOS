#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    nixpkgs.config.allowUnfree = true;
    programs.firefox.enable = true;
    environment.systemPackages = with pkgs; [
        "thunderbird"
        #TODO
    ];
}
