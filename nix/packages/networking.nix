#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    networking.hostName = "ultima"; #TWEAKABLE: Replace "ultima" with your desired hostname.

    ## Ability to network
    networking.networkmanager.enable = true;
    networking.wireless.enable = true;

    ## Proxy settings
    networking.proxy.noProxy = "127.0.0.1,localhost"; #TODO: Dynamically set this with relevent contents of `/etc/hosts`.

    ## Firewall
    networking.firewall.enable = true; #TODO: Is this `firewalld`?
    networking.firewall.allowedTCPPorts = [];
    networking.firewall.allowedUDPPorts = [];
}
