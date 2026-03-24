#cloud-config
# Reverse Proxy Cloud-Init Configuration
# Installs NGINX and configures it to proxy requests to the TodoApp

package_update: false
package_upgrade: false

packages:
  - nginx

write_files:
  - path: /etc/nginx/sites-available/default
    permissions: '0644'
    owner: root:root
    content: |
      # Upstream configuration for TodoApp backend
      upstream todoapp {
          server 10.0.0.4:5000;
          keepalive 32;
      }

      server {
          listen 80 default_server;
          listen [::]:80 default_server;
          server_name _;

          # Security headers
          add_header X-Frame-Options "SAMEORIGIN" always;
          add_header X-Content-Type-Options "nosniff" always;
          add_header X-XSS-Protection "1; mode=block" always;

          # Proxy configuration for TodoApp
          location / {
              proxy_pass http://todoapp;
              proxy_http_version 1.1;
              
              # Proxy headers
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header Connection "";
              
              # WebSocket support
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
              
              # Timeouts
              proxy_connect_timeout 60s;
              proxy_send_timeout 60s;
              proxy_read_timeout 60s;
          }

          # Health check endpoint
          location /health {
              access_log off;
              return 200 "OK\n";
              add_header Content-Type text/plain;
          }

          # NGINX status (for monitoring)
          location /nginx_status {
              stub_status on;
              allow 10.0.0.0/24;
              deny all;
          }
      }

  - path: /etc/nginx/conf.d/limits.conf
    permissions: '0644'
    owner: root:root
    content: |
      # Increase worker connections for better performance
      worker_connections 1024;

runcmd:
  # Add WebServer hostname to /etc/hosts for internal communication
  - echo "10.0.0.4 WebServer" >> /etc/hosts

  # Remove default site if it exists and create symlink
  - rm -f /etc/nginx/sites-enabled/default || true
  - ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

  # Test NGINX configuration
  - nginx -t

  # Enable and start NGINX
  - systemctl enable nginx
  - systemctl restart nginx

  # Configure firewall to allow HTTP traffic
  - ufw allow 'Nginx HTTP' || true
