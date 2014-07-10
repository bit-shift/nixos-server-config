{ config, pkgs, ... }:

with (import ./simple-nginx.nix { lib = pkgs.stdenv.lib; });
serveSites [ (withPhp (basicSite "pxl.psquid.net" [] ""))
             (withSsl "/srv/www/ssl/owncloud.crt" "/srv/www/ssl/owncloud.key"
               (withCustomPhp (basicSite "cloud.psquid.net" [] ''
                 client_max_body_size 10G;
                 fastcgi_buffers 64 4K;
                 
                 rewrite ^/caldav(.*)$ /remote.php/caldav$1 redirect;
                 rewrite ^/carddav(.*)$ /remote.php/carddav$1 redirect;
                 rewrite ^/webdav(.*)$ /remote.php/webdav$1 redirect;
                 
                 error_page 403 /core/templates/403.php;
                 error_page 404 /core/templates/404.php;
                 
                 location = /robots.txt {
                   allow all;
                   log_not_found off;
                   access_log off;
                 }
                 
                 location ~ ^/(data|config|\.ht|db_structure\.xml|README) {
                   deny all;
                 }
                 
                 location / {
                   rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
                   rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json last;
                   
                   rewrite ^/.well-known/carddav /remote.php/carddav/ redirect;
                   rewrite ^/.well-known/caldav /remote.php/caldav/ redirect;
                   
                   rewrite ^(/core/doc/[^\/]+/)$ $1/index.html;
                   
                   try_files $uri $uri/ index.php;
                 }
                 
                 location ~ ^(.+?\.php)(/.*)?$ {
                   try_files $1 =404;
                   
                   ${fastcgiParams}
                   fastcgi_param SCRIPT_FILENAME $document_root$1;
                   fastcgi_param PATH_INFO $2;
                   fastcgi_pass unix:/run/phpfpm/nginx;
                 }
                 
                 location ~* ^.+\.(jpg|jpeg|gif|bmp|ico|png|css|js|swf)$ {
                   expires 30d;
                   access_log off;
                 }
               '')))
             (basicSite "_" [] "")
           ]
