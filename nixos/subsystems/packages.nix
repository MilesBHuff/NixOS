#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}:

let
    ## For OSS, native packages are preferred over sandboxed packages.
    ## For proprietary software, sandboxed packages are preferred over native packages.
    ## For sandboxed packages, prefer official releases over unofficial ones.
    ## Ceteris paribus, prefer Flatpak over Snap.
    packages = [
        "calibre"
        "minicom"
        "sweethome3d"

        ## System
        "bleachbit"
        "clamtk"
        "gparted"
        "konsole"
        "qdirstat"
        "plasma-systemmonitor"
        "tlpui"
        "wine-staging"

        ## Accessories
        "7zip-gui" #WARN: New GitHub project, may not be a package yet. (https://github.com/shampuan/7Zip-GUI)
        "gnome-charselect"
        "qalculate-gui"
        "ventoy"

        ## Internet
        "bitwarden-desktop"
        "chromium"
        "firefox"
        "filezilla"
        "qbittorrent"
        "wireshark"

        ## Office
        "libreoffice-fresh"
        "okular"
        "standardnotes"
        "thunderbird"

        ## Graphics
        "displaycal"
        "flameshot"
        "fontforge"
        "gimp"
        "inkscape"
        "kolourpaint"
        "ristretto"
        "pix" #TODO: Is this the best choice?
        "skanpage" #TODO: Is this the best choice?

        ## Video
        "kdenlive"
        "obs-studio"
        "vlc"

        ## Audio
        "audacity"
        "exfalso"
        "quodlibet"
        "rephase" #FIXME: This is a Windows program run over Wine, not a native Linux app.
        "roomeqwizard" #FIXME: This is proprietary, but no sandboxed package format exists for it.
        "vmpk" ## Virtual Midi Piano Keyboard

        ## Peripherals
        "kdeconnect" ## For phones
        "obsbot-control-linux" ## For OBSBOT webcams
        "piper" ## For Logitech G502 mices
        "qjoypad" ## Gamepad configurator
        "webcamcontrol" ## For any webcam

        ## Coding
        "vscodium"
        "zed"

        ## Virtualization
        "dosbox-staging"
        "virtualbox"
        "virtualbox-extpack"

        ## Games
        "0ad"
        "dolphin-emu"
        "freeciv"
        "runelite-launcher"
        "supertux2"
        "supertuxkart"
        "visualboyadvance-m"

        ## 3D-Printing
        "cura"
        "orcaslicer"

        ## Chat
        "element-desktop" ## Matrix client
        "hexchat" ## IRC client
        "signal-desktop"
        "webcord" ## Despookified Discord client
        "whatsie" ## Native Whatsapp client
    ];
    flatpaks = [
        "com.github.tchx84.Flatseal"

        ## Misc
        "com.bambulab.BambuStudio" ## No official option available as of 2026-01.
        "com.google.EarthPro" ## No official option available as of 2026-01.
        "com.makemkv.MakeMKV" ## No official option available as of 2026-01.

        ## Games
        "com.jagex.RuneScape" ## No official option available as of 2026-01
        "org.mojang.Minecraft" ## No official option available as of 2026-01
        "com.valvesoftware.Steam" ## No official option available as of 2026-01.
    ];
    snaps = [
        ## None atm.
    ];
in {
    nixpkgs.config.allowUnfree = true;
    environment.systemPackages = with pkgs; packages;

    services.flatpak.enable = true;
    system.activationScripts.flatpakSetup = {
        text = "${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo";
    };
    system.activationScripts.flatpakApps = {
        text = "${pkgs.flatpak}/bin/flatpak install -y --noninteractive flathub ${builtins.concatStringsSep " \\\n " flatpakApps}";
    };

    services.snapd.enable = true;
    services.snapd.apparmor.enable = true;
}
