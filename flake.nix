{
  description = "hand7s' flake";

  nixConfig = {
    max-jobs = "auto";
    builders = "";
    require-sigs = true;
    sandbox = true;
    sandbox-fallback = false;
    auto-optimise-store = true;

    allowed-users = [
      "@wheel"
    ];

    trusted-users = [
      "root"
      "@wheel"
    ];

    experimental-features = [
      "nix-command"
      "flakes"
    ];

    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://chaotic-nyx.cachix.org"
      "https://hyprland.cachix.org"
      "https://devenv.cachix.org"
      "https://ghostty.cachix.org"
      "https://yazi.cachix.org"
      "https://helix.cachix.org"
      "https://zellij.cachix.org"
      "https://attic.xuyh0120.win/lantian"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    "cachix" = {
      type = "github";
      owner = "cachix";
      repo = "cachix";

      inputs = {
        "nixpkgs" = {
          follows = "nixpkgs";
        };
      };
    };

    "devenv" = {
      type = "github";
      owner = "cachix";
      repo = "devenv";

      inputs = {
        "nixpkgs" = {
          follows = "nixpkgs";
        };
      };
    };

    "devenv-root" = {
      flake = false;
      url = "file+file:///dev/null";
    };

    "flake-parts" = {
      type = "github";
      owner = "hercules-ci";
      repo = "flake-parts";
    };

    "git-hooks-nix" = {
      type = "github";
      owner = "cachix";
      repo = "git-hooks.nix";

      inputs = {
        "nixpkgs" = {
          follows = "nixpkgs";
        };
      };
    };

    "nixpkgs" = {
      type = "github";
      owner = "nixos";
      repo = "nixpkgs";
      ref = "nixpkgs-unstable";
    };

    "nixpkgs-master" = {
      type = "github";
      owner = "nixos";
      repo = "nixpkgs";
      ref = "master";
    };

    "treefmt-nix" = {
      type = "github";
      owner = "numtide";
      repo = "treefmt-nix";

      inputs = {
        "nixpkgs" = {
          follows = "nixpkgs";
        };
      };
    };
  };

  outputs = {self, ...} @ inputs:
    inputs."flake-parts".lib.mkFlake {
      inherit
        inputs
        self
        ;
    } {
      debug = true;

      # x86_64-linux only
      systems = [
        "x86_64-linux"
      ];

      imports = [
        inputs."treefmt-nix".flakeModule
        inputs."devenv".flakeModule
        inputs."git-hooks-nix".flakeModule
      ];

      perSystem = {
        config,
        system,
        pkgs,
        lib,
        ...
      }: let
        flavors = import ./lib/flavors.nix {
          inherit
            inputs
            system
            pkgs
            lib
            ;
        };
      in {
        packages = flavors.kernels;
        legacyPackages = flavors.linuxPackages;

        # numtide/treefmt-nix, treefmt integrated into nix
        treefmt = {
          flakeFormatter = true;

          programs = {
            "alejandra" = {
              enable = true;
              priority = 1;
              includes = [
                "*.nix"
              ];
            };

            "statix" = {
              enable = true;
              priority = 1;
              includes = [
                "*.nix"
              ];
            };

            "deadnix" = {
              enable = true;
              priority = 1;
              includes = [
                "*.nix"
              ];
            };
          };

          settings = {
            global = {
              on-unmatched = "warn";
              excludes = [
                ".gitignore"
              ];
            };
          };
        };

        # cachix/git-hooks-nix, pre-commit-hooks integrated into nix
        pre-commit = {
          check = {
            enable = true;
          };

          settings = {
            enable = true;
            package = pkgs.prek;
            gitPackage = pkgs.git;

            hooks = {
              "alejandra" = {
                enable = true;
                settings = {
                  verbosity = "quiet";
                  check = true;
                };
              };

              "deadnix" = {
                enable = true;
                settings = {
                  edit = false;
                };
              };

              "statix" = {
                enable = true;
              };

              "gitlint" = {
                enable = true;
              };
            };
          };
        };

        # cachix/devenv, basically a devShells, even better than numtide/devshells
        devenv = {
          shells = {
            "default" = {
              enterShell = config.pre-commit.shellHook;

              enterTest = ''
                prek run --all-files --fail-fast
              '';

              cachix = {
                enable = true;

                pull = [
                  "nix-community"
                  "devenv"
                ];
              };

              packages =
                [
                  pkgs.cachix
                  config.treefmt.build.wrapper
                ]
                ++ config.pre-commit.settings.enabledPackages;
            };
          };
        };
      };

      flake = {
        overlays.default = final: _prev:
          (import ./lib/flavors.nix {
            inherit inputs;
            inherit (final) system pkgs lib;
          }).linuxPackages;
      };
    };
}
