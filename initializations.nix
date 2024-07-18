#!/usr/bin/env nix eval -f
{config, pkgs, lib, ...}: {
    config.systemd.tmpfiles.rules = [];
}
