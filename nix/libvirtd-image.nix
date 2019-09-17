{ system ? builtins.currentSystem, size ? "10" }:
let
  pkgs = import <nixpkgs> {};
  config = (import <nixpkgs/nixos/lib/eval-config.nix> {
    inherit system;
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

      services.qemuGuest.enable = true;

      # thanks to clever
      # https://github.com/cleverca22/not-os/blob/master/runit.nix#L62-L66
      # https://github.com/cleverca22/not-os/blob/d55aa5ca2d3795d7151ac8a4099c79bf506a2aa4/qemu.nix#L4
      systemd.services.hwrng = {
        # after = [ "network.target" "sound.target" ];
        description = "Hardware generator ";
        # eventually sshd ?
        # wantedBy = optional (!cfg.startWhenNeeded) "multi-user.target";
        # wantedBy = optional (!cfg.startWhenNeeded) "multi-user.target";

        serviceConfig = {
          # User = "${cfg.user}";
          ExecStart = ''
            #!/bin/sh
            export PATH=$PATH:${pkgs.rng_tools}/bin
            exec rngd -r /dev/hwrng
          '';
          # Type = "notify";
          # LimitRTPRIO = 50;
          # LimitRTTIME = "infinity";
          # ProtectSystem = true;
          # NoNewPrivileges = true;
          # ProtectKernelTunables = true;
          # ProtectControlGroups = true;
          # ProtectKernelModules = true;
          # RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX AF_NETLINK";
          # RestrictNamespaces = true;
        };
      };

    } ];
  }).config;

in pkgs.vmTools.runInLinuxVM (
  pkgs.runCommand "libvirtd-image"
    { memSize = 768;
      preVM =
        ''
          mkdir $out
          diskImage=$out/image
          ${pkgs.vmTools.qemu}/bin/qemu-img create -f qcow2 $diskImage "${size}G"
          mv closure xchg/
        '';
      postVM =
        ''
          mv $diskImage $out/disk.qcow2
        '';
      buildInputs = [ pkgs.utillinux pkgs.perl ];
      exportReferencesGraph =
        [ "closure" config.system.build.toplevel ];
    }
    ''
      # Create a single / partition.
      ${pkgs.parted}/sbin/parted /dev/vda mklabel msdos
      ${pkgs.parted}/sbin/parted /dev/vda -- mkpart primary ext2 1M -1s

      # Create an empty filesystem and mount it.
      ${pkgs.e2fsprogs}/sbin/mkfs.ext4 -L nixos /dev/vda1
      ${pkgs.e2fsprogs}/sbin/tune2fs -c 0 -i 0 /dev/vda1
      mkdir /mnt
      mount /dev/vda1 /mnt

      # The initrd expects these directories to exist.
      mkdir /mnt/dev /mnt/proc /mnt/sys
      mount --bind /proc /mnt/proc
      mount --bind /dev /mnt/dev
      mount --bind /sys /mnt/sys

      # Copy all paths in the closure to the filesystem.
      storePaths=$(perl ${pkgs.pathsFromGraph} /tmp/xchg/closure)

      echo "filling Nix store..."
      mkdir -p /mnt/nix/store
      set -f
      cp -prd $storePaths /mnt/nix/store/

      mkdir -p /mnt/etc/nix
      echo 'build-users-group = ' > /mnt/etc/nix/nix.conf

      # Register the paths in the Nix database.
      printRegistration=1 perl ${pkgs.pathsFromGraph} /tmp/xchg/closure | \
          chroot /mnt ${config.nix.package.out}/bin/nix-store --load-db

      # Create the system profile to allow nixos-rebuild to work.
      chroot /mnt ${config.nix.package.out}/bin/nix-env \
          -p /nix/var/nix/profiles/system --set ${config.system.build.toplevel}

      # `nixos-rebuild' requires an /etc/NIXOS.
      mkdir -p /mnt/etc/nixos
      touch /mnt/etc/NIXOS

      # `switch-to-configuration' requires a /bin/sh
      mkdir -p /mnt/bin
      ln -s ${config.system.build.binsh}/bin/sh /mnt/bin/sh

      # Generate the GRUB menu.
      ln -s vda /dev/sda
      chroot /mnt ${config.system.build.toplevel}/bin/switch-to-configuration boot

      umount /mnt/proc /mnt/dev /mnt/sys
      umount /mnt
    ''
)

