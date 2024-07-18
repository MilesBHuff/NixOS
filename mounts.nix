#!/usr/bin/env nix eval -f
{config, pkgs, ...}: {

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

        "/" = { #TODO: Make this automatically roll back to an empty snapshot at every boot, for impermanence.
            device = "rpool/system";
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

        "/boot/efi" = { ## https://docs.zfsbootmenu.org/en/v2.3.x/general/mdraid-esp.html
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
            device = "/rpool/system/boot";
            fsType = "zfs";
            options = [ "lazytime" ];
        };
        "/var" = {
            depends = [ "/" ];
            device = "rpool/system/var";
            fsType = "zfs";
            options = [ "lazytime" ];
        };
        "/nix" = {
            depends = [ "/" ];
            device = "/rpool/nix";
            fsType = "zfs";
            options = [ "lazytime" ];
        };

        ################################################################################
        ## PERSISTENT DEVICES                                                         ##
        ################################################################################

        "/.persist" = {
            depends = [ "/" ];
            device = "/rpool/persist";
            fsType = "zfs";
            options = [ "lazytime" ];
        };
        "/srv" = {
            depends = [ "/" ];
            device = "/rpool/persist/srv";
            fsType = "zfs";
            options = [ "lazytime" ];
        };
        "/home" = {
            depends = [ "/" ];
            device = "/rpool/persist/home";
            fsType = "zfs";
            options = [ "lazytime" ];
        };

        ################################################################################
        ## EXTERNAL DEVICES                                                           ##
        ################################################################################

        "/media/games" = {
            depends = [ "/" ];
            device = "/xpool/games";
            fsType = "zfs";
            options = [ "lazytime" "noauto" "user" ];
        };
        "/media/backups" = {
            depends = [ "/" ];
            device = "/kpool/@";
            fsType = "zfs";
            options = [ "lazytime" "noauto" ];
        };
    };

    ################################################################################
    ## SWAP DEVICES                                                               ##
    ################################################################################
    #TODO: Create/delete swapfiles as needed (increments of 1GiB), so that there is always at leat 1GiB of free swap and less than 2GiB of free swap.
    #TODO: Dynamically create a `0.swp` file of a size equivalent to system RAM, for hibernation.

    systemd.tmpfiles.rules = config.systemd.tmpfiles.rules ++ [
        "d /swap 0600 root root -"
        "f /swap/1.swp 0600 root root 0"
        "f /swap/2.swp 0600 root root 0"
        "f /swap/3.swp 0600 root root 0"
        "f /swap/4.swp 0600 root root 0"
    ];
    swapDevices = [{
        device = "/swap/1.swp";
        priority = 99;
        size = 1024; #MiB
    } {
        device = "/swap/2.swp";
        priority = 98;
        size = 1024; #MiB
    } {
        device = "/swap/3.swp";
        priority = 97;
        size = 1024; #MiB
    } {
        device = "/swap/4.swp";
        priority = 96;
        size = 1024; #MiB
    }];
}
