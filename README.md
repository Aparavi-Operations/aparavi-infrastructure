# Aparavi Infrastructure

Aparavi repository that stores all of the code used for infrastructure provisioning on a customer side
Contains Ansible roles for configuring and deploying Aparavi app on baremetal hosts.

## Usage Example

`curl -s https://raw.githubusercontent.com/Aparavi-Operations/aparavi-infrastructure/main/install.sh | sudo bash -s -- "your-platform-url.aparavi.com" "new_client1" "ddd-ddd-ddd-ddd" "logstash.aparavi.com"`

Parameters description:
* `your-platform-url.aparavi.com` - actual Aparavi platform URL to connect your AppAgent to
* `new_client1` - client name, assumed one deployment per client, in case of several deployments, just specify this like `new_client1_deployment1`, `new_client1_deployment2`, ..., `new_client1_deploymentN` per each deployment
* `ddd-ddd-ddd-ddd` - parent object id provided by Aparavi
* `logstash.aparavi.com` - actual Aparavi log collector URL


## Directory Structure

Shell script - the only file you need to run
* [`install.sh`](install.sh)

Ansible roles used to deploy projects:
* [`ansible/roles/`](ansible/roles/)




