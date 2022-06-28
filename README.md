# Aparavi Infrastructure

Aparavi repository that stores all of the code used for infrastructure provisioning on a customer side
Contains Ansible roles for configuring and deploying Aparavi app on baremetal hosts.

## Usage Example

`curl -s https://raw.githubusercontent.com/Aparavi-Operations/aparavi-infrastructure/main/install.sh | sudo bash -s -- -n "full" -c "client_name" -o "parent_object_id"`

Required options:
* `-n` Node profile for deploying. Default: "basic"  
  * `basic`                             - OS and SSH hardening included only
  * `hardening_advanced`                - OS hardening + SSH hardening + advanced hardening + Wazuh agent + ClamAV agent
  * `hardening_advanced_and_partitions` - OS hardening + SSH hardening + advanced hardening + Wazuh agent + ClamAV agent + partitions
  * `monitoring`                        - basic profile + logs shipping agent + monitoring metrics, requires `-c` switch
  * `default`                           - OS hardening + SSH hardening + Wazuh agent + ClamAV agent + MySQL server + Aparavi AppAgent + logs shipping agent + monitoring metrics
  * `full_without_partitions`           - all featured above without partitions, requires both `-c` and `-o` switches
  * `full`                              - all featured above, requires both `-c` and `-o` switches. The most secure version of the application installation. There may be server issues
  * `mysql_only`                        - basic profile + MySQL server

* `-c` Client name, assumed one deployment per client, in case of several deployments, just specify this like `new_client1_deployment1`, `new_client1_deployment2`, ..., `new_client1_deploymentN` per each deployment
* `-o` Parent object id provided by Aparavi. Example: "ddd-ddd-ddd-ddd"

Additional options:
* `-a` Actual Aparavi platform URL to connect your AppAgent to. Default "preview.aparavi.com"
* `-l` Actual Aparavi log collector URL. Default: "logstash.aparavi.com"
* `-m` Mysql AppUser name. Default: "aparavi_app"
* `-d` Install TMP dir. Default: "/tmp/debian11-install"
* `-v` Verbose on or off. Default: "on"
* `-b` Git branch to clone. Default: "main"
* `-h` Add advanced hardening or not (yes/no). Default: "no"
* `-p` Remount partitions for hardening or not (yes/no). Default: "no"

## Example
`install.sh -n "full" -c "client_name" -o "parent_object_id`

## Directory Structure

Shell script - the only file you need to run
* [`install.sh`](install.sh)

Ansible roles used to deploy projects:
* [`ansible/roles/`](ansible/roles/)

# Playbook configuration

These options can be set in the file `ansible/playbooks/base/main.yml`

Additional variables:
* `ssh_port` SSHD port. Default "22"
* `ipv6_disable` Disable IPv6 or not. Default false
* `wazuh_agent_full_version` Wazuh full version. Default "" (latest)
* `mysql_version` Mysql server version. Default "0.8.22-1"
* `disable_vfat` Disable vfat or not. Default true
* `disable_forwarding` Disable ipv4 and ipv6 forwarding or not. Default true

Partitions parameters:
* `swap_size`    Swap size. Default "1g"
* `var_size`     Size of `/var/` partition. Default "10g"
* `vlog_size`    Size of `/var/log/` partition. Default:"5g"
* `vlaudit_size` Size of `/var/log/audit/` partition. Default:"2g"
* `home_size`    Size of `/home/` partition. Default:"5g"
* `tmp_size`     Size of `/tmp/` partition. Default:"2g"
* `vtmp_size`    Size of `/var/tmp/` partition. Default::"2g"
