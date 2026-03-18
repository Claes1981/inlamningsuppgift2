#cloud-config
package_update: false
package_upgrade: false

runcmd:
  - systemctl restart ssh
  - systemctl enable ssh
