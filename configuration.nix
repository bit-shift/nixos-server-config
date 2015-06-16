{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./web.nix
      ./db.nix
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

  nixpkgs.config.allowUnfree = true;

  networking = {
    hostName = "eos";
    firewall = {
      enable = true;
      allowedTCPPorts = [ 5222 5269 5280 7777 8080 10011 30033 ];
      allowedUDPPorts = [ 9987 ];
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

    ejabberd = {
      enable = true;
      virtualHosts = ''"bigmacintosh.net","localhost"'';
    };

    teamspeak3.enable = true;
  };

  virtualization.docker.enable = true;

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
                                        "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEApm1KTXGyp+9zorCtEIpMO7Y3bOw+7jM+xEdSa+a+cgfmSt6SktV1u/Ir1eQjY88x3AKvzZFkl+27CvZRec+fE4uAFe0IouGvVmcpAC1M7tYviXoALaNULZ0BVsl82+hQPuVdOk6l9nAnrV054h55F4kYvpQIJLfNSoeQeu57dKMBBHUQ1ebbDt/CV4TdrOokxAy68nCSPmkA+TuYRqe1PmgmiLpdoFxt7m7TCQTaRP9LbEI79s9QOMhuAu/sNqBBMfzikAHTiKA7LXXChnpEuuZyJq4s8wrPnM5wDkEHdn+MxaY0Yf+bE5S7zezP1xo/hx41RpOdCWK/52iGAud/LQ== bitshift@zylphe"
                                        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2q8mueBKv7HipKYXx1sjF750NRqNeSaE/AxU7Z2dwENW9zo1tEw9jG6FxEbbTIXbtD/IyBhoDdYP+Yfh9LBE20yKoQx2f1XBYa2rmBKtiK6bUfDqNQC8bM9A/1AR15YdsxcC3KBxlReh7m67WFkrtqnCE+dU0Rc3PZEP+ZM0xMxLJtFWTQaXa+yX0Wdlq/OwkWJTKv1xvIAumS4e9VVwYf5rTu8F8BgCKaGvXeCjzVaXiNJxjb4fhTtynP/hNQPdE3KG9P0PXxZM/VSeu2JB1F101gayhNR0i+5KEMtykQ+rh6GjCrscM1VjfGA9EGdz/PMNnWZ29xzZTvwopQMaF pi@salamander"
                                        "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAsH7JJIJE3EFXuQNQ7tMWx8OUZJ7LfMX91iXdJUt1ixFKA1w3WUIFcunxgAXkL2dLk1VmnNOuFO+dpdYgfjDn1me/lOLxCKafE+B07RsrAx9z0Ji6X/tL9P6NB3xxdcXubuX3vtVnyg8JA9aYv9jjpljWTlprj7KrhltUrwcNMpbIZj0nglVQZqI1Nrv+Zs6ExlQAf5MIQKDa7AifxPX3/3c91UU94p/6mXViqo8TNUw5LwDhPy6XfPX+Kl3dKrNFyvTxom8x59jSQnqjmM7HXYKQI0RJw0zbU6l5z0ZjJS6VV6YvJOIWrpr32eUBlMpuoDOD3iAtoOI9tlMJ8/vHQw== sylphacer"
                                      ];
      };
    };
    defaultUserShell = "/run/current-system/sw/bin/bash";
  };

  security = {
    sudo.wheelNeedsPassword = false;
  };
}
