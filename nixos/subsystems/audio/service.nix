#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}:

let
    ## Helper functions
    round_positive = num: builtins.floor (num + 0.5);
    num2pow2 = directionality: num:
        if num <= 1 then 1 else let
            power = builtins.floor (builtins.logBase 2 (num + 1e-9));
            low = 2 ^ power;
            high = 2 ^ (power + 1);
        in lib.getAttr directionality {
            floor = low;
            ceil = high;
            round = if num - low <= high - num then low else high;
        };

    ## Scheduling settings
    use_microframes = true; ## Whether to take full advantage of microframes. Requires your sound devices to be High-Speed (not Full-Speed) and not in competition with another device for their microframes.
    tsched = 1; #DEPRECATED ## `1` to reduce latency and power-consumption; `0` for compatibility.

    ## While it may seem best to allow Pipewire to attempt to switch sample rates to match the current content, I don't actually think that's truly ideal, and here's why:
    ## * There is a pause when switching.
    ## * If Pipewire is running at 44.1kHz, 48kHz content has increased latency. Videos and videogames are very latency-sensitive, and both use 48kHz. The only thing that uses 44.1kHz is music. Music is not latency-sensitive. Risking increased latency on latency-sensitive use-cases in order to reduce latency on latency-insensitive use-cases makes no sense.
    ## * Resampling to 44.1kHz with soxr-lq (`2`) rolls off above 17.6kHz, which is really low. Resampling to 48kHz with soxr-lq rolls off above 19.2kHz, which is extremely acceptable. `2` has lower latency and CPU than `3`. Rolling off these ultra-high frequencies is actually desirable anyway because it gives headroom for boosting still-high-but-less-high frequencies into audibility.
    ## * All FIR SoX levels have worst-case stopband dB levels *way* below audibility: soxr-lq, the lowest quality one, has them at -100dB. 16-bit audio is at most 96dB, and the loudest you're likely to listen to music is 80dBA SPL.
    resample_quality = 2; ## This is for SoXR. A `3` corresponds to "medium quality". Per `man sox`, `3` and `2` both have stopbands at -100dB (better than you'll ever need); but `2` starts rolling off at 80% of the max, while `3` waits until `95%`. (source: https://community.audirvana.com/t/explanation-for-sox-filter-controls/10848/9)
    sample_rate_default = 48000; ## This is most content.
    # sample_rate_alternate = 44100; ## This is music from audio CDs. As per the above comment block, all uses of this variable are commented-out.

    ## Multiply the below two values to get your total latency multiplier. You probably don't want a total multiplier above `5`.
    #NOTE: A total multiplier of `4`, all things considered, lands at a total latency of about 6.3ms over ALSA, assuming no resampling.
    periods = 2; ## `1` provides the target_quanta below, but has no resiliency. Default is `2`.
    latency_multiplier = 2; ## You can increase this if you want to save CPU. Must be a power of two.

    ## This block is designed to make latency imperceptible. It assumes `periods` and `latency_multiplier` both equal `1`, and it pretends non-powers of two are universally supported.
    target_quanta = { ## Division is explicitly with floats in case we ever need to support 22050Hz.
        floor = if use_microframes then builtins.ceil (sample_rate_default / 8000.0) else builtins.ceil (sample_rate_default / 1000.0); ## (125µs) The absolute lowest possible with microframes.
        min   = round_positive (sample_rate_default / 1000.0); ## (1ms) The lowest we can realistically go without microframes. Thankfully, there's physically no point in going lower, anyway: Even controlled inter-aural comparisons (which we're way more-sensitive to than total delay) at 2kHz (our most-sensitive frequency) show sensitivity only to 1ms.
        norm  = round_positive (sample_rate_default / 500.0); ## (2ms) Our ears can detect 2ms inter-aurally at most frequencies.
        max   = round_positive (sample_rate_default * 3 / 500.0); ## (6ms) Below 6–10ms, overall (non-inter-aural) delay is generally imperceptible; this is the highest we can go within that limit.
        ceil  = builtins.floor (sample_rate_default / 100.0); ## (10ms) The upper-end of the 6–10ms imperceptibility range.
    };
    ## Many things expect quanta to be powers of two, so we need to round the above to their closest powers of two after we scale them by the latency multiplier.
    quanta = {
        floor =  num2pow2 "ceil"  (target_quanta.floor);                      ## `ceil`  because we need to stay above the minimum it is feasible to feed in one microframe.
        min   =  num2pow2 "round" (target_quanta.min);                        ## `round` because we're targeting this value roughly.
        norm  = (num2pow2 "floor" (target_quanta.norm)) * latency_multiplier; ## `floor` because we're trying to keep below a perceptual target.
        max   = (num2pow2 "round" (target_quanta.max))  * latency_multiplier; ## `round` because we're targeting this value roughly.
        ceil  = (num2pow2 "round" (target_quanta.ceil)) * latency_multiplier; ## `round` because we're targeting this value roughly.
    };
in {
    boot.extraModprobeConfig = lib.optionalString use_microframes ''
        options snd-usb-audio nrpacks=1
    '';

    ## Documentation: https://nixos.wiki/wiki/PipeWire#Enabling_PipeWire
    security.rtkit.enable = true;
    services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;

        wireplumber.extraConfig = {
            ## Modified from: https://nixos.wiki/wiki/PipeWire#Bluetooth_Configuration
            bluetoothEnhancements = {
                "monitor.bluez.properties" = {
                    "bluez5.enable-sbc-xq" = true;
                    "bluez5.enable-msbc" = true;
                    "bluez5.enable-hw-volume" = true;
                };
            };

            ## ALSA
            "51-alsa-latency" = {
                "monitor.alsa.rules" = [{
                    matches = [
                        { node.name = "~alsa_output.*" }
                        { node.name = "~alsa_input.*" }
                    ];
                    actions = {
                        update-props = {
                            "api.alsa.period-num" = periods;
                            "api.alsa.period-size" = quanta.norm;
                            # "api.alsa.buffer-size" = quanta.norm * periods;
                            "api.alsa.headroom" = target_quanta.floor * 8; ## This gives us 1 FS frame or 8 HS microframes of slack.
                        };
                    };
                }];
            };
        };

        ## Custom stuff
        extraConfig = {
            pipewire = {
                # "90-memory-locking" = {
                #     "context.properties" = {
                #         "mem.allow-mlock" = true;
                #         "mem.warn-mlock" = true;
                #         "mem.mlock-all" = true;
                #     };
                # };
                "90-sampling" = {
                    "context.properties" = {
                        "default.clock.allowed-rates" = [ sample_rate_default ]; #sample_rate_alternate
                        "default.clock.rate" = sample_rate_default;

                        "resample.method" = "soxr";
                        "resample.quality" = resample_quality;
                    };
                };
                "90-latency" = {
                    "context.properties" = {
                        "clock.power-of-two-quantum" = true; ## While non-powers of two can yield integer seconds, many audio pathways expect or perform better with powers of two, so we should ensure we use them.
                        "node.lock-quantum" = false; ## Whether to keep quantum stable while apps are active.
                        # "clock.force-quantum" = quanta.norm; ## Optional. Prevents applications from forcing us to the quantum limit. In my experience, Firefox always requests the max, and I know it's not the only one; this largely defeats the purpose of my tuning.

                        "default.clock.quantum-floor" = quanta.floor;
                        "default.clock.min-quantum" = quanta.min;
                        "default.clock.quantum" = quanta.norm;
                        "default.clock.max-quantum" = quanta.max;
                        "default.clock.quantum-limit" = quanta.ceil;
                    };
                };
                "90-priority" = {
                    "module.rt.args" = {
                        "nice.level" = -19;
                        "rt.prio" = 40;
                    };
                };
            };
            client = {
                "90-mixing" = {
                    "stream.properties" = {
                        "resample.method"  = "soxr";
                        "resample.quality" = resample_quality;
                        "channelmix.upmix" = true; ## This beats having surround speakers sit idle 99% of the time.
                        "channelmix.mix-lfe" = true; ## Consume LFE if it exists
                        "channelmix.lfe-cutoff" = 0.0; ## Disable synthesizing LFE
                    };
                };
            };
            jack = {
                #TODO
            };
            pipewire-pulse = {
                "90-format" = {
                    "pulse.properties" = {
                        "pulse.default.format" = "F32";

                        "pulse.min.frag" = "${quanta.min}/${sample_rate_default}";
                        "pulse.default.frag" = "${quanta.norm}/${sample_rate_default}";

                        "pulse.min.req" = "${quanta.min}/${sample_rate_default}";
                        "pulse.default.req" = "${quanta.norm}/${sample_rate_default}";
                        "pulse.default.tlength" = "${toString (quanta.norm * periods)}/${sample_rate_default}";

                        "pulse.min.quantum" = "${quanta.min}/${sample_rate_default}";
                        "pulse.max.quantum" = "${quanta.max}/${sample_rate_default}";
                    };
                };
            };
        };
    };

    ## Settings: Pulseaudio (no longer used; kept for historical reasons)
    services.pulseaudio = {
        enable = false;

        configFile = pkgs.writeText "default.pa" ''
            #!/usr/bin/pulseaudio -nF
            ## This only runs when PulseAudio is started per-user (not system-wide).
            .fail

            ################################################################################
            ## M E T A D A T A                                                            ##
            ################################################################################

            ## Use /usr/share/application/*.desktop files as a source of information about streams
            load-module module-augment-properties

            ## Support intended roles
            load-module module-intended-roles

            ################################################################################
            ## P R E - C O N F I G U R E                                                  ##
            ################################################################################

            ## Restore volumes
            load-module module-card-restore
            load-module module-device-restore
            load-module module-stream-restore

            ## Automatically switch to new destinations
            load-module module-switch-on-port-available
            # load-module module-switch-on-connect

            ################################################################################
            ## L O A D   S I N K S                                                        ##
            ################################################################################

            ## If udev, load drivers per present hardware; else, load staticly
            ## `tsched=1` uses less power and wastes less latency.
            ## `tsched=0` works with more devices.
            .ifexists module-udev-detect.so
            load-module module-udev-detect tsched=${tsched}
            .else
            load-module module-detect tsched=${tsched}
            .endif

            ## UNIX support
            .ifexists module-esound-protocol-unix.so
            load-module module-esound-protocol-unix
            .endif
            load-module module-native-protocol-unix

            ## JACK support
            .ifexists module-jackdbus-detect.so
            load-module module-jackdbus-detect channels=2
            .endif

            ## Bluetooth support
            .ifexists module-bluetooth-policy.so
            load-module module-bluetooth-policy
            .endif
            .ifexists module-bluetooth-discover.so
            load-module module-bluetooth-discover
            .endif

            ## If you want Internet support, add it here.

            ## GSettings support
            ## You can configure these via paprefs; but doing so may cause conflicts with manually-loaded modules.
            .ifexists module-gsettings.so
            .nofail
            load-module module-gsettings
            .fail
            .endif

            ## Ensure there is always at least one sink, even if it's null.
            ## Should run after all other sink-loading commands have run.
            load-module module-always-sink

            ################################################################################
            ## C O N F I G U R E   S I N K S                                              ##
            ################################################################################

            ## Restore default sink
            ## Should be as early as possible so that as many modules as possible have the correct default sink.
            load-module module-default-device-restore

            ## Rescue streams (obsolete)
            # load-module module-rescue-streams

            ## Suspend idle sinks
            load-module module-suspend-on-idle

            ## Support session managers (avoids issues with `autoexit`)
            .ifexists module-console-kit.so
            load-module module-console-kit
            .endif
            .ifexists module-systemd-login.so
            load-module module-systemd-login
            .endif

            ################################################################################
            ## E F F E C T S                                                              ##
            ################################################################################

            ## Spatializes event sounds according to where they occur on the screen(s)
            load-module module-position-event-sounds

            ## Loads filters (like echo cancellation) on-demand
            load-module module-filter-heuristics
            load-module module-filter-apply

            ## Cork A/V streams when a phone stream is active
            load-module module-role-cork

            ## Block recording for sandboxes that don't plug the "pulseaudio"/"audio-record" interfaces
            .ifexists module-flatpak-policy.so
            load-module module-flatpak-policy
            .endif
            .ifexists module-snap-policy.so
            load-module module-snap-policy
            .endif

            ################################################################################

            ## Includes the `default.pa.d`, where additional configs may lie.
            .nofail
            .include /etc/pulse/default.pa.d
        ''
        daemon.config = {

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
            default-fragments = 2; ## Set to the lowest value that doesn't give you playback issues.
            default-fragment-size-msec = 4; ## Going too far below about 5 can cause issues with quality (metalicness, ringing). `4`, `8`, and `17` allows you to make your total latency be some rough multiple of fps.
            enable-deferred-volume = true; ## Avoids harsh changes mid-buffer.
            deferred-volume-safety-margin-usec = 3000; ## Must be large-enough to handle timing errors, yet smaller than default-fragment-size-msec.
            deferred-volume-extra-delay-usec = 0; ## Should be 0 unless you're working around hardware issues.
            scache-idle-time = 60; ## How long to cache audio. Reduces disk reads.
            exit-idle-time = 1; ## Affects `avoid-resampling`; should be low so that content plays more-often in its native rate. Consider adding a 1s delay between tracks in your audio player to take full advantage of automatic sample-rate switching.

            ## Sampling
            avoid-resampling = true; ## Locks Pulseaudio into the sample rate of the first track it plays.
            default-sample-format = "float32le"; ## Not using 32+ bits or floats means deleting entire bits when scaling volume.
            default-sample-rate = sample_rate_default; ## Best conventional option for math reasons.
            alternate-sample-rate = sample_rate_default; ## SoX is so good as to be inaudible; this means that there is no reason to ever risk higher latency on videos and games just to avoid resampling music. Ergo, we should not support 44.1kHz.
            resample-method = "soxr-lq";

            ## Channels
            enable-remixing = true;
            remixing-use-all-sink-channels = true; ## Ensures surround-sound sats aren't sitting there idle during stereo playback.
            remixing-produce-lfe = false; ## Keep bass stereo and let the speakers sort it out.
            remixing-consume-lfe = true;
            lfe-crossover-freq = 120; ## 120Hz is the official standard for LFE XO; we have to match it for playback to be accurate. The only reason to break the 120Hz standard is when you're generating your own LFE channel, which we aren't doing.
            default-sample-channels = 2;
            # default-channel-map = "side-left,side-right"; ## Whether speakers or headphones, I always have my sources at 180°. With `enable-remixing = true`, front channels (99% of everything) should move to side without issue, while surround will remap more-gracefully than it would to front.
            default-channel-map = "front-left,front-right"; ## The canonical option. Ensures nothing breaks, but not as literally correct.

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
    };

    ## Settings: OpenAL
    ## https://github.com/kcat/openal-soft/blob/master/alsoftrc.sample
    environment.etc."openal/alsoft.conf".text = lib.generators.toINI {} {
        general = {
            sample-type = "float32";
            frequency = sample_rate_default; ## We're forcing this for consistency. The default behavior tries to auto-detect, and while it does fall back to 48kHz, I fear it may occasionally detect 44.1kHz.
            resampler = "bsinc48";

            periods = periods; ## Matches what we configured for Pulseaudio above.
            period_size = quanta.norm; ## About 5.3ms.

            stereo-encoding = "hrtf"; #TODO: Implement HRTF centrally in Pipewire instead, and only when the output is fewer channels than the input.
        };
        decoder = {
            hq-mode = true;
        }
    };
};
