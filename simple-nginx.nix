let pkgs = import <nixpkgs> {};
    lib = pkgs.lib;
    fcgiParams = "include ${pkgs.nginx}/conf/fastcgi_params;";
in rec {
  # Export the "include fastcgi<etc.>" line so the full "pkgs.blah" doesn't
  # need repeating in configs that use this module.
  fastcgiParams = fcgiParams;

  # Some nice default rules for php blocks if you don't have particular needs.
  phpSimpleRules = [ "try_files $uri =404;"
                     "${fcgiParams}"
                     "fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;"
                     "fastcgi_pass unix:/run/phpfpm/nginx;"
                   ];

  # The meat of simple-nginx, turns our config into a nix config
  # Entries are added to /etc/hosts for all served hostnames iff addHosts == true,
  # as a testing helper. Set it to false unless really necessary.
  mkServerConf = { addHosts ? false,
                   rtmp ? { enable = false; },
                   sites ? []
                 } :
    let rtmpConf = if rtmp.enable
                      then ''
                        rtmp {
                          server {
                            listen 1935;
                            chunk_size 4096;
                            
                            application live {
                              live on;
                              on_publish http://${rtmp.hostname}/auth.php;
                            }
                          }
                        }
                      ''
                      else "";
        rtmpSiteRoot = pkgs.runCommand "rtmp-site" {} ''
                         mkdir -p "$out"
                         cd "$out"
                         cat <<'EOF' >auth.php
                         ${import ./rtmp/auth.php.nix rtmp.username rtmp.password}
                         EOF
                         cat <<'EOF' >index.html
                         ${builtins.readFile ./rtmp/index.html}
                         EOF
                       '';
        rtmpSiteHtpasswd = pkgs.runCommand "rtmp-htpasswd" {
                             user = rtmp.username;
                             pass = rtmp.password;
                             ssl = "${pkgs.openssl}/bin/openssl";
                           } ''
                               salt="$ssl rand -base64 12"
                               hash="$(echo -n "$pass$salt" | $ssl dgst -binary -sha1 | sed 's#$#'"$salt"'#' | base64)"
                               echo "$user:{SSHA}$hash" > $out
                             '';
        rtmpSiteConf = if rtmp.enable
                          then ''
                            server {
                              listen 80;
                              server_name ${rtmp.hostname};
                              root ${rtmpSiteRoot};
                              index index.html;
                              
                              location /auth.php {
                                ${fcgiParams}
                                fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                                fastcgi_pass unix:/run/phpfpm/nginx;
                              }

                              location /control {
                                auth_basic_user_file ${rtmpSiteHtpasswd};
                                auth_basic "rtmp live";
                                rtmp_control all;
                              }
                            }
                          ''
                          else "";
    # The meat of the meat! Takes one site, and generates a server{} block or
    # two for it.
        makeConfig = { hostname,  # The main hostname - doubles as the path if 'path'
                                  # is left as the default ("").
                       extraHostnames ? [],  # Any other hostnames the site should be
                                             # served on.
                       regexDomain ? false,  # Turn the domain into a regex that
                                             # matches subdomains and stores the 
                                             # specific subdomain (with dot) to
                                             # $subdomain?
                       path ? "",  # The path under /srv/www to use as document root.
                       ssl ? null,  # The site will be served using SSL with a
                                    # redirect from :80, using ssl.cert and ssl.key
                                    # as the certificate and key, iff ssl is non-null.
                       indexes ? ["index.html" "index.htm"],  # Self-explanatory.
                       preConf ? [],  # Lines of configuration to insert before auto-
                                      # generated location{} blocks.
                       locs ? {},  # Custom location{} blocks, using the key as the
                                   # location itself, and the value as a list of lines
                                   # that go in the block.
                       postConf ? [] } :  # Like preConf, but after locations.
        let serverNames = if regexDomain
                             then ''~(?<subdomain>.+\.|)${hostname}''
                             else lib.concatStringsSep " "
                                    (lib.singleton hostname ++ extraHostnames);
            mainPort = if ssl == null
                          then "80"
                          else "443 ssl";
            portAnnot = if hostname == "_"
                           then " default"
                           else "";
            sslRedirect = if ssl == null
                             then ""
                             else ''
                                    server {
                                      listen 80${portAnnot};
                                      server_name ${serverNames};
                                      return 301 https://$server_name$request_uri;  # enforce https
                                    }
                                  '';
            sslConfig = if ssl == null
                           then ""
                           else ''
                                  ssl_certificate ${ssl.cert};
                                  ssl_certificate_key ${ssl.key};
                                '';
            sitePath = if path == ""
                          then (if hostname == "_" then "default" else hostname)
                          else path;
            mkLocation = name : value : ''
                                          location ${name} {
                                            ${lib.concatStringsSep "\n" value}
                                          }
                                        '';
        in ''
             ${sslRedirect}
             
             server {
               ${sslConfig}
            
               listen ${mainPort}${portAnnot};
               server_name ${serverNames};
               root /srv/www/${sitePath};
               index ${lib.concatStringsSep " " indexes};
               
               ${lib.concatStringsSep "\n" preConf}
               
               ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkLocation locs)}
               
               ${lib.concatStringsSep "\n" postConf}
             }
           '';
    in {
      # Ensure the service is on and using our config (including mime.types
      # to avoid weirdness).
      services.nginx = {
        enable = true;
        user = "www-data";
        group = "www-data";
        config = ''
          events {
            use epoll;
          }
          http {
            include ${pkgs.nginx}/conf/mime.types;
            
            auth_basic_user_file /srv/www/.htpasswd;
            
            autoindex_exact_size off;  # seriously who even wants exact bytes?
            
            geoip_country /srv/www/data/GeoIP.dat;
            geoip_city    /srv/www/data/GeoLiteCity.dat;

            ${rtmpSiteConf}
            
            ${lib.concatMapStrings makeConfig sites}
          }

          ${rtmpConf}
        '';
      };

      # Need a www-data user for our services.
      users.extraUsers."www-data" = {
        uid = 33;
        group = "www-data";
        home = "/srv/www";
        createHome = true;
        useDefaultShell = true;
      };
      users.extraGroups."www-data".gid = 33;

      # PHP-FPM, including some pool config and php config via that.
      services.phpfpm.poolConfigs.nginx = ''
        listen = /run/phpfpm/nginx
        listen.owner = www-data
        listen.group = www-data
        listen.mode = 0660
        user = www-data
        pm = dynamic
        pm.max_children = 75
        pm.start_servers = 10
        pm.min_spare_servers = 5
        pm.max_spare_servers = 20
        pm.max_requests = 500

        php_flag[display_errors] = off
        php_admin_value[error_log] = "/run/phpfpm/php-fpm.log"
        php_admin_flag[log_errors] = on
        php_value[date.timezone] = "UTC"

        env[PATH] = /srv/www/bin:/var/setuid-wrappers:/srv/www/.nix-profile/bin:/srv/www/.nix-profile/sbin:/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/run/current-system/sw/bin/run/current-system/sw/sbin
      '';

      # Add the extra testing hosts iff addHosts == true.
      networking.extraHosts = if addHosts
                              then let serverNames = lib.filter (h : h != "_") (lib.concatMap (s : lib.singleton s.hostname ++ s.extraHostnames or []) sites);
                                   in lib.concatMapStrings (servName: ''
                                        127.0.0.1	${servName}
                                      '') serverNames
                              else "";
      networking.firewall.allowedTCPPorts = [ 80 443 ]
                                         ++ (if rtmp.enable
                                                then [ 1935 ]
                                                else []);
    };

  ## Site types, preset many values to sane, general defaults.
  # Bog-standard site, with some nice handling for user-supplied pre/post/locs
  # configuration, without forcing the internal list approach on them.
  basicSite = hostname : extraHostnames : { pre ? "", post ? "", locs ? {} } : {
    hostname = hostname;
    extraHostnames = extraHostnames;
    indexes = ["index.html" "index.htm"];
    preConf = lib.splitString "\n" pre;
    locs = {
      "~ \\.php\$" = ["return 403;"];  # Refuse access to PHP files unless this is
                                       # removed or outranked by a more specific rule.
    } // lib.mapAttrs (n : v : lib.splitString "\n" v) locs;
    postConf = lib.splitString "\n" post;
  };
  # A simple redirect, just creates a 301/302 block with the supplied target.
  redirect = hostname : extraHostnames : perm : redirectTo : {
    hostname = hostname;
    extraHostnames = extraHostnames;
    preConf = let code = if perm then 301 else 302;
                    in ["return ${toString code} ${redirectTo};"];
  };
  # A more interesting redirect, handles switching domains while preserving all
  # other elements of the URL.
  domainRedirect = from : to : {
    hostname = from;
    regexDomain = true;
    preConf = [ "set $domain ${to};"
                "return 301 $scheme://$subdomain$domain$request_uri;" ];
  };

  ## Site modifiers - take an existing site and change specific things.
  # Serve the site from a different subdirectory of /srv/www
  withPath = path : site : site // {
    path = path;
  };
  # Add index.php to indexes, and switch out "return 403;" for some rules that
  # actually handle running PHP.
  withPhp = site : site // {
    indexes = ["index.php"] ++ site.indexes;
    locs = site.locs // {
      "~ \\.php\$" = (lib.remove "return 403;" site.locs."~ \\.php\$")
                  ++ phpSimpleRules;
    };
  };
  # Add index.php to indexes, but remove the php location block entirely,
  # so the user-supplied config can supply its own handling for PHP files.
  withCustomPhp = site : site // {  # remove default php loc
    indexes = ["index.php"] ++ site.indexes;
    locs = lib.filterAttrs (n : v : n != "~ \\.php\$") site.locs;
  };
  # Adds the provided cert and key paths to the site config's ssl config.
  withSsl = cert : key : site : site // {
    ssl = {
      cert = cert;
      key = key;
    };
  };
  # Enable autoindex for all provided paths.
  withIndexes = ixLocs : site : site // {
    locs = let newLocs = lib.filter (l : ! lib.hasAttr l site.locs) ixLocs;
      in (lib.mapAttrs (loc : rules :
                          if lib.elem loc ixLocs then rules ++ ["autoindex on;"] else rules)
                        site.locs)
         // lib.listToAttrs (map (l : lib.nameValuePair l ["autoindex on;"]) newLocs);
  };
  # Enable h5ai for a site without enabling PHP globally if it isn't already.
  # TODO: Figure out how to actually install h5ai if it's not present. Right now
  #       it has to be installed in the site directory manually before this
  #       does anything.
  withH5ai = site : site // {
    indexes = site.indexes ++ ["/_h5ai/server/php/index.php"];
    locs = site.locs // {
      "= /_h5ai/server/php/index.php" = phpSimpleRules;
    };
  };
  # Attempt to always serve the exact same path for all requests to the site.
  singlePage = pagePath : site : site // {
    indexes = [pagePath] ++ site.indexes;
    preConf = ["error_page 404 ${pagePath};"] ++ site.preConf;
  };
}
