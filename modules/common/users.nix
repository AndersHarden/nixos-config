{ ... }:

{
  users.users.anders = {
    isNormalUser = true;
    description = "Anders Hardenborg";
    extraGroups = [ "wheel" "kvm" ];
  };
}
