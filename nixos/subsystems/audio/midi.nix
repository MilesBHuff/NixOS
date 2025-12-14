#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    services.fluidsynth = { #TODO: Is this the best midi service?
        enable = true;
        soundFont = "${pkgs.soundfont-fluid}/share/sounds/sf2/Arachno-1.0.sf2"; #TODO: Confirm filename.
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

    ## TODO: The following directories should redirect to `/usr/share/sounds/sf2/`:
    ## /usr/share/soundfonts/
    ## /usr/share/cinnamon/sounds/sf2/
    ## /usr/share/gnome/sounds/sf2/
    ## (probably others)

    #TODO: What about sf3?
}
