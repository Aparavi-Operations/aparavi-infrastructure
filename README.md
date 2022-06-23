# Aparavi Infrastructure

Aparavi repository that stores all of the code used for infrastructure provisioning on a customer side
Contains Ansible roles for configuring and deploying Aparavi app on baremetal hosts.

## Usage Example

`curl -s https://raw.githubusercontent.com/Aparavi-Operations/aparavi-infrastructure/main/install.sh | sudo bash -s -- -n "full" -c "client_name" -o "parent_object_id"`

Required options:
* `-n` Node profile for deploying. Default: "basic"  
  * `basic`      - OS ans SSH hardening included only  
  * `hardening`  - OS,SSH and advanced hardening included only  
  * `secure`     - basic profile + Wazuh agent + ClamAV agent  
  * `monitoring` - basic profile + logs shipping agent + monitoring metrics, requires `-c` switch
  * `appliance`  - basic profile + MySQL server + Aparavi AppAgent, requires `-o` switch
  * `full`       - all featured above, requires both `-c` and `-o` switches
  * `mysql_only` - basic profile + MySQL server

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
