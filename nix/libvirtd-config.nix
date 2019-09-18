{ config, lib, pkgs,  ... }:
{
    modules = [ {
      imports = [
        <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
      ];
      fileSystems."/".device = "/dev/disk/by-label/nixos";

      boot.kernelParams = [ "earlycon=ttyS0" "console=ttyS0" ];

      boot.loader.grub.version = 2;
      boot.loader.grub.device = "/dev/vda";
      boot.loader.timeout = 0;

      services.openssh.enable = true;
      services.openssh.startWhenNeeded = false;

      # to prevent issues
      systemd.services.sshd.serviceConfig.TimeoutStartSec = "2s";
      services.openssh.extraConfig = "UseDNS no";

      boot.initrd.availableKernelModules = [
        "ata_piix" "uhci_hcd"
        "virtio" "virtio_pci" "virtio_net" "virtio_rng" "virtio_blk" "virtio_console"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      # should print everything (more than 8 should be useless)
      boot.consoleLogLevel=8;

      # just to help debug
      users.users.root = {
        # once can set initialHashedPassword too
        initialPassword = "test";
        # import basetools
        # openssh.authorizedKeys.keyFiles = [ ./keys/root_gitolite.pub ];
      };

      services.qemuGuest.enable = true;

      # qemu-guest disables rngd (pkgs.lib.mkForce)
      security.rngd.enable = true;
      security.rngd.debug = true;
    } ];
}
