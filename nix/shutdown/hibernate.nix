#!/usr/bin/env nix eval -f
{config, pkgs, lib, ...}: {
    #TODO: Before hibernating, dynamically create/delete a `/swap/0.swp` file of a size equivalent to system RAM and swap it on with max priority.
    #TODO: After recovering from hibernation, unswap and delete `/swap/0.swp`.
}
