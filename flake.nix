{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:smunix/devenv?ref=smunix-patch-1";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    nix-utils.url = "github:smunix/nix-utils";
    nix-filter.url = "github:numtide/nix-filter";
    flake-utils.url = "github:numtide/flake-utils";
    effectful.url = "github:haskell-effectful/effectful?ref=labeled";
    effectful.flake = false;
    optics.url = "github:well-typed/optics";
    optics.flake = false;
    hls.url = "github:haskell/haskell-language-server";
    hls.inputs.nixpkgs.follows = "nixpkgs";
    tree-diff.url = "github:haskellari/tree-diff";
    tree-diff.flake = false;
    fourmolu.url =
      "https://hackage.haskell.org/package/fourmolu-0.13.0.0/fourmolu-0.13.0.0.tar.gz";
    fourmolu.flake = false;
  };

  outputs = { self, nixpkgs, devenv, systems, nix-utils, nix-filter, flake-utils
    , ... }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
      config = { };
      pkgs' = system: import nixpkgs { inherit config system; };
      ghc-version = "92";
      hspkgs' = system:
        let pkgs = pkgs' system;
        in with nix-utils.lib;
        with nix-filter.lib;
        with pkgs.haskell.lib;
        slow pkgs.haskell.packages."ghc${ghc-version}" [
          {
            modifiers = [ doHaddock dontCheck ];
            extension = hfinal: hprevious:
              with hfinal; {
                project = callCabal2nixWithOptions "project" (filter {
                  root = "${inputs.self}/project";
                  exclude = [ (matchExt "cabal") ];
                })
                  (if ghc-version != "96" then "-fuse-effectful-plugin" else "")
                  { };
              };
          }
          {
            modifiers = [ dontHaddock dontCheck ];
            extension = hfinal: hprevious:
              with hfinal; {
                optics-core = callCabal2nix "optics-core"
                  (filter { root = "${inputs.optics}/optics-core"; }) { };
                optics-extra = callCabal2nix "optics-extra"
                  (filter { root = "${inputs.optics}/optics-extra"; }) { };
                optics-th = callCabal2nix "optics-th"
                  (filter { root = "${inputs.optics}/optics-th"; }) { };
                optics = callCabal2nix "optics"
                  (filter { root = "${inputs.optics}/optics"; }) { };
              };
          }
          {
            modifiers = [ dontHaddock dontCheck ];
            extension = hfinal: hprevious:
              with hfinal; {
                effectful-core = callCabal2nix "effectful-core"
                  (filter { root = "${inputs.effectful}/effectful-core"; }) { };
                effectful-plugin = callCabal2nix "effectful-plugin"
                  (filter { root = "${inputs.effectful}/effectful-plugin"; })
                  { };
                effectful-th = callCabal2nix "effectful-th"
                  (filter { root = "${inputs.effectful}/effectful-th"; }) { };
                effectful = callCabal2nix "effectful"
                  (filter { root = "${inputs.effectful}/effectful"; }) { };
              };
          }
          {
            modifiers = [ dontHaddock dontCheck ];
            extension = hfinal: hprevious:
              with hfinal; {
                tree-diff = callCabal2nix "tree-diff"
                  (filter { root = "${inputs.tree-diff}"; }) { };
              };
          }
          {
            modifiers = [ ];
            extension = hfinal: hprevious:
              with hfinal; {
                hls =
                  inputs.hls.packages.${pkgs.system}."haskell-language-server-${ghc-version}";
              };
          }
          {
            modifiers = [ ];
            extension = hfinal: hprevious:
              with hfinal; {
                fourmolu = callCabal2nix "fourmolu"
                  (filter { root = "${inputs.fourmolu}"; }) { };
              };
          }
        ];
      devShells = system:
        let
          pkgs = pkgs' system;
          hspkgs = hspkgs' system;
        in {
          default = devenv.lib.mkShell rec {
            inherit inputs pkgs;
            modules = [{
              packages = with hspkgs;
                with pkgs; [
                  git
                  ghcid
                  hello
                  hls
                  hpack
                  project
                  (ghcWithPackages (p: with p; [ cabal-install implicit-hie ]))
                ];
              enterShell = ''
                hello
                git --version
                hpack -f project/package.yaml
                gen-hie --cabal &> hie.yaml
              '';
              scripts = {
                repl-lib.exec =
                  ''ghcid -W -a -T "Lib.Top.main" -c cabal repl lib:project'';
                repl-app.exec =
                  ''ghcid -W -a -T "Top.main" -c cabal repl exe:project-exe'';
              };
              pre-commit.hooks = {
                nixfmt.enable = true;
                fourmolu.enable = true;
              };
            }];
          };
        };
      packages = system:
        let
          pkgs = pkgs' system;
          hspkgs = hspkgs' system;
        in rec {
          default = project;
          inherit (hspkgs) project;
        };
      apps = system:
        with flake-utils.lib; rec {
          default = project-exe;
          project-exe = mkApp {
            name = "project-exe";
            drv = (packages system).default;
          };
        };
    in {
      devShells = forEachSystem devShells;
      packages = forEachSystem packages;
      apps = forEachSystem apps;
    };

  nixConfig = { allow-import-from-derivation = "true"; };
}
