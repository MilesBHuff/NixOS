#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    config.systemd.tmpfiles.rules = [];
}
