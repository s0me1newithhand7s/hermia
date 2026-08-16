{
  inputs,
  system,
  pkgs,
  lib,
}: let
  llvm = pkgs.llvmPackages_latest;
in
  inputs."nixpkgs-master".legacyPackages.${system}.linux_latest.override {
    inherit (llvm) stdenv;

    structuredExtraConfig = with lib.kernel; {
      CC_IS_CLANG = yes;
      GCC_VERSION = freeform "0";

      "64BIT" = yes;
      X86_64 = yes;
      EXPERT = yes;
      PRINTK = yes;
      RUST = lib.mkForce (option no);
      DRM_NOVA = lib.mkForce (option no);
      NOVA_CORE = lib.mkForce (option no);
      DRM_PANIC_SCREEN_QR_CODE = lib.mkForce (option yes);

      MODULES = yes;
      MODULE_SIG = no;
      BLK_DEV_DM = module;
      DM_CRYPT = module;

      VFAT_FS = yes;
      BTRFS_FS = module;

      NVME_CORE = yes;
      BLK_DEV_NVME = yes;
      NVME_AUTH = lib.mkForce yes;
      USB_SUPPORT = yes;
      USB_XHCI_HCD = yes;
      HID = yes;
      HID_GENERIC = yes;
      USB_HID = yes;
      NETDEVICES = yes;
      ETHERNET = yes;
      NET_VENDOR_REALTEK = yes;
      R8169 = yes;
      NET = yes;
      INET = yes;
      PACKET = yes;

      CRYPTO_AES = yes;
      CRYPTO_AES_NI_INTEL = yes;
      CRYPTO_XTS = yes;
      CRYPTO_SHA256 = yes;
      CRYPTO_SHA512 = yes;

      TCG_TPM = yes;
      TCG_TIS = yes;
      TCG_CRB = yes;
    };

    extraMakeFlags = [
      "LLVM=1"
      "LLVM_IAS=1"
      "LD=${lib.getExe' llvm.lld "ld.lld"}"
      "AR=${lib.getExe' llvm.llvm "llvm-ar"}"
      "NM=${lib.getExe' llvm.llvm "llvm-nm"}"
      "OBJCOPY=${lib.getExe' llvm.llvm "llvm-objcopy"}"
      "OBJDUMP=${lib.getExe' llvm.llvm "llvm-objdump"}"
      "STRIP=${lib.getExe' llvm.llvm "llvm-strip"}"
      "READELF=${lib.getExe' llvm.llvm "llvm-readelf"}"
    ];
  }
