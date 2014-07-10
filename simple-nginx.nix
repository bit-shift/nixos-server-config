{ lib, ... } :

let fcgiParams = ''
    fastcgi_param   QUERY_STRING            $query_string;
    fastcgi_param   REQUEST_METHOD          $request_method;
    fastcgi_param   CONTENT_TYPE            $content_type;
    fastcgi_param   CONTENT_LENGTH          $content_length;
     
    fastcgi_param   SCRIPT_FILENAME         $request_filename;
    fastcgi_param   SCRIPT_NAME             $fastcgi_script_name;
    fastcgi_param   REQUEST_URI             $request_uri;
    fastcgi_param   DOCUMENT_URI            $document_uri;
    fastcgi_param   DOCUMENT_ROOT           $document_root;
    fastcgi_param   SERVER_PROTOCOL         $server_protocol;
     
    fastcgi_param   GATEWAY_INTERFACE       CGI/1.1;
    fastcgi_param   SERVER_SOFTWARE         nginx/$nginx_version;
     
    fastcgi_param   REMOTE_ADDR             $remote_addr;
    fastcgi_param   REMOTE_PORT             $remote_port;
    fastcgi_param   SERVER_ADDR             $server_addr;
    fastcgi_param   SERVER_PORT             $server_port;
    fastcgi_param   SERVER_NAME             $server_name;
     
    fastcgi_param   HTTPS                   $https if_not_empty;
     
    # PHP only, required if PHP was built with --enable-force-cgi-redirect
    fastcgi_param   REDIRECT_STATUS         200;
  '';
in rec {
  fastcgiParams = fcgiParams;

  serveSites = sites :
    let makeConfig = { hostname, extraHostnames ? [], nginxBaseConf, phpRule ? true, usePhp ? false, ssl ? null, indexedLocs ? [] ... } :
        let serverNames = lib.concatStringsSep " " (lib.singleton hostname ++ extraHostnames);
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
            mkIndexRule = loc : ''
                                  location ${loc} {
                                    autoindex on;
                                  }
                                '';
            phpBlock = let phpRuleInner = if usePhp
                                             then ''
                                                    try_files $uri =404;
                                                    ${fcgiParams}
                                                    fastcgi_pass unix:/run/phpfpm/nginx;
                                                  ''
                                             else "return 403;";
                       in if phpRule
                          then ''
                                 location ~ \.php$ {
                                   ${phpRuleInner}
                                 }
                               ''
                          else "";
        in ''
	  ${sslRedirect}

          server {
            ${sslConfig}

            listen ${mainPort}${portAnnot};
            server_name ${serverNames};
            root /srv/www/${if hostname == "_" then "default" else hostname};
            index ${if usePhp then "index.php " else ""}index.html index.htm;
            
            ${lib.concatMapStrings mkIndexRule indexedLocs}
            
            ${phpBlock}

            ${nginxBaseConf}
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
            autoindex_exact_size off;  # seriously who even wants exact bytes?

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

        php_flag[display_errors] = on
        php_admin_value[error_log] = /run/phpfpm/php-fpm.log
        php_admin_flag[log_errors] = on
        php_value[date.timezone] = "UTC";
      '';
    };

  # site types - for now one, later maybe more
  basicSite = hostname : extraHostnames : extraConf : {
    hostname = hostname;
    extraHostnames = extraHostnames;
    nginxBaseConf = extraConf;
  };

  # modifiers - possible todo: inverse operations
  withPhp = site : site // {
    usePhp = true;
  };
  withoutDefaultPhpRule = site : site // {
    phpRule = false;
  };
  withSsl = cert : key : site : site // {
    ssl = {
      cert = cert;
      key = key;
    };
  };
  withIndexes = locs : site : site // {
    indexedLocs = locs
  };

  # convenience functions to avoid parenthitis
  withCustomPhp = site : withoutDefaultPhpRule (withPhp site);
}
