# direnv

## update pinned version

```
mv .nixpkgs-version.json nixpkgs-version.json.previous
nix-prefetch-git https://github.com/nixos/nixpkgs.git refs/heads/nixos-unstable >.nixpkgs-version.json
```
