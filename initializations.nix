#!/usr/bin/env nix eval -f
{config, pkgs, ...}: {
    config.systemd.tmpfiles.rules = [];
}
