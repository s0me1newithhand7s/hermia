{
  baseKernel,
  pkgs,
  lib,
}: let
  llvm = pkgs.llvmPackages_latest;

  extendKernel = base: nameSuffix: {
    extraConfig,
    extraMakeFlags ? [],
  }: let
    overridden = base.override (
      old: {
        inherit (llvm) stdenv;

        structuredExtraConfig =
          (
            old.structuredExtraConfig or {}
          )
          // extraConfig;
      }
    );
  in
    overridden.overrideAttrs (
      old: {
        pname = "linux-hermia-${nameSuffix}";

        nativeBuildInputs =
          (
            old.nativeBuildInputs or []
          )
          ++ [
            llvm.llvm
            llvm.lld
          ];

        makeFlags =
          (
            old.makeFlags or []
          )
          ++ extraMakeFlags;
      }
    );

  archs = {
    v3 = {
      march = "x86-64-v3";
      makeFlags = ["V=1"];
    };
    znver3 = {
      march = "znver3";
      mtune = "znver3";
    };
  };

  llvmFlags = arch: let
    kcflags =
      [
        "-O3"
        "-mllvm -inline-threshold=600"
        "-mllvm -inlinehint-threshold=1000"
        "-mllvm -unroll-threshold=300"
        "-mllvm -align-all-functions=6"
        "-mllvm -align-all-blocks=5"
        "-march=${arch.march}"
      ]
      ++ lib.optional (arch ? mtune) "-mtune=${arch.mtune}";
  in [
    "HOSTCC=${pkgs.clang}/bin/clang"
    "KCFLAGS=${lib.concatStringsSep " " kcflags}"
    "HOSTCFLAGS=-O3 -march=native"
  ];

  flavorsConfig = {
    latest = with lib.kernel; {
      CC_OPTIMIZE_FOR_PERFORMANCE = yes;
      LTO_CLANG_THIN = option yes;
      DRM = yes;
      DRM_AMDGPU = yes;
      DRM_AMD_DC = yes;
      NTSYNC = yes;
      I2C_CHARDEV = yes;
      SCHED_CLASS_EXT = yes;
      PREEMPT = lib.mkForce yes;
      PREEMPT_LAZY = lib.mkForce no;
      HZ_1000 = lib.mkForce yes;
      BPF = yes;
      BPF_SYSCALL = yes;
      BPF_JIT = yes;
      BPF_JIT_ALWAYS_ON = lib.mkForce yes;
    };

    hardened = with lib.kernel; {
      CC_OPTIMIZE_FOR_PERFORMANCE = yes;
      LTO_CLANG_THIN = option yes;
      DRM = yes;
      DRM_AMDGPU = yes;
      SCHED_CLASS_EXT = yes;
      PREEMPT = lib.mkForce yes;
      PREEMPT_LAZY = lib.mkForce no;
      INIT_ON_ALLOC_DEFAULT_ON = yes;
      INIT_ON_FREE_DEFAULT_ON = yes;
      SLAB_MERGE_DEFAULT = no;
      SECURITY_LANDLOCK = yes;
      SECURITY_YAMA = yes;
    };

    server = with lib.kernel; {
      LTO_CLANG_THIN = yes;
      PREEMPT_LAZY = lib.mkForce yes;
      PREEMPT = lib.mkForce no;
      HZ_100 = yes;
    };
  };

  makeKernel = archName: flavorName:
    extendKernel baseKernel "${flavorName}-${archName}-lto" {
      extraMakeFlags = (archs.${archName}.makeFlags or []) ++ llvmFlags archs.${archName};
      extraConfig = flavorsConfig.${flavorName};
    };
in
  lib.listToAttrs (
    lib.concatMap
    (
      flavor:
        lib.map
        (
          arch: {
            name = "linuxPackages-hermia-${flavor}-${arch}-lto";
            value = pkgs.linuxPackagesFor (makeKernel arch flavor);
          }
        )
        (lib.attrNames archs)
    )
    (lib.attrNames flavorsConfig)
  )
