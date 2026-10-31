server {
    listen 80; listen [::]:80;
    server_name __DOMAIN__;
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://$host$request_uri; }
}
server {
    # слушает ТОЛЬКО localhost — наружу выходит через Reality dest на 443
    listen 127.0.0.1:__SITE_PORT__ ssl; http2 on;
    server_name __DOMAIN__;
    ssl_certificate     /etc/letsencrypt/live/__DOMAIN__/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/__DOMAIN__/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    root /var/www/tak-sovpalo; index index.html;

    # подписка 3x-ui
    location /sub/  { proxy_pass https://127.0.0.1:__SUB_PORT__; proxy_ssl_server_name on; proxy_set_header Host $host; access_log off; }
    location /json/ { proxy_pass https://127.0.0.1:__SUB_PORT__; proxy_ssl_server_name on; proxy_set_header Host $host; access_log off; }

    # панель 3x-ui по секретному пути
    location /__PANEL_SEG__/ {
        proxy_pass https://127.0.0.1:__PANEL_PORT__;
        proxy_ssl_server_name on;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 3600s;
        access_log off;
    }

    # панель AmneziaWG по секретному пути (ассеты wg-easy релятивные — заходить со слешом)
    location /__AWG_SEG__/ {
        proxy_pass http://127.0.0.1:__AWG_UI_PORT__/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 3600s;
        access_log off;
    }

    location / { try_files $uri $uri/ =404; }
}
