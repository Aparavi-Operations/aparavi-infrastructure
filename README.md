# Aparavi Infrastructure

Aparavi repository that stores all of the code used for infrastructure provisioning on a customer side
Contains Ansible roles for configuring and deploying Aparavi app on baremetal hosts.

## Usage Example for Linux script

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
* `-p` DNS Name of the installed Platform, if you select `-n` profile as `platform`. Default "test.paas.aparavi.com"
* `-l` Actual Aparavi log collector URL. Default: "logstash.aparavi.com"
* `-m` Mysql AppUser name. Default: "aparavi_app"
* `-d` Install TMP dir. Default: "/tmp/debian11-install"
* `-v` Verbose on or off. Default: "on"
* `-b` Git branch to clone. Default: "main"
* `-u` URL to download AppAgent. Default: "https://aparavi.jfrog.io/artifactory/aparavi-installers-public/linux-installer-latest.run"

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

### More usage examples   

Platform installation:    
* `curl -s https://raw.githubusercontent.com/Aparavi-Operations/aparavi-infrastructure/main/install.sh | bash -s -- -n "platform" -c "client_name" -p "test.paas.aparavi.com"`

## Usage Example for Windows PowerShell Script

To install aggregator-collector on a Windows host, follow these steps:

1. Open Windows Terminal as an administrator.   
2. Copy and paste the following code:   

```
$tempFolder = New-Item -ItemType Directory -Path $env:TEMP\MyTempFolder
$url = 'https://raw.githubusercontent.com/Aparavi-Operations/aparavi-infrastructure/main/install.ps1'
Invoke-WebRequest $url -OutFile "$tempFolder\install.ps1"
cd $tempFolder
& .\install.ps1 -a "preview.aparavi.com" -o "aaa-bbbb-cccc-dddd-eeee"
```
3. replace `preview.aparavi.com` with the URL of the Aparavi platform you want to connect to.
4. Replace `aaa-bbbb-cccc-dddd-eeee` with the parentId of the object you want to connect the application to.

### Parameters

The PowerShell script accepts the following parameters:

* `-n` profile: The deploy profile to apply. The options are `aggregator-collector`, `aggregator`, `collector`, `platform`, `worker`, `db`, or `monitoring-only`. The default value is `aggregator-collector`.
* `-o` parentId: The parentId of the object to connect this application to. This parameter is mandatory.
* `-a` bindAddress: The platform endpoint. The default value is `preview.aparavi.com`.
* `-l` logstashAddress: The Logstash connecting endpoint. The default value is `logstash-ext.paas.aparavi.com:5044`.
* `-b` gitBranch: The automation branch name. The default value is `main`.
* `-u` downloadUrl: The application installer URL. The default value is `https://aparavi.jfrog.io/artifactory/aparavi-installers-public/windows-installer-latest.exe`.
* `-m` mysqlUser: The application database username. The default value is `aparavi_app`.
