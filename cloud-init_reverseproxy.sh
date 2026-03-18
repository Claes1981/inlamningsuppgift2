#cloud-config
package_update: false
package_upgrade: false
packages:
  - nginx

write_files:
  - path: /etc/nginx/sites-available/default
    content: |
      upstream webserver {
          server 10.0.0.5:8080;
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
  - systemctl restart nginx
  - systemctl enable nginx
