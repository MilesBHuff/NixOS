#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.supportedLocales = [
        "C.UTF-8"
        "en_CA.UTF-8"
        "en_US.UTF-8"
    ];
    i18n.extraLocaleSettings = {
        COUNTRY=US
        LANGUAGE=en_US.UTF-8
        LANG=en_US.UTF-8
        #LC_ALL=
        #LC_ADDRESS=en_US.UTF-8
        #LC_COLLATE=en_US.UTF-8
        #LC_CTYPE=C.UTF-8
        #LC_IDENTIFICATION=en_US.UTF-8
        LC_MEASUREMENT=en_CA.UTF-8
        #LC_MESSAGES=en_US.UTF-8
        #LC_MONETARY=en_US.UTF-8
        #LC_NAME=en_US.UTF-8
        #LC_NUMERIC=en_US.UTF-8
        #LC_PAPER=en_US.UTF-8
        #LC_TELEPHONE=en_US.UTF-8
        LC_TIME=en_CA.UTF-8
        TIME_STYLE=iso
    };
}
