#cloud-config
# Web Server Cloud-Init Configuration
# Installs .NET runtime and configures TodoApp as a systemd service

package_update: false
package_upgrade: false

packages:
  - wget
  - apt-transport-https
  - software-properties-common

write_files:
  - path: /etc/systemd/system/todoapp.service
    permissions: '0644'
    owner: root:root
    content: |
      [Unit]
      Description=TodoApp Web Application
      After=network.target
      Wants=network-online.target

      [Service]
      Type=simple
      User=azureuser
      Group=azureuser
      WorkingDirectory=/home/azureuser/TodoApp/publish
      ExecStart=/usr/bin/dotnet /home/azureuser/TodoApp/publish/TodoApp.dll
      Restart=always
      RestartSec=10
      StandardOutput=journal
      StandardError=journal
      SyslogIdentifier=todoapp
      Environment="ASPNETCORE_ENVIRONMENT=Production"
      Environment="DOTNET_ROLL_FORWARD=LatestMajor"
      Environment="ASPNETCORE_URLS=http://+:5000"

      [Install]
      WantedBy=multi-user.target

runcmd:
  # Create directory for the application with proper permissions
  - mkdir -p /home/azureuser/TodoApp/publish
  - chown -R azureuser:azureuser /home/azureuser/TodoApp

  # Reload systemd and enable the service
  - systemctl daemon-reload
  - systemctl enable todoapp.service

  # Configure firewall to allow port 5000 (internal only)
  - ufw allow 5000/tcp || true

  # Set resource limits for the service
  - systemctl set-property todoapp.service MemoryMax=512M || true
