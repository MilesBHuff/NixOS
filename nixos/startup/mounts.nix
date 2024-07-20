#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {

    ## Drives that are primarily or totally dedicated to ZFS should have Linux's default I/O scheduler disabled, since they have their own built-in.
    #TODO: Dynamically populate the relevant disks.
    services.udev.extraRules = ''
        ACTION=="add|change", KERNEL=="nvme0n1", ATTR{queue/scheduler}="noop"
        ACTION=="add|change", KERNEL=="nvme1n1", ATTR{queue/scheduler}="noop"
    '';

    #WARN: btrfs and zfs do poorly with access time updates, which actually trigger a full CoW, which can dramatically increase space usage if the files in-question have previously been snapshotted!  Accordingly, `atime` and `relatime` should *not* be used on btrfs or zfs if you plan to make use of snapshotting.
    #NOTE: `lazytime` affects `mtime` and `ctime`, too -- not just `atime`.  Accordingly, it can still be beneficial in tandem with `noatime`.
    fileSystems = {

        ################################################################################
        ## IMPERSISTENT DEVICES                                                       ##
        ################################################################################

        "/" = {
            device = "nix-pool/system";
            fsType = "zfs";
            options = [ "lazytime" ];
        };
        "/tmp" = {
            depends = [ "/" ];
            fsType = "tmpfs";
            options = [
                "size=128M" ## The largest `/tmp` I've seen was around half this.
                "nosuid" "mode=1777" ## `/tmp` requires special permissions.
                "lazytime" "noatime"
            ];
        };

        ################################################################################
        ## SEMI-PERSISTENT DEVICES                                                    ##
        ################################################################################

        "/boot/efi" = {
            depends = [ "/" ];
            device = "/dev/md/esp";
            fsType = "vfat";
            options = [
                "iocharset=utf8" "tz=UTC" ## Will not be used by Windows, so making it maximally Linux-friendly.
                "sync" "flush" ## FAT has no journalling, so all writes should be done synchronously to help ensure data integrity.  Write issues here can prevent booting!
                "lazytime" "noatime"
            ];
        };
        "/boot" = {
            depends = [ "/" ];
            device = "/nix-pool/system/boot";
            fsType = "zfs";
            options = [ "lazytime" ];
        };
        "/var" = {
            depends = [ "/" ];
            device = "nix-pool/system/var";
            fsType = "zfs";
            options = [ "lazytime" ];
        };
        "/nix" = {
            depends = [ "/" ];
            device = "/nix-pool/nix";
            fsType = "zfs";
            options = [ "lazytime" ];
        };

        ################################################################################
        ## PERSISTENT DEVICES                                                         ##
        ################################################################################

        "/.persist" = {
            depends = [ "/" ];
            device = "/nix-pool/persist";
            fsType = "zfs";
            options = [ "lazytime" ];
        };
        "/srv" = {
            depends = [ "/" ];
            device = "/nix-pool/persist/srv";
            fsType = "zfs";
            options = [ "lazytime" ];
        };
        "/home" = {
            depends = [ "/" ];
            device = "/nix-pool/persist/home";
            fsType = "zfs";
            options = [ "lazytime" ];
        };

        ################################################################################
        ## EXTERNAL DEVICES                                                           ##
        ################################################################################

        "/media/games" = {
            depends = [ "/" ];
            device = "/game-pool/games";
            fsType = "zfs";
            options = [ "lazytime" "noauto" "user" ];
        };
        "/media/backups" = {
            depends = [ "/" ];
            device = "/backup-pool/@";
            fsType = "zfs";
            options = [ "lazytime" "noauto" ];
        };
    };
}
