#cloud-config
# Web Server Cloud-Init Configuration
# Installs .NET runtime and configures TodoApp as a systemd service

package_update: true
package_upgrade: false

packages:
  - wget
  - apt-transport-https
  - software-properties-common

write_files:
  - path: /etc/systemd/system/GithubActionsTodoApp.service
    content: |
      [Unit]
      Description=ASP.NET Web App running on Ubuntu

      [Service]
      WorkingDirectory=/opt/GithubActionsTodoApp
      ExecStart=/usr/bin/dotnet /opt/GithubActionsTodoApp/GithubActionsTodoApp.dll
      Restart=always
      RestartSec=10
      KillSignal=SIGINT
      SyslogIdentifier=GithubActionsTodoApp
      User=www-data
      Environment=ASPNETCORE_ENVIRONMENT=Production
      Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
      Environment="ASPNETCORE_URLS=http://*:5000"

      [Install]
      WantedBy=multi-user.target      
    owner: root:root
    permissions: '0644'

runcmd:
  # Register Microsoft repository (which includes .Net Runtime 10.0 package)
  - wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  - dpkg -i packages-microsoft-prod.deb

  # Install .Net Runtime 10.0
  - apt-get update
  - apt-get install -y aspnetcore-runtime-10.0

  # Enable the application service
  - systemctl daemon-reload
  - systemctl enable GithubActionsTodoApp.service

  # Configure firewall to allow port 5000 (internal only)
  - ufw allow 5000/tcp || true

  # Set resource limits for the service
  - systemctl set-property GithubActionsTodoApp.service MemoryMax=512M || true
