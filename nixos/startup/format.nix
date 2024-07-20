#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    disko.devices = {

        ################################################################################
        ## DRIVE LAYOUTS                                                              ##
        ################################################################################

        let diskContents = {
            type = "gpt";
            partitions = {
                esp = {
                    name = "ESP";
                    type = "EF00";
                    size = "500M"; ## Seems to be the recommendation for non-insane setups.
                    content = {
                        type = "mdraid";
                        name = "esp";
                    };
                };
                main = {
                    name = "Main";
                    type = "BF00";
                    size = "100%"; #TODO: Check whether this leaves space for GPT backup sectors.  If not, set to "-20480".
                    content = {
                        type = "zfs";
                        pool = "rpool";
                    };
                };
            };
        }; in
        disk = {
            "0" = {
                type = "disk";
                device = "/dev/nvme0n1";
                content = diskContents;
            };
            "1" = {
                type = "disk";
                device = "/dev/nvme1n1";
                content = diskContents;
            };
        };

        ################################################################################
        ## RAID DEFINITIONS                                                           ##
        ################################################################################

        mdadm = {
            esp = {
                type = "mdadm";
                level = 1;
                metadata = "1.0";
                content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot/efi";
                    mountOptions = [
                        "iocharset=utf8" "tz=UTC" ## Will not be used by Windows, so we might as well make it maximally Linux-friendly.
                        "sync" "flush" ## FAT has no journalling, so all writes should be done synchronously to help ensure data integrity.  Write issues here can prevent booting!
                        "lazytime" "noatime"
                    ];
                };
            };
        };
        zpool = {
            rpool = {
                type = "zpool";
                mode = "mirror";
                mountpoint = "none";
                mountOptions = [ "lazytime" ];
                options = {
                    ashift = 12; ## ashift=12 is 4096, appropriate for Advanced Format drives, which is basically everything these days.

                    autoexpand = "on";  ## Automatically expands the pool to use available space.
                    # autoreplace = "on"; ## Automatically replaces failed drives with newly inserted ones.
                };
                rootFsOptions = {

                    atime = "off"; ## `atime` causes data duplication on read after snapshots.
                    compression = "on";  ## Recommended on; effectively no performance hit for free space savings.  Default value is LZ4.
                    logbias = "latency"; ## Correct setting for PCs; set to "throughput" if server.

                    acltype = "posixacl";       ## Required for `journald`.
                    aclinherit = "passthrough"; ## Doesn't affect POSIX ACLs, but can be needed for non-POSIX ones to work as intended.
                    aclmode = "passthrough";    ## Setting is supposedly ignored by ZoL.

                    xattr = "sa";       ## Helps performance, but makes xattrs Linux-specific.
                    dnodesize = "auto"; ## Helpful when using xattr=sa

                    redundant_metadata = "most"; ## This reduces metadata redundancy, which is appropriate when mirroring.
                    checksum = "skein"; ## More-secure than the default, which is "fletcher4"; however, this comes at a performance penalty. Datasets for which data integrity is unimportant should use the default instead.

                    encryption = "aes-256-gcm";
                    keyformat = "passphrase";
                    keylocation = "prompt";

                    mountpoint = "none";

                    "com.sun:auto-snapshot" = "false"; ## Not sure that we need this.
                };
                postCreateHook = "zfs snapshot rpool@blank";

                datasets = {
                    "reservation" = {
                        type = "zfs_fs";
                        mountpoint = "none";
                        options = {
                            checksum = "fletcher4";
                            reservation = "100G"; #TODO: Dynamically set this to 10% of disk capacity.
                        };
                        mountOptions = [ "lazytime" ];
                        postCreateHook = "zfs snapshot rpool/system@blank";
                    };
                    "system" = {
                        type = "zfs_fs";
                        mountpoint = "/";
                        options = { checksum = "fletcher4"; };
                        mountOptions = [ "lazytime" ];
                        postCreateHook = "zfs snapshot rpool/system@blank";
                    };
                    "system/boot" = {
                        type = "zfs_fs";
                        mountpoint = "/boot";
                        mountOptions = [ "lazytime" ];
                        postCreateHook = "zfs snapshot rpool/system/boot@blank";
                    };
                    "system/var" = {
                        type = "zfs_fs";
                        mountpoint = "/var";
                        mountOptions = [ "lazytime" ];
                        postCreateHook = "zfs snapshot rpool/system/var@blank";
                    };
                    "nix" = {
                        type = "zfs_fs";
                        mountpoint = "/nix";
                        mountOptions = [ "lazytime" ];
                        postCreateHook = "zfs snapshot rpool/nix@blank";
                    };
                    "persist" = {
                        type = "zfs_fs";
                        mountpoint = "/.persist";
                        mountOptions = [ "lazytime" ];
                        options = { "com.sun:auto-snapshot" = "true"; };
                        postCreateHook = "zfs snapshot rpool/persist@blank";
                    };
                    "persist/home" = {
                        type = "zfs_fs";
                        mountpoint = "/home";
                        mountOptions = [ "lazytime" ];
                        options = {
                            "com.sun:auto-snapshot" = "true";
                            # relatime = "on"; ## Uncomment if you *really* need access times for some reason.
                        };
                        postCreateHook = "zfs snapshot rpool/persist/home@blank";
                    };
                    "persist/srv" = {
                        type = "zfs_fs";
                        mountpoint = "/srv";
                        mountOptions = [ "lazytime" ];
                        options = {
                            "com.sun:auto-snapshot" = "true";
                            # atime = "on"; ## Uncomment if you run an FTP server and need access times.
                        };
                        postCreateHook = "zfs snapshot rpool/persist/srv@blank";
                    };
                };
            };
        };

        ################################################################################
        ## SPECIAL DEVICES                                                            ##
        ################################################################################

        nodev = {
            "/tmp" = {
                fsType = "tmpfs";
                mountOptions = [
                    "size=128M" ## The largest `/tmp` I've seen was around half this.
                    "nosuid" "mode=1777" ## `/tmp` requires special permissions.
                    "lazytime" "noatime"
                ];
            };
        };
    };
}
