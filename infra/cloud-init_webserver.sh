#cloud-config
# Web Server Cloud-Init Configuration
# Installs .NET runtime and configures TodoApp as a systemd service

package_update: true
package_upgrade: false

packages:
  - openssh-server
  - wget
  - curl
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

  # Ensure SSH is running
  - systemctl enable ssh || true
  - systemctl start ssh || true

  # Download and configure GitHub Actions runner
  - mkdir -p /home/azureuser/actions-runner
  - curl -o /tmp/actions-runner-linux-x64-2.333.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.333.0/actions-runner-linux-x64-2.333.0.tar.gz
  - echo "7ce6b3fd8f879797fcc252c2918a23e14a233413dc6e6ab8e0ba8768b5d54475  actions-runner-linux-x64-2.333.0.tar.gz" | shasum -a 256 -c
  - tar xzf /tmp/actions-runner-linux-x64-2.333.0.tar.gz -C /home/azureuser/actions-runner
  - chown -R azureuser:azureuser /home/azureuser/actions-runner
  - chmod +x /home/azureuser/actions-runner/config.sh
  - echo "{{GITHUB_TOKEN}}" > /tmp/runner_token.txt
  - chown azureuser:azureuser /tmp/runner_token.txt
  - su - azureuser -c "cd /home/azureuser/actions-runner && ./config.sh --unattended --url https://github.com/Claes1981/inlamningsuppgift2 --token $(cat /tmp/runner_token.txt)"
  - rm /tmp/runner_token.txt
  - # Run the Github runner as a service
  - su - azureuser -c "/home/azureuser/actions-runner/svc.sh install azureuser"
  - su - azureuser -c "/home/azureuser/actions-runner/svc.sh start"


