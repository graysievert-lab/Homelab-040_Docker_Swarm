# Single-node swarm cluster with Traefik and Portainer

- `110-Infrastructure_terraform` - Creates a VM on the Proxmox node
- `120-Configuration_ansible` - Configurations for the VM
  - `play-01-install-swarm.yaml` - Install docker and initialize swarm
  - `play-02-deploy-stack-traefik.yaml` - Deploy Traefik stack (Install option A)
  - `play-03-deploy-stack-portainer.yaml` - Deploy Portainer stack (Install option A)
  - `play-04-deploy-stack-portainer-first.yaml` - Deploy Portainer stack (Install option B)
- `stack-001-traefik` - Traefik stack files
- `stack-002-portainer` - Portainer stack files

## Two installation scenarios

### Option A

This scenario assumes that after the creation of a VM, configuration will happen in the following order

- Install docker and initialize swarm via Ansible `play-01-install-swarm.yaml`
- Deploy traefik stack `stack-001-traefik` via Ansible `play-02-deploy-stack-traefik.yaml`
- Deploy portainer stack `stack-002-portainer` via Ansible `play-03-deploy-stack-portainer.yaml`
- Set `admin` user for Portainer
- Configure OAuth for Portainer

In this scenario, the traefik stack will have "Limited" control in Portainer, so any subsequent update of dynamic configuration via file provider would require a re-run of ansible play `play-02-deploy-stack-traefik.yaml`.

### Option B

This scenario is intended to deploy traefik stack via portainer from the git repository using the option `relative path volumes`. Which would allow subsequent updates of Traeffik's file provider without Ansible.
After the creation of a VM configuration needs to happen in the following order:

- Install docker and initialize swarm via Ansible `play-01-install-swarm.yaml`
- Deploy portainer stack `stack-002-portainer` via Ansible `play-04-deploy-stack-portainer-first.yaml` which will add a `ports:` override to the compose file.
- Set `admin` user for Portainer
- Deploy traefik stack `stack-001-traefik` via Portainer directly from Git repository (see [below](#deploying-traefik-stack-via-portainer)).
- Configure OAuth for Portainer.

Note: It is recommended to try Scenario A first to work out the kinks and then, redeploy via Scenario B sequence. The walkthrough below follows this recommendation.

## `110-Infrastructure_terraform`

This configuration:

- Installs a Rocky Linux VM, with pinned IP address.
- Creates DNS A record for `swarm.lan` pointing to that address
- Creates DNS CNAME record for `*.swarm.lan` pointing to `swarm.lan`

Prerequisites:

- Vault secrets:
  - `infra-homelab/dns_zone_lan` contains key `TF_VAR_TSIG_key`  with value formatted as  `key_name.|key_material`

NOTE: The user for remote access is `rocky`. Any SSH key signed by Vault's SSH CA `ssh-vm-usercert` will provide access (see [example](https://github.com/graysievert-lab/Homelab-030_Secrets_and_Auth/tree/master/template_project_secrets)).

### Initialize environment

Note: All commands in this readme (unless stated otherwise) are expected to run from the repo's root directory.

Generate SSH keys:

```bash
$ ssh-keygen -q  -C "" -N "" -f $HOME/.ssh/iac
$ ssh-keygen -q  -C "" -N "" -f $HOME/.ssh/vm
```

Set env variables:

```bash
$ eval $(ssh-agent -s)
$ export VAULT_ADDR=https://aegis.lan:8200
$ vault login -method=oidc
```

<details>
  <summary>**NOTE: OIDC Login via CLI on a Headless Server**</summary>

Command `vault login -method=oidc` will try to open a web browser to finish login. Sometimes this is not feasible, but in any case vault will output the URL that needs to be visited in a browser, then will open port `8250` on address `127.0.0.1`  and will wait for a GET request on that port :

```bash
$ vault login -method=oidc
Complete the login via your OIDC provider. Launching browser to:

https://aegis.lan/application/o/authorize/?client_id=NotThatSecretButUniqueRandomStringUsedForVault&code_challenge=ZS8q3vEJDSuIj1Wn4eV8yKBVPotrMUD2Y1jUYMoytdo&code_challenge_method=S256&nonce=n_67hy9LqZq9ujwlJnGTNb&redirect_uri=http%3A%2F%2Flocalhost%3A8250%2Foidc%2Fcallback&response_type=code&scope=openid+profile+email&state=st_DHBwZjhBmfXvCDijbCpd

Waiting for OIDC authentication to complete...
```

One is expected to open the provided URL in some browser and finish authentication. When it is done OAuth will redirect to localhost with special parameters in the URL. The problem is that it is another localhost, so the call eventually ends in a failed GET request which will never reach the right network interface.
The workaround is really simple:

1. After authorization, copy the callback URL from the browser (or browser's console).
2. In another terminal session `curl "<full callback url>"` (It is important to quote the URL):

```bash
$ curl "http://localhost:8250/oidc/callback?code=5f3f5b470cfd471dae99ee5d1892b31d&state=st_DHBwZjhBmfXvCDijbCpd"
```

</details>

Generate the API token and sign the SSH key to access Proxmox:

```bash
$ source ./prime_proxmox_secrets.sh $HOME/.ssh/iac
Signed key saved to $HOME/.ssh/iac-cert.pub
Identity added: $HOME/.ssh/iac ($HOME/.ssh/iac)
Certificate added: $HOME/.ssh/iac-cert.pub (vault-oidc-newton@homelab.lan-18b60df80df89efb42bcc1487fd86d2cf2abc83317eaa1677b69bfc97521621a)
Key added to SSH agent successfully.
TF_VAR_pvetoken has been set.
```

Fetch Project's secrets:

```bash
$ source prime_env.sh <<< $(./gen_token.sh < 110-Infrastructure_terraform/secrets.list)
Priming your environment with secrets...
Your env is ready
```

### Create VM and test SSH access

Initialize providers and execute configuration:

```bash
$ terraform -chdir=110-Infrastructure_terraform init
$ terraform -chdir=110-Infrastructure_terraform plan
$ terraform -chdir=110-Infrastructure_terraform apply
```

When it's done, sign the second SSH key and test the VM's accessibility. This is also a good opportunity to populate known_hosts with the VM's SSH host key.

```bash
$ ./sign_ssh_vm_key.sh $HOME/.ssh/vm
Signed key saved to $HOME/.ssh/vm-cert.pub
Identity added: $HOME/.ssh/vm ($HOME/.ssh/vm)
Certificate added: $HOME/.ssh/vm-cert.pub (vault-oidc-newton@homelab.lan-b6bcfa40fcc46788e5b29e52349c71e7aefdbb3821a218789084f9baeb288df3)
Key added to SSH agent successfully.

$ ssh rocky@swarm.lan
The authenticity of host 'swarm.lan (10.1.2.2)' can't be established.
ED25519 key fingerprint is SHA256:frD9ojg45vUHgEDuvkzUuxKNCTq6DmrWLYg4ef0yEP4.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'swarm.lan' (ED25519) to the list of known hosts.

[rocky@swarm ~]$ logout
Connection to swarm.lan closed.
```

## `120-Configuration_ansible`

The ansible step is intended to bootstrap a single-node swarm cluster and deploy several stacks to increase the usability of the swarm for the next deployments.

The directory `120-Configuration_ansible` contains the following files:

- `ansible.cfg` - ansible configuration with few tweaks
- `inventory.yaml` - Inventory file with connection details
- `ansible-requirements.yaml` - ansible collections required for execution
- `play-01-install-swarm.yaml` - Installs docker and activates swarm mode
- `play-02-deploy-stack-traefik.yaml` - Uploads `traefik` stack files and deploys the stack
- `play-03-deploy-stack-portainer.yaml` - Uploads `portainer` stack files and deploys the stack
- `play-04-deploy-stack-portainer-first.yaml` - Alternative Portainer play for scenario B
- `secrets.list` - the list of secrets in Vault that could be used to [generate Vault token for a user with limited access to Vault](https://github.com/graysievert-lab/Homelab-030_Secrets_and_Auth/tree/master/template_project_secrets) (not used in this scenario).

### Prepare environment

Install requirements:

```bash
$ ansible-galaxy install -r 120-Configuration_ansible/ansible-requirements.yaml
```

and proceed to:

### `play-01-install-swarm.yaml`

This play:

- Installs the latest stable docker release
- Creates `/etc/docker/daemon.json` with a few tweaks
- Initializes the swarm mode with docker network CIDR re-configuration.

To run the book execute the following:

```bash
$ ANSIBLE_CONFIG=120-Configuration_ansible/ansible.cfg \
ansible-playbook -v 120-Configuration_ansible/play-01-install-swarm.yaml
```

### `play-02-deploy-stack-traefik.yaml`

#### Ansible notes

Note: The play requires a valid Vault token and several secrets at `infra-swarm/traefik`. Please see play and stack `yaml` files for details.

Note: Authentik needs some configuration to get a functioning traefik dashboard (see below).

This play:

- Creates several swarm secrets and populates them with data from Vault
- Creates overlay network `traefik`
- Copies stack files from directory `stack-001-traeffik`
- Deploys the stack

To run the book execute the following:

```bash
$ ANSIBLE_CONFIG=120-Configuration_ansible/ansible.cfg \
ansible-playbook -v 120-Configuration_ansible/play-02-deploy-stack-traefik.yaml
```

If everything is set up correctly, after a few minutes the URL `https://traefik.swarm.lan`  will display (after authentication via Authentik SSO) traefik's dashboard.

#### Stack notes

Prerequisites:

Traeffik's dashboard is going to be protected by Authentik, so the following steps are needed before (or right after) stack deployment:

Crate Provider:

- Name: `Provider for DevOps Access`
- Authentication/Authorization flow: chose anything you like
- Select the tab `Forward Auth (single application)`, set `External Host` to `https://traefik.swarm.lan`

Create Application:

- Name: `DevOps Access`
- Slug: `devops-access`
- Provider:`Provider for DevOps Access`
- UI settings->Launch URL: `https://traefik.swarm.lan`
- Switch to the tab `Policy / Group / User Bindings` and create binding for group `devops`

Edit embedded Outpost:

- Type: `proxy`
- Selected applications: `DevOps Access`
- in the advanced section ensure key-value: `authentik_host: https://aegis.lan`

The corresponding middleware `traefik.http.middlewares.authentik.forwardauth` is configured in the compose file via labels of service `traefik`.

Compose and static configuration files contain some useful explanations. If more details are needed, here's a good introduction to [dockerized traefik](https://www.spad.uk/posts/practical-configuration-of-traefik-as-a-reverse-proxy-for-docker-updated-for-2023/).

### `play-03-deploy-stack-portainer.yaml`

#### Ansible notes

This play:

- Creates a volume for portainer data
- Copies stack files from directory `stack-002-portainer`
- Deploys the stack

To run the book execute the following:

```bash
$ ANSIBLE_CONFIG=120-Configuration_ansible/ansible.cfg \
ansible-playbook -v 120-Configuration_ansible/play-03-deploy-stack-portainer.yaml
```

#### Stack notes

Note: This stack assumes a single-node swarm installation without portainer agent or edge.

Note: This stack by default uses a business edition image, so it will ask for a license key after the installation. OIDC group matching described below requires a business edition version. It is very easy to receive a demo key for 3 nodes using some temporary emails service, but if that is not acceptable just modify comments in the compose file to switch to the community edition.

### Post install steps: enabling authentication in Portainer via OAuth (Authentik IdP)

After the deployment of portainer stack a human needs to visit `https://portainer.swarm.lan` to initialize portainer with a password for `admin` user. If a business edition is being installed, the next page will ask for a license. Please remember if the password for admin is not set within 5 minutes after deployment, the Portainer container will need a restart.

#### Authentik config

Create an additional OIDC provider and application in Authentik:

Provider:

- Name: `portainer`
- Redirect URIs: `https://portainer.swarm.lan/`
- Scopes: `email`, `openid`, `profile`
- Subject mode: `based on user's email`

Application:

- Name: `portainer`
- Slug: `portainer`
- Provider: `portainer`

#### Create a group in Portainer

Visit `Administration -> User-related -> Teams`
Create a team with the name: `devops`.

#### Setup OAuth in Portainer

Visit `Settings -> Authentication`, select `OAuth`

- Use SSO: `on`
- Hide internal authentication prompt: `off`
- Automatic user provisioning: `on`
- Automatic team membership: `on`
- Claim name: `groups`
- Statically assigned teams (`add team mapping`):
  - claim value regex: `devops`
  - maps to: team `devops`
- Assign admin rights to group(s): on
  - add admin mapping (claim value regex): `devops`

Select Provider: `custom` and configure it as such:

- Client ID: `Your NotThatSecretButUniqueRandomStringUsedForPortainer`
- Secret: `Your Secret`
- Authorization URL: `https://aegis.lan/application/o/authorize/`
- Access token URL: `https://aegis.lan/application/o/token/`
- Resource URL: `https://aegis.lan/application/o/userinfo/`
- Redirect URL: `https://portainer.swarm.lan/`
- Logout URL: leave empty
- User identifier: `email`
- Scopes: `email openid profile` (space separated, which might contradict the placeholder)
- Auth Style: `In Params`

#### Troubleshooting OAuth

Troubleshooting this step would be most probably around TLS connection to Authentik, so ensure that the Portainer container binds the local CA certificate to `/etc/ssl/certs/localCA.crt` (cloud-init should download it to `/etc/pki/ca-trust/source/anchors/localCA.crt` on the VM).

Changing log-level to `DEBUG` in the compose file might also provide some useful insights. One can leverage the Portaner UI to check service logs without logging in to the VM.

## Scenario B

After completing the play `play-01-install-swarm.yaml` run the alternative Portainer play:

```bash
$ ANSIBLE_CONFIG=120-Configuration_ansible/ansible.cfg \
ansible-playbook -v 120-Configuration_ansible/play-04-deploy-stack-portainer-first.yaml
```

The play above:

- Creates swarm secrets for traefik's ACME client to pass DNS challenge and populates them with data from Vault.
- Creates the overlay network `traefik`
- Creates a volume for portainer data
- Copies stack files from directory `stack-002-portainer`
- Deploys the stack with compose override to publish port `9443:9443`

After deployment of the portainer stack a human needs to visit `https://swarm.lan:9443` to initialize the portainer with a password for `admin` user. If a business edition is being installed the next page will ask for a license. Please remember if the password for admin is not set within 5 minutes after deployment, the Portainer container will need a restart.

NOTE: Connection to `https://swarm.lan:9443` will be reported by the browser as insecure. After the deployment of traefik, users are expected to visit `https://portainer.swarm.lan` or `https://swarm.lan` which both will supply a valid TLS certificate.

### Deploying Traefik stack via Portainer

Go to `Home`, and select `Primary` on the environments list. Then go to `Stacks` and `+Add Stack` with the following details:

- Name: `traefik`
- Build method: `repository`
- Repository URL: `https://github.com/graysievert-lab/Homelab-040_Docker_Swarm`
- Repository reference: `refs/heads/main`
- Compose path: `/stack-001-traefik/compose-traefik.yaml`
- GitOps updates: `on`
- Mechanism: `webhook`
- Re-pull image: `off`
- Force redeployment: `on`
- Skip TLS Verification: `off`
- Enable relative path volumes: `on`
- Network filesystem path: `/mnt/stacks`

### Enabling authentication via OAuth

Just follow the instructions in the [section above](#post-install-steps-enabling-authentication-in-portainer-via-oauth-authentik-idp)
