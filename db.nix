{ config, pkgs, ... }:

{
  services.mysql = {
    enable = true;
    initialScript = let pass = builtins.readFile /srv/www/data/sql-poni-pass;
                    in pkgs.runCommand "prepare_users.sql" {} ''
                      cat >$out <<'EOF'
                      CREATE USER 'poni'@'localhost' IDENTIFIED BY '${pass}';
                      GRANT ALL PRIVILEGES ON *.* TO 'poni'@'localhost'
                          WITH GRANT OPTION;
                      EOF
                    '';
    rootPassword  = /srv/www/data/sql-root-pass;
    package = pkgs.mysql55;
  };
}
