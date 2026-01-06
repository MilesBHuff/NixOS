#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    services.fluidsynth = {
        enable = true;
        soundFont = "${pkgs.soundfont-fluid}/share/sounds/sf2/Arachno.sf2";
        soundService = "pipewire-pulse";
        extraOptions = [
            "-m" "alsa_seq" ## Midi Driver (Use ALSA for compatibility; use JACK only if you have pro audio devices that explicitly need it.)
            "-a" "jack" ## Audio Driver (Use JACK if available, else use PulseAudio.)
            "-o" "midi.autoconnect=1"
            "-g" "1.0" ## Gain
        ];
    };

    pkgs.soundfont-arachno = true; #TODO: Make sure this works.
    #TODO: Install SGM-V2.01.sf2 via URL: https://archive.org/download/SGM-V2.01/SGM-V2.01.sf2

    systemd.tmpfiles.rules = lib.mkAfter [
        "L /usr/share/soundfonts - - - - /usr/share/sounds/sf2"
        "L /usr/share/cinnamon/sounds/sf2 - - - - /usr/share/sounds/sf2"
        "L /usr/share/gnome/sounds/sf2 - - - - /usr/share/sounds/sf2"
    ];

    #TODO: What about sf3?
}
