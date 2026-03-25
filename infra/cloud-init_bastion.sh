#cloud-config
# Bastion Host Cloud-Init Configuration
# Configures SSH settings and security hardening

package_update: true
package_upgrade: false

packages:
  - sshpass
  - vim
  - htop
  - net-tools

write_files:
  - path: /etc/ssh/sshd_config.d/99-bastion-hardening.conf
    permissions: '0644'
    owner: root:root
    content: |
      # SSH Hardening for Bastion Host
      PasswordAuthentication no
      PermitRootLogin no
      X11Forwarding no
      AllowTcpForwarding yes
      AllowAgentForwarding yes
      MaxAuthTries 3
      LoginGraceTime 60
      ClientAliveInterval 300
      ClientAliveCountMax 2

runcmd:
  # Reload SSH configuration
  - systemctl reload sshd || true

  # Note: Firewall handled by Azure NSG, not ufw

  # Set hostname
  - hostnamectl set-hostname BastionHost || true

  # Add internal hostnames to /etc/hosts
  - echo "10.0.0.4 WebServer" >> /etc/hosts
  - echo "10.0.0.5 ReverseProxy" >> /etc/hosts
