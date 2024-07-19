#!/usr/bin/env nix eval -f
{config, pkgs, lib, ...}: {
    #TODO:  ZFSBootMenu in ESP
    #TODO:  systemd-boot for ZFS
    #TODO:  rollback `/` to blank snapshot for impersistence
    #TODO:  after system regenerates, copy `/.persist/` to `/`
}
