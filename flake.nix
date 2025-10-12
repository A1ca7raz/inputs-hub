rec {
  description = "A1ca7raz's Inputs Hub";

  inputs = {
    # Basic flakes
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-lib.url = "github:NixOS/nixpkgs/nixos-unstable?dir=lib";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    };
    flake-utils.url = "github:numtide/flake-utils";

    # Dependencies of 3rd-party flakes
    crane.url = "github:ipetkov/crane";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 3rd-party flakes
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
      inputs.flake-utils.follows = "flake-utils";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dns = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    kwin-effects-forceblur = {
      url = "github:taj-ny/kwin-effects-forceblur";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };
    kwin-gestures = {
      url = "github:taj-ny/kwin-gestures";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.pre-commit-hooks-nix.follows = "";
      inputs.crane.follows = "crane";
      inputs.rust-overlay.follows = "rust-overlay";
      inputs.flake-compat.follows = "flake-compat";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "flake-utils/systems";
    };
  };

  # 1. export nixos modules from external flakes
  # 2. add packages from external flakes
  # 3. provide helper modules
  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    let
      systems = [
        "x86_64-linux"
      ];
    in
    flake-utils.lib.eachSystem systems (system:
      let
        pkgs = import nixpkgs {
          config.allowUnfree = true;
          inherit system;
        };

        mkBundle = name: apps: {
          "bundle_${name}" = pkgs.stdenv.mkDerivation {
            name = "${name}-bundle";
            srcs = with builtins; filter isAttrs (attrValues apps);

            phases = [ "installPhase" ];
            installPhase = ''
              mkdir -p $out
              for _src in $srcs; do
                [[ -e "$out/$(basename $_src)" ]] || ln -s "$_src"  "$out/$(basename $_src)"
              done
            '';
          };
        };
      in rec {
        # Packages from external flakes
        legacyPackages = {
          kwin-effects-forceblur = pkgs.kdePackages.callPackage (inputs.kwin-effects-forceblur + "/nix/package.nix") {};
          kwin-gestures = pkgs.kdePackages.callPackage (inputs.kwin-gestures + "/nix/package-kwin.nix") {};
        };

        # With packages from nixpkgs that request cache
        # Will be used by CI
        packages = {
          inherit (pkgs)
            obsidian
            unrar
            veracrypt
            wpsoffice
            teamspeak3
            teamspeak_server
          ;
          # inherit (pkgs.jetbrains)
          #   goland
          #   datagrip
          #   rider
          # ;
        } // legacyPackages
          // mkBundle "lanzaboote" inputs.lanzaboote.packages.${system}
          // mkBundle "nix-index-database" inputs.nix-index-database.packages.${system}
          // mkBundle "sops-nix" inputs.lanzaboote.packages.${system}
        ;

        devShells.default = pkgs.mkShell {};
      }
    ) // {
      overlays.external = final: prev: self.packages.x86_64-linux;

      nixosModules = with inputs; {
        colmena = colmena.nixosModules.deploymentOptions;
        disko = disko.nixosModules.disko;
        home-manager = home-manager.nixosModules.home-manager;
        impermanence = impermanence.nixosModules.impermanence;
        lanzaboote = lanzaboote.nixosModules.lanzaboote;
        nix-index-database = nix-index-database.nixosModules.nix-index;
        sops = sops-nix.nixosModules.sops;

        helper = {
          # Add NUR substituters
          nix.settings = nixConfig;
          # Add custom packages
          nixpkgs.overlays = [
            self.overlays.external
          ];
        };
      };

      homeModules = with inputs; {
        sops = sops-nix.homeManagerModule;
      };
    };

  nixConfig = {
    extra-substituters = [
      # "https://cache.garnix.io"
      "https://a1ca7raz-nur.cachix.org"
    ];

    extra-trusted-public-keys = [
      # "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "a1ca7raz-nur.cachix.org-1:twTlSh62806B8lfG0QQzge4l5srn9Z8/xxyAFauOZnQ="
    ];
  };
}
