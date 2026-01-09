#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {

    ceil_percent_of = percent: value:
        ((value * percent) + 99) / 100;

    let
        latency_multiplier = 1; ## Increase this if your system can't handle the defaults. Should be a power of 2.
        use_microframes = true; ## Whether to take full advantage of microframes. Requires your sound devices to be High-Speed (not Full-Speed) and not in competition with another device for their microframes.
        tsched = 1; #DEPRECATED ## `1` to reduce latency and power-consumption; `0` for compatibility.

        sample_rate_default = 48000;
        sample_rate_alternate = 44100;
        resample_quality = 100; ## This is a percent.
    in {
        let
            quantum_floor = if use_microframes then sample_rate_default / 8000 else sample_rate_default / 1000; ## (125µs) The absolute lowest possible with microframes.
            quantum_min = sample_rate_default / 1000; ## (1ms) The lowest we can realistically go without microframes. Thankfully, there's physically no point in going lower, anyway: Even controlled inter-aural comparisons (which we're way more-sensitive to than total delay) at 2kHz (our most-sensitive frequency) show sensitivity only to 1ms.
            quantum_norm = sample_rate_default / 500; ## (2ms) Our ears can detect 2ms inter-aurally at most frequencies.
            quantum_max = sample_rate_default * 3 / 500; ## (6ms) Below 6–10ms, overall (non-inter-aural) delay is generally imperceptible; this is the highest we can go within that limit.
            quantum_ceil = sample_rate_default / 100; ## (10ms) The upper-end of the 6–10ms imperceptibility range.
        in {
            if use_microframes then boot.extraModprobeConfig = ''
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
                    ## Copied from: https://nixos.wiki/wiki/PipeWire#Bluetooth_Configuration
                    bluetoothEnhancements = {
                        "monitor.bluez.properties" = {
                            "bluez5.enable-sbc-xq" = true;
                            "bluez5.enable-msbc" = true;
                            "bluez5.enable-hw-volume" = true;
                            "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ]; ## Try removing if you encounter weird issues.
                        };
                    };

                    ## ALSA
                    "51-alsa-latency" = {
                        "monitor.alsa.rules" = [{

                            ## DAC
                            matches = [
                                { "device.name" = "alsa_card.usb-REPLACE_ME_DAC"; } #TODO
                            ];
                            actions = {
                                update-props = {
                                    "audio.rate" = 48000;
                                    "api.alsa.period-size" = 48;
                                    "api.alsa.period-num" = 2;
                                    "api.alsa.headroom" = 0;
                                };
                            };
                        } {

                            ## Mic
                            matches = [
                                { "device.name" = "alsa_card.usb-REPLACE_ME_MIC"; } #TODO
                            ];
                            actions = {
                                update-props = {
                                    "audio.rate" = 48000;
                                    "api.alsa.period-size" = 48;
                                    "api.alsa.period-num" = 2;
                                    "api.alsa.headroom" = 0;
                                };
                            };
                        }];
                    };
                };

                ## Custom stuff
                extraConfig = {
                    pipewire = {
                        "90-memory-locking" = {
                            "context.properties" = {
                                "mem.allow-mlock" = true;
                                "mem.warn-mlock" = true;
                                "mem.mlock-all" = true;

                                "clock.power-of-two-quantum" = false; ## Required to get integer quanta with common sample rates.
                            };
                        };
                        "90-sampling" = {
                            "context.properties" = {
                                "default.clock.allowed-rates" = [ sample_rate_default sample_rate_alternate ];
                                "default.clock.rate" = sample_rate_default;
                                "resample.quality" = ceil_percent_of resample_quality 10;
                            };
                        };
                        "90-latency" = {
                            "context.properties" = {
                                "default.clock.quantum-floor" = quantum_floor * latency_multiplier;
                                "default.clock.min-quantum" = quantum_min * latency_multiplier;
                                "default.clock.quantum" = quantum_norm * latency_multiplier;
                                "default.clock.max-quantum" = quantum_max * latency_multiplier;
                                "default.clock.quantum-limit" = quantum_ceil * latency_multiplier;
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
                                "node.lock-quantum" = false; ## Whether to keep quantum stable while apps are active
                                "resample.quality" = ceil_percent_of resample_quality 14;
                                "channelmix.upmix" = true;
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

                                "pulse.min.frag" = "${quantum_min * latency_multiplier}/${sample_rate_default}";
                                "pulse.default.frag" = "${quantum_norm * latency_multiplier}/${sample_rate_default}";

                                "pulse.min.req" = "${quantum_min * latency_multiplier}/${sample_rate_default}";
                                "pulse.default.req" = "${quantum_norm * latency_multiplier}/${sample_rate_default}";
                                "pulse.default.tlength" = "${quantum_norm * latency_multiplier}/${sample_rate_default}";

                                "pulse.min.quantum" = "${quantum_min * latency_multiplier}/${sample_rate_default}";
                                "pulse.max.quantum" = "${quantum_max * latency_multiplier}/${sample_rate_default}";
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
                    alternate-sample-rate = sample_rate_alternate; ## CD-quality audio. Has to be supported because it's extremely common.
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
            };

            ## Settings: OpenAL
            ## https://github.com/kcat/openal-soft/blob/master/alsoftrc.sample
            environment.etc."openal/alsoft.conf".text = lib.generators.toINI {} {
                general = {
                    sample-type = "float32";
                    # frequency = sample_rate_default; ## Leave empty; default behavior tries to auto-detect, and falls back to 48000 already.
                    resampler = "bsinc48";

                    periods = 3; ## Matches what we configured for Pulseaudio above.
                    period_size = 256; ## About 5.3ms.

                    stereo-encoding = "hrtf"; #TODO: Implement HRTF centrally in Pipewire instead, and only when the output is fewer channels than the input.
                };
                decoder = {
                    hq-mode = true;
                }
            };
        };
    };
}
