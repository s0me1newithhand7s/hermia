{
  inputs,
  system,
  pkgs,
  lib,
}: let
  baseKernel = import ./base.nix {
    inherit
      inputs
      system
      pkgs
      lib
      ;
  };

  llvm = pkgs.llvmPackages_latest;

  extendKernel = base: type: {
    extraConfig,
    extraMakeFlags ? [],
  }: let
    version = "${base.version}-${type}";
    modDirVersion = "${lib.versions.pad 3 base.version}-${type}";

    overridden = base.override (
      old: {
        inherit (llvm) stdenv;
        argsOverride =
          (
            old.argsOverride or {}
          )
          // {
            pname = "linux-hermia";
            inherit
              version
              modDirVersion
              ;
          };

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
          ++ extraMakeFlags
          ++ ["LOCALVERSION=-${type}"];
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
        "-mllvm -inline-threshold=365"
        "-mllvm -inlinehint-threshold=450"
        "-mllvm -unroll-threshold=150"
        "-mllvm -align-all-functions=6"
        "-mllvm -align-all-blocks=5"
        "-mllvm -hot-cold-split"
        "-mllvm -enable-dfa-jump-thread"
        "-march=${arch.march}"
      ]
      ++ lib.optional (arch ? mtune) "-mtune=${arch.mtune}";
  in [
    "HOSTCC=${lib.getExe' pkgs.clang "clang"}"
    "KCFLAGS=${lib.concatStringsSep " " kcflags}"
    "HOSTCFLAGS=-O3 -march=native"
    "LDFLAGS=-Wl,--threads=2,--icf=all,--lto-partitions=1,--strip-all,--allow-shlib-undefined"
  ];

  flavorsConfig = {
    latest = with lib.kernel; {
      CC_OPTIMIZE_FOR_PERFORMANCE = yes;
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
      PAGE_POISONING = yes;
      SECURITY_DMESG_RESTRICT = yes;
      STRICT_KERNEL_RWX = yes;
      STRICT_MODULE_RWX = yes;
      RANDOMIZE_BASE = yes;
      RANDOMIZE_MEMORY = yes;
      SLUB_DEBUG = yes;
      SLUB_DEBUG_ON = yes;
      PAGE_TABLE_ISOLATION = yes;
      RETPOLINE = yes;
      X86_IOPL_IOPERM = no;
      STRICT_DEVMEM = yes;
      COMPAT = lib.mkForce no;
      CPU_SUP_AMD = yes;
      CPU_SUP_INTEL = yes;
      X86_MPPARSE = yes;
    };

    server = with lib.kernel; {
      CC_OPTIMIZE_FOR_PERFORMANCE = yes;
      PREEMPT_LAZY = lib.mkForce yes;
      PREEMPT = lib.mkForce no;
      SCHED_CLASS_EXT = yes;
      HZ_300 = yes;
      SECURITY_LANDLOCK = yes;
      SECURITY_YAMA = yes;
      STRICT_KERNEL_RWX = yes;
      STRICT_MODULE_RWX = yes;
      PAGE_TABLE_ISOLATION = yes;
      RETPOLINE = yes;
      BPF = yes;
      BPF_SYSCALL = yes;
      BPF_JIT = yes;
      BPF_JIT_ALWAYS_ON = lib.mkForce yes;
      CPU_SUP_AMD = yes;
      CPU_SUP_INTEL = yes;
      X86_MPPARSE = yes;
    };
  };

  makeKernel = archName: flavorName:
    extendKernel baseKernel "${flavorName}-${archName}-lto" {
      extraMakeFlags = (archs.${archName}.makeFlags or []) ++ llvmFlags archs.${archName};
      extraConfig = flavorsConfig.${flavorName};
    };

  kernels = lib.listToAttrs (
    lib.concatMap
    (
      flavor:
        lib.map
        (
          arch: {
            name = "linuxPackages-hermia-${flavor}-${arch}-lto";
            value = makeKernel arch flavor;
          }
        )
        (lib.attrNames archs)
    )
    (lib.attrNames flavorsConfig)
  );
in {
  inherit
    kernels
    ;

  linuxPackages = lib.mapAttrs (_: kernel: pkgs.linuxPackagesFor kernel) kernels;
}
