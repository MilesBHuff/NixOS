#!/usr/bin/env nix eval -f
## https://nixos.wiki/wiki/KDE
{config, pkgs, lib, var, ...}: {
    # services.xserver.enable = true; ## Shouldn't need if using a Wayland session.

    services.displayManager = {
        sddm.wayland.enable = true;
        defaultSession = "plasma";
    };
    services.displayManager.sddm.wayland.enable = true;
    services.displayManager.defaultSession = "plasma";

    services.desktopManager.plasma6.enable = true;

    ## Disable unwanted KDE software
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
        amarok
        kmail
        konversation
    ];

    ## Suppress alternatives to KDE's builtins
    nixpkgs.config.packageOverrides = pkgs: pkgs // {
        gnome-keyring = null;
    };

    ## Needed in order to fix theming in non-KDE Wayland windows
    programs.dconf.enable = true;
}
