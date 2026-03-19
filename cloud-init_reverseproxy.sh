#cloud-config
package_update: true
package_upgrade: false
packages:
  - nginx

write_files:
  - path: /etc/nginx/sites-available/default
    content: |
      upstream webserver {
          server webserver:8080;
      }

      server {
          listen 80 default_server;
          server_name _;

          location / {
              proxy_pass http://webserver;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
          }
      }

runcmd:
  - echo "$(dig +short webserver | head -1) webserver" >> /etc/hosts
  - systemctl restart nginx
  - systemctl enable nginx
