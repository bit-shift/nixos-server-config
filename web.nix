{ config, pkgs, ... }:

with import ./simple-nginx.nix;
let retired = hostname : (singlePage "/retired.html"
                           (withPath "/srv/www/special" (basicSite hostname [] {})));
in
mkServerConf {
  addHosts = false;  # no /etc/hosts modification
  rtmp = {  # switch on rtmp support
    enable = true;
    hostname = "live.psquid.net";
    username = "bitsypon";
    password = builtins.readFile /srv/www/data/rtmp-pass;
  };
  sites = [ ### kitsun.es
            (basicSite "www.kitsun.es" ["kitsun.es"] {
              locs."~ ^/(register|http-bind)" = ''
                           proxy_set_header  X-Real-IP $remote_addr;
                           proxy_set_header  Host      $http_host;
                           proxy_pass        http://127.0.0.1:5280;
                         '';
            })
            (withPhp (basicSite "ocdb.kitsun.es" [] {
              pre = ''
                      client_max_body_size 15M;
                      
                      rewrite "^(.*)/_images/([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{28}).*$" /$1/images/$2/$2$3$4 break;
                      rewrite "^(.*)/_thumbs/([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{28}).*$" /$1/thumbs/$2/$2$3$4 break;
                      rewrite "^(.*)/(.*)\.(php|css|js|gif|png|jpg|ico|html|manifest|appcache|txt|jar)$" /$1/$2.$3 break;
                      rewrite "^(.*)/(.*)\?(.*)$ /$1/index.php?q=$2&$3" last;
                      rewrite "^(.*)/(.*)$ /$1/index.php?q=$2" last;
                      rewrite ^/(.*)$ /index.php?q=$1 last;
                    '';
              locs."~ /_?(images|thumbs)/" = ''default_type image/jpeg;'';
            }))

            ### identicurse.net
            (withIndexes ["/release/"]
              (basicSite "www.identicurse.net" ["identicurse.net"] {
                locs."/" = ''
                             ssi on;
                             rewrite ^/([^./]+)\.php$ /$1.html last;
                             rewrite ^/([^./]+)$ /$1.html last;
                           '';
              }))
            (redirect "issues.identicurse.net" ["bugzilla.identicurse.net"] true
              "https://github.com/identicurse/IdentiCurse/issues")

            ### psquid.eu
            (domainRedirect "psquid.eu" "psquid.net")

            ### psquid.net
            (basicSite "ws.psquid.net" [] {
              locs = {
                "/" = ''
                        proxy_pass http://127.0.0.1:9080;
                        proxy_http_version 1.1;
                        proxy_set_header Upgrade $http_upgrade;
                        proxy_set_header Connection "upgrade";
                      '';
              };
            })
            (basicSite "dl.psquid.net" [] {})
            # (withIndexes ["/"] (basicSite "dl-public.psquid.net" [] {}))
            (withH5ai (basicSite "dl-public.psquid.net" [] {}))
            (redirect "node.psquid.net" [] true "http://dl-public.psquid.net$request_uri")
            (retired "deb.psquid.net")
            (retired "rpm.psquid.net")
            (retired "humphrey.psquid.net")
            (retired "mspa.psquid.net")
            (retired "pony.psquid.net")
            (retired "projects.psquid.net")
            (withPhp (basicSite "pxl.psquid.net" [] {
              locs = {
                "/favicon.ico" = "";
                "/pxl.min.js" = "";
                "/robots.txt" = "";
                "/log.txt" = ''auth_basic "pxl";'';
                "/" = ''rewrite ^/(.*)$ /log.php?u=$1&geoip_country_name=$geoip_country_name&geoip_city=$geoip_city last;'';
              };
            }))

            ### msjessi.ca
            (basicSite "www.msjessi.ca" ["msjessi.ca"] {})

            ### default
            (singlePage "/nonexistent.html"
              (withPath "/srv/www/special" (basicSite "_" [] {})))
          ];
}
