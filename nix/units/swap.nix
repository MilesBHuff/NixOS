#!/usr/bin/env nix eval -f
{config, pkgs, lib, var, ...}: {
    #TODO: Create/delete swapfiles as needed.  Swap files should be stored under `/swap/`, and should be named `n.swp`, with "n" being an integer starting at `1` and increasing thence.  Each swap file's priority should be its number less than the maximum desired number of swap files (by default `100`).  (Note that this avoids using priority `-1`, thus preserving it for special use.)  Each swap file should be 1GiB in size, and sparsely allocated if possible.  A new swapfile should be created every time the system has less than 1GiB of swap remaining;  and the most-recently-created swapfile should be deleted whenever the system has 2GiBs or more of free swap space.
}
