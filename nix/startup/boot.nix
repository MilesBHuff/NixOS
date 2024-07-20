#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    #TODO:  ZFSBootMenu in ESP
    #TODO:  systemd-boot for ZFS
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    #TODO:  rollback `/` to blank snapshot for impersistence
    #TODO:  after system regenerates, copy `/.persist/` to `/`
}
