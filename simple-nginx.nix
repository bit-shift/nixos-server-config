{ pkgs, ... } :

let lib = pkgs.stdenv.lib;
    fcgiParams = "include ${pkgs.nginx}/conf/fastcgi_params;";
in rec {
  fastcgiParams = fcgiParams;

  serveSites = addHosts : sites :
    let makeConfig = { hostname,
                       extraHostnames ? [],
                       regexDomain ? false,
                       path ? "",
                       ssl ? null,
                       indexes ? ["index.html" "index.htm"],
                       preConf ? [],
                       locs ? {},
                       postConf ? [] } :
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
            
            ${lib.concatMapStrings makeConfig sites}
          }
        '';
      };

      users.extraUsers."www-data" = {
        uid = 33;
        group = "www-data";
        home = "/srv/www";
        createHome = true;
        useDefaultShell = true;
      };
      users.extraGroups."www-data".gid = 33;

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
        php_admin_value[error_log] = /run/phpfpm/php-fpm.log
        php_admin_flag[log_errors] = on
        php_value[date.timezone] = "UTC"
      '';

      networking.extraHosts = if addHosts
                              then let serverNames = lib.filter (h : h != "_") (lib.concatMap (s : lib.singleton s.hostname ++ s.extraHostnames or []) sites);
                                   in lib.concatMapStrings (servName: ''
                                        127.0.0.1	${servName}
                                      '') serverNames
                              else "";
    };

  # site types
  basicSite = hostname : extraHostnames : { pre ? "", post ? "", locs ? {} } : {
    hostname = hostname;
    extraHostnames = extraHostnames;
    indexes = ["index.html" "index.htm"];
    preConf = lib.splitString "\n" pre;
    locs = {
      "~ ^.+?\\.php\$" = ["return 403;"];
    } // lib.mapAttrs (n : v : lib.splitString "\n" v) locs;
    postConf = lib.splitString "\n" post;
  };
  redirect = hostname : extraHostnames : perm : redirectTo : {
    hostname = hostname;
    extraHostnames = extraHostnames;
    preConf = let code = if perm then 301 else 302;
                    in ["return ${toString code} ${redirectTo};"];
  };
  domainRedirect = from : to : {
    hostname = from;
    regexDomain = true;
    preConf = [ "set $domain ${to};"
                "return 301 $scheme://$subdomain$domain$request_uri;" ];
  };

  # modifiers - possible todo: inverse operations
  withPath = path : site : site // {
    path = path;
  };
  withPhp = site : site // {
    indexes = ["index.php"] ++ site.indexes;
    locs = site.locs // {
      "~ ^.+?\\.php\$" = (lib.remove "return 403;" site.locs."~ ^.+?\\.php\$")
                  ++ [ "try_files $uri =404;"
                       "${fcgiParams}"
                       "fastcgi_pass unix:/run/phpfpm/nginx;" ];
    };
  };
  withCustomPhp = site : site // {  # remove default php loc
    indexes = ["index.php"] ++ site.indexes;
    locs = lib.filterAttrs (n : v : n != "~ ^.+?\\.php\$") site.locs;
  };
  withSsl = cert : key : site : site // {
    ssl = {
      cert = cert;
      key = key;
    };
  };
  withIndexes = ixLocs : site : site // {
    locs = let newLocs = lib.filter (l : ! lib.hasAttr l site.locs) ixLocs;
      in (lib.mapAttrs (loc : rules :
                          if lib.elem loc ixLocs then rules ++ ["autoindex on;"] else rules)
                        site.locs)
         // lib.listToAttrs (map (l : lib.nameValuePair l ["autoindex on;"]) newLocs);
  };
}
