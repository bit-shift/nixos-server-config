{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./web.nix
    ];

  boot = {
    cleanTmpDir = true;
    loader.grub = {
      enable = true;
      version = 1;
      extraPerEntryConfig = "root (hd0)";
      device = "nodev";
    };
  };

  networking = {
    hostName = "eos";
    firewall = {
      enable = true;
      allowedTCPPorts = [ 80 443 ];
      allowedUDPPortRanges = [ { from = 60000; to = 61000; }  # mosh
                             ];
    };
  };

  time.timeZone = "UTC";

  i18n = {
    consoleFont = "lat9w-16";
    consoleKeyMap = "us";
    defaultLocale = "en_GB.UTF-8";
  };

  # List packages installed in system profile. To search by name, run:
  # -env -qaP | grep wget
  #
  # dummied out with syntax because it makes me uneasy, but I want to know what it was set as if that passes
  ## environment.systemPackages = with pkgs; [
  environment.systemPackages = [
    pkgs.wget
    pkgs.vim
    pkgs.git
  ];

  services = {
    openssh = {
      enable = true;
      ports = [ 9022 ];
      passwordAuthentication = false;
    };
    sshd.usePAM = false;

    locate = {
      enable = true;
      period = "15 8 * * *";  # 8:15 am UTC, should be low-activity time
    };
  };

  users = {
    mutableUsers = false;
    extraUsers = {
      root = {
        passwordFile = "/root/.passwd";
        hashedPassword = null;  # must be unset because security.initialRootPassword implies it, and it supersedes passwordFile 
      };
      bitshift = {
        name = "bitshift";
        uid = 1000;
        group = "users";
        extraGroups = [ "wheel" ];
        createHome = true;
        home = "/home/bitshift";
        useDefaultShell = true;
        openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3PyHwNf19brgX6dFQFYp2cnQO0n0vEdiHuW71lWzsql4C4oH1QUclI2WCdc+rpugiPuDlTJfGjy1CoDNYFCBXGo56nR+JBcEQk+EPsZ6UnbwwxUruzKkuPK8N3pIKU/IZq8QzebBh1pX6VQSa3P22QfJ7IqddRurC/WghsLgZOCquu+Qgj+q1BZhEsgj/QZZ5q6E8s0t7zsUZQdjRwWSjjtvUDGGOIm3ABkJa9hVZ8S5QNnnHQEnpr+4U0fXaWJ5Uze3ZwpeqiubsAAE7nKH/TA6mnPggZV0AS5YaHPFdRCfMjCrmy6Twue6/gVo5UBCdC1W83qY0NOZRPgakc1Bt bitshift@ubuntu"
                                        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDed7UE/5R9HRRUVTGoO5hly1bt+4hbE16zptCUcO40VhNx7KlVIY+aYE1tCkAmFnCqemu7axaSLcyFhTHrKRsdMa3oFyhj84Y1wwOVog2bEk5xqM0LUOGPuM3X5BsOoX3dJTsi16hq73vSLNuvye5ctaSP+9H3aODqkI18hGBO5Zgrj9LVg33ZyLmq4wQXFAwmWBW22BLwsM4bIs/59Ea2VXegarBHL4FbaL6Rt7OyVT168tdGFLQZcxH2ph2SIbfv1L+D+8cUwKlE5zPLv03mYqulnt/DhvBubZ78NvYVjbNRv35YmmlDjYDvNYkzlBj3yRiDFlRXSZPbzHz9WMKV JuiceSSH"
                                      ];
      };
    };
    defaultUserShell = "/run/current-system/sw/bin/bash";
  };

  security = {
    sudo.wheelNeedsPassword = false;
  };
}
