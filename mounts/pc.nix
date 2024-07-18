#!/usr/bin/env nix eval -f
{config, pkgs, ...}: {
    #TODO: Set up disk encryption.
    #TODO: Use ZFS instead of btrfs.
    #TODO: Set SSD/HDD options dynamically.  `btrfs` already automatically sets SSD options for SSDs, but it doesn't set `autodefrag` for HDDs.
    #WARN: btrfs and zfs do poorly with access time updates, which actually trigger a full CoW, which can dramatically increase space usage if the files in-question have previously been snapshotted!  Accordingly, `atime` and `relatime` should *not* be used on btrfs or zfs if you plan to make use of snapshotting.
    #NOTE: `lazytime` affects `mtime` and `ctime`, too -- not just `atime`.  Accordingly, it can still be beneficial in tandem with `noatime`.
    fileSystems = {

        ################################################################################
        ## BIOS DEVICES                                                               ##
        ################################################################################

        "/boot/EFI" = {
            depends = [ "/" ];
            device = "/dev/disk/by-label/ESP";
            fsType = "vfat";
            options = [
                "iocharset=utf8" "tz=UTC" ## Will not be used by Windows, so making it maximally Linux-friendly.
                "sync" "flush" ## FAT has no journalling, so all writes should be done synchronously to help ensure data integrity.  Write issues here can prevent booting!
                "lazytime" "noatime"
            ];
        };
        "/boot/EFI.bak" = {
            depends = [ "/" ];
            device = "/dev/disk/by-label/ESP.bak";
            fsType = "vfat";
            options = [
                "iocharset=utf8" "tz=UTC" ## Will not be used by Windows, so making it maximally Linux-friendly.
                "sync" "flush" ## FAT has no journalling, so all writes should be done synchronously to help ensure data integrity.  Write issues here can prevent booting!
                "lazytime" "noatime"
            ];
        };

        ################################################################################
        ## SYSTEM DEVICES                                                             ##
        ################################################################################

        "/" = { #TODO: Set up a way to easily replace this with a new subvolume, for occasional impersistence.  I'd like to impersist root every time NixOS has a major update.
            device = "/dev/disk/by-label/NixOS";
            fsType = "btrfs";
            options = [
                "subvol=@root"
                "compress=zstd:1"
                "lazytime" "noatime"
            ];
        };
        "/boot" = {
            depends = [ "/" ];
            device = "/dev/disk/by-label/NixOS";
            fsType = "btrfs";
            options = [
                "subvol=@boot"
                "compress=zstd:1"
                "lazytime" "noatime"
            ];
        };
        "/boot/.snapshots" = {
            depends = [ "/" "/boot" ];
            device = "/dev/disk/by-label/NixOS";
            fsType = "btrfs";
            options = [
                "subvol=@boot/snapshots"
                "ro"
            ];
        };
        "/nix" = {
            depends = [ "/" ];
            device = "/dev/disk/by-label/NixOS";
            fsType = "btrfs";
            options = [
                "subvol=@nix-store"
                "compress=zstd:1"
                "lazytime" "noatime"
            ];
        };
        "/etc/nix" = {
            depends = [ "/" ];
            device = "/dev/disk/by-label/NixOS";
            fsType = "btrfs";
            options = [
                "subvol=@nix-conf"
                "compress=zstd:1"
                "lazytime" "noatime"
            ];
        };
        "/var/swap" = {
            depends = [ "/" ];
            device = "/dev/disk/by-label/NixOS";
            fsType = "btrfs";
            options = [
                "subvol=@swap"
                "nodatacow" ## Mandatory for swapfiles
                "lazytime" "noatime"
            ];
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
        "/.snapshots" = {
            depends = [ "/" ];
            device = "/dev/disk/by-label/NixOS";
            fsType = "btrfs";
            options = [
                "subvol=@snapshots"
                "ro"
            ];
        };

        ################################################################################
        ## USER/SERVICE DEVICES                                                       ##
        ################################################################################

        "/usr/local" = {
            depends = [ "/" ];
            device = "/dev/disk/by-label/Local";
            fsType = "btrfs";
            options = [
                "subvol=@usr"
                "compress=zstd:1"
                "lazytime" "noatime"
            ];
        };
        "/usr/local/.snapshots" = {
            depends = [ "/" "/usr/local" ];
            device = "/dev/disk/by-label/NixOS";
            fsType = "btrfs";
            options = [
                "subvol=@local/snapshots"
                "ro"
            ];
        };
        "/srv" = {
            depends = [ "/" ];
            device = "/dev/disk/by-label/Local";
            fsType = "btrfs";
            options = [
                "subvol=@srv"
                "compress=zstd:1"
                "lazytime" "noatime" #NOTE: Consider `atime` if you run an FTP server and aren't using btrfs snapshots.
            ];
        };
        "/srv/.snapshots" = {
            depends = [ "/" "/srv" ];
            device = "/dev/disk/by-label/NixOS";
            fsType = "btrfs";
            options = [
                "subvol=@local/snapshots"
                "ro"
            ];
        };
        "/home" = {
            depends = [ "/" ];
            device = "/dev/disk/by-label/Local";
            fsType = "btrfs";
            options = [
                "subvol=@home"
                "compress=zstd:1"
                "lazytime" "noatime" #NOTE: Consider `relatime` if not using btrfs snapshots, because access time is needed for certain backup programs and email clients to work right.
            ];
        };
        "/home/.snapshots" = {
            depends = [ "/" "/home" ];
            device = "/dev/disk/by-label/NixOS";
            fsType = "btrfs";
            options = [
                "subvol=@local/snapshots"
                "ro"
            ];
        };

        ################################################################################
        ## EXTERNAL DEVICES                                                           ##
        ################################################################################

        "/media/games" = {
            depends = [ "/" ];
            device = "/dev/disk/by-label/Games";
            fsType = "btrfs";
            options = [
                "subvol=@games"
                "compress=zstd:1"
                "lazytime" "noatime"
            ];
        };
    };

    ################################################################################
    ## SWAP DEVICES                                                               ##
    ################################################################################

    #TODO: Create/delete swapfiles as needed (increments of 1GiB), so that there is always at leat 1GiB of free swap and less than 2GiB of free swap.
    #TODO: Dynamically create a `0.swp` file of a size equivalent to system RAM, for hibernation.
    swapDevices = [{
        device = "/var/swap/1.swp";
        priority = 99;
        size = 1024; #MiB
    } {
        device = "/var/swap/2.swp";
        priority = 98;
        size = 1024; #MiB
    } {
        device = "/var/swap/3.swp";
        priority = 97;
        size = 1024; #MiB
    } {
        device = "/var/swap/4.swp";
        priority = 96;
        size = 1024; #MiB
    }];
}
