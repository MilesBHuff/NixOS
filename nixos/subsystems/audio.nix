#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {

    ## Documentation: https://nixos.wiki/wiki/PipeWire#Enabling_PipeWire
    security.rtkit.enable = true;
    services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
        extraLibraries = [ pkgs.libsoxr ];
    };

    ## Copied from: https://nixos.wiki/wiki/PipeWire#Bluetooth_Configuration
    services.pipewire.wireplumber.extraConfig.bluetoothEnhancements = {
        "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
        };
    };

    ## Settings: Pipewire
    services.pipewire.extraConfig.pipewire."context.properties" = {
        "resample.quality" = 10;
        "default.clock.rate" = 48000;
        "default.clock.allowed-rates" = [ 48000 44100 ];

        ## Latency
        "default.clock.quantum-floor" = 16; ## 1/3ms (0.3ms) Basically the lowest anything physically supports running at.
        "default.clock.min-quantum" = 32; ## 2/3ms (0.7ms) Physically no point in allowing lower; would just waste system resources. Even controlled inter-aural comparisons (which we're way more-sensitive to than total delay) at 2kHz (our most-sensitive frequency) show sensitivity only to 1ms, and this is below that, allowing for 0.3ms of additional lag before we hit that 1ms target.
        "default.clock.quantum" = 64; ## 4/3ms (1.3ms) Keeps us comfortably below the 2ms that our ears can detect at most frequencies in inter-aural comparisons, which is exceptional for total delay. This means the chain can be used for live monitoring with minimal comb-filtering. And in non-monitoring situations, it leaves us with plenty of headroom for DSP further in the chain.
        "default.clock.max-quantum" = 256; ## 16/3ms (5.3ms) Below 6–10ms, overall (non-inter-aural) delay is generally imperceptible; this is the highest we can go within that limit, and it provides headroom for delays elsewhere in the chain.
        "default.clock.quantum-limit" = 512; ## 32/3ms (10.7ms) The upper-end of the 6–10ms imperceptibility range.
    };

    ## Settings: Pulseaudio
    ## A lot of these are ignored under Pipewire, but I specify them anyway for reference so that I know how to configure systems still running actual Pulseaudio.
    services.pipewire.pulse.config."daemon.conf" = {

        ## Memory
        lock-memory = true; ## Prevents paging out audio-related memory.
        enable-memfd = true; ## Modern memory architecture.
        enable-shm = true; ## Legacy memory architecture. Used if memfd isn't available.
        # shm-size-bytes = 0; ## 0 == auto (64M)

        ## Scheduling
        cpu-limit = false;
        high-priority = true; ## Ignored if RT.
        nice-level = -19; ## Ignored if RT.
        realtime-scheduling = true;
        realtime-priority = 40;
        # tsched = 0; ## If `1`, can cause dropouts under load. Not present on newer versions of Pulseaudio.
        default-fragments = 2; ## Should be greater than 1 but also as low as possible. Increase only if you experience playback issues. 2x4=8ms, which is about 0.5fps; this means that Pulseaudio won't be a cause of A/V desynchronization.
        default-fragment-size-msec = 4; ## Going too far below about 5 can cause issues with quality (metalicness, ringing).
        enable-deferred-volume = true; ## Avoids harsh changes mid-buffer.
        deferred-volume-safety-margin-usec = 3000; ## Must be large-enough to handle timing errors, yet smaller than default-fragment-size-msec.
        deferred-volume-extra-delay-usec = 0; ## Should be 0 unless you're working around hardware issues.
        scache-idle-time = 60; ## How long to cache audio. Reduces disk reads.
        exit-idle-time = 1; ## Affects `avoid-resampling`; should be low so that content plays more-often in its native rate. Consider adding a 1s delay between tracks in your audio player to take full advantage of automatic sample-rate switching.

        ## Sampling
        avoid-resampling = true; ## Locks Pulseaudio into the sample rate of the first track it plays.
        default-sample-format = "float32le"; ## Not using 32+ bits or floats means deleting entire bits when scaling volume.
        default-sample-rate = 48000; ## Best conventional option for math reasons.
        alternate-sample-rate = 44100; ## CD-quality audio. Has to be supported because it's extremely common.
        resample-method = "soxr-vhq";

        ## Channels
        enable-remixing = true;
        remixing-use-all-sink-channels = true; ## Ensures surround-sound sats aren't sitting there idle during stereo playback.
        remixing-produce-lfe = false; ## Keep bass stereo and let the speakers sort it out.
        remixing-consume-lfe = true;
        lfe-crossover-freq = 120; ## 120Hz is the official standard for LFE XO; we have to match it for playback to be accurate. The only reason to break the 120Hz standard is when you're generating your own LFE channel, which we aren't doing.
        default-sample-channels = 2;
        # default-channel-map = "side-left,side-right"; ## Whether speakers or headphones, I always have my sources at 180°. With `enable-remixing = true`, front channels (99% of everything) should move to side without issue, while surround will remap more-gracefully than it would to front.
        default-channel-map = "front-left,front-right" ## The canonical option. Ensures nothing breaks, but not as literally correct.

        ## Misc
        rescue-streams = true; ## Prevents streams from sticking with dead sinks.
        flat-volumes = false; ## Misguided behavior; leave disabled.

        ## Logging
        log-target = "auto";
        log-level = "notice";
        log-meta = false;
        log-time = true;
        log-backtrace = 0;
    };

    ## Settings: OpenAL
    ## https://github.com/kcat/openal-soft/blob/master/alsoftrc.sample
    environment.etc."openal/alsoft.conf".text = lib.generators.toINI {} {
        general = {
            sample-type = "float32";
            # frequency = 48000; ## Leave empty; default behavior tries to auto-detect, and falls back to 48000 already.
            resampler = "bsinc48";

            periods = 3; ## Matches what we configured for Pulseaudio above.
            period_size = 256; ## About 5.3ms.

            stereo-encoding = "hrtf"; #TODO: Implement HRTF centrally in Pipewire instead, and only when the output is fewer channels than the input.
        };
        decoder = {
            hq-mode = true;
        }
    };
}
