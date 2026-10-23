# OpenStack on one VM of an OpenStack cloud

Three scripts give you a complete OpenStack (2026.1, deployed with Kolla-Ansible) on a single VM of any OpenStack
cloud, in about an hour, and delete it all when you are done:

| Script | What it does | Measured |
|---|---|---|
| `create.sh` | Creates one VM (4 vCPU, 16 GB RAM, 50 GB disk), its key, security group, port and, if you want one, a floating IP. Shows the estimated cost per hour and asks before creating anything | 3 min |
| `deploy.sh` | Installs Kolla-Ansible on the VM and deploys OpenStack all-in-one: Keystone, Glance, Nova, Neutron (Open vSwitch), Placement, Heat, Horizon. Ends with a test instance reachable on a floating IP | 53 min |
| `destroy.sh` | Deletes everything `create.sh` created, after asking, and checks that nothing is left | under 1 min |

Measured on 2026-10-23, on Felcloud (the scripts' first test cloud): OpenStack 2026.1, Kolla-Ansible 22.2.0,
ansible-core 2.20.10, images from quay.io, Ubuntu 24.04 VM with nested KVM, a project without direct Internet access
(through an HTTPS proxy). The last full run, from `create.sh` to `destroy.sh`, took 57 minutes:

| Step of `deploy.sh` | Time |
|---|---|
| Prepare the host | 5 min 52 s |
| Install Kolla-Ansible | 2 min 22 s |
| Configuration, `bootstrap-servers`, `prechecks` | 3 min 26 s |
| `pull` (images from quay.io) | 17 min 53 s |
| `deploy` | 21 min 21 s |
| `post-deploy`, smoke test (an instance, a floating IP, ping and SSH) | 2 min 19 s |

## The cost risk, before anything else

The VM costs money **every hour it exists**, whether you use it or not, until you run `./destroy.sh`.

- **Prepaid cloud**: spending cannot go beyond the credit you loaded. Felcloud, the first cloud these scripts were
  tested on, is prepaid: its [pricing page](https://felcloud.io/pricing) says *"Top up your balance and spend only
  what you loaded."* (checked on 2026-10-23), and it bills per second (same page). For another prepaid provider,
  check its own terms before you rely on it.
- **Pay-as-you-go cloud**: set a budget alert in your provider's console **before** you start, and destroy the lab
  the same day.
- `create.sh` prints the estimate from `COST_PER_HOUR`, which you copy from your provider's price list, and waits for
  your confirmation. Include everything your provider bills for the lab: the flavor, and, if it bills them apart, the
  root volume (created when the flavor has no 50 GB disk) and the floating IP (if you use one).

## What you need

- An account on an OpenStack cloud, with a quota for one VM of 4 vCPU and 16 GB of RAM.
- On your computer: `bash` 4.4 or later (macOS ships 3.2: install a newer one, for example with Homebrew), `ssh`,
  `python3`, and the OpenStack client (`pip install python-openstackclient`).
- A `clouds.yaml` for that account (download it from your cloud's dashboard: *API Access*), in
  `~/.config/openstack/clouds.yaml`. The scripts never copy it anywhere.
- A network of your project with Internet access (a router), and a way to reach the VM: a floating IP, or a host of
  the same network. If your project has no direct Internet access, the scripts can use an HTTPS proxy and an NTP
  server instead (see `config.example.env`).

## Steps

```bash
cp config.example.env config.env
$EDITOR config.env            # at least OS_CLOUD, NETWORK, SSH_FROM, COST_PER_HOUR; FLOATING_NETWORK if you use one
./create.sh                   # shows what it will create and the cost, asks, creates
./deploy.sh                   # about an hour; can be run again after a failure, it resumes
ssh -i .state/<prefix><lab>/id_ed25519 ubuntu@<vm-address>
source ~/kolla-venv/bin/activate; . /etc/kolla/admin-openrc.sh
openstack server list          # demo1, the test instance
./destroy.sh                  # when you are done: deletes everything, after asking
```

Every resource is named with your `PREFIX` (default `quicklab-`) and `LAB` (default `1`): the VM is
`quicklab-1`, with `quicklab-1-key`, `quicklab-1-sg`, `quicklab-1-port`, and `quicklab-1-root` when the flavor has no
disk and the VM boots from a volume. `destroy.sh` finds them by these names even if the creation failed half-way or
`.state/` was lost, and fails loudly if anything is left. Two labs side by side need two values of
`LAB`. The private key and the IDs of what was created are kept in `.state/<prefix><lab>/` (ignored by git).

## Inside the lab

On the VM, load the OpenStack client and the admin credentials:

```bash
source ~/kolla-venv/bin/activate
. /etc/kolla/admin-openrc.sh
openstack server list
```

`deploy.sh` ends with Kolla-Ansible's demo set-up (`init-runonce`) and a test instance. What exists then, for the
exercises:

| Name | What it is |
|---|---|
| `cirros` | The CirrOS test image |
| `m1.tiny`, `m1.small`, `m1.medium`, … | Flavors |
| `demo-net` | A tenant network (a private range set in `remote-deploy.sh`), behind the router `demo-router` |
| `public1` | The lab's external network, range `LAB_EXT_CIDR` (see `config.example.env`); its floating IPs are reachable from the VM itself |
| `mykey` | A key pair; its private key is `~/.ssh/id_ecdsa` on the VM (`ssh -i ~/.ssh/id_ecdsa cirros@<floating-ip>`) |
| `demo1` | The test instance, with a floating IP from `public1` |

## What `deploy.sh` does, and why

| Step | Why |
|---|---|
| Turns off automatic upgrades (`unattended-upgrades`) | On an earlier lab they upgraded `libc6` and `systemd` in the middle of a deploy |
| Synchronises the clock (your `NTP_SERVER` if set) | Kolla-Ansible's prechecks refuse to deploy on an unsynchronised clock |
| Proxy for apt, pip, Docker and the containers, if `HTTPS_PROXY` is set; apt over HTTPS if `APT_HTTPS=yes` | Clouds whose projects have no direct Internet access |
| A veth pair as the lab's external network | One network interface is enough; floating IPs of the lab are reachable from the VM itself |
| Installs `docker` and `dbus-python` in Kolla-Ansible's virtual environment | On an all-in-one, Ansible runs that environment's Python on the VM itself |
| `enable_haproxy: "no"` and `enable_proxysql: "no"` | One node: no load balancer needed, and ProxySQL would take MariaDB's port |
| `global_physnet_mtu` set to the VM's MTU | Cloud networks often have an MTU below 1500; Neutron must know it |
| `nova_compute_virt_type: kvm` when the VM offers nested virtualisation, `qemu` otherwise | Instances are much faster with KVM; `qemu` still works |
| Checks that Docker really uses its proxy after `bootstrap-servers` | A Docker that ignores its proxy fails every image pull |
| `prechecks --use-test-images` when the images come from quay.io | Kolla-Ansible 2026.1 refuses the quay.io images, which are published for testing, unless told so; a lab is that use |

The full reasoning, with the errors met while building this lab, is in the
[all-in-one lab pattern](https://github.com/OzarLand/kolla-ansible-deployment-patterns/blob/main/topologies/all-in-one-lab-on-a-single-vm.md).

## When something fails

- `deploy.sh` prints the failing task of `kolla-ansible` and keeps the full logs on the VM, in `~/.quicklab/`.
  Fix the cause and run `./deploy.sh` again: it skips the steps already done.
- To start again from scratch: `./destroy.sh`, then `./create.sh`.

## Limits

- One node: no high availability, no Cinder, no Octavia. Enough to learn, break and repair the core services.
- Tested on one cloud so far (see the timings above). Reports from other clouds are welcome.

**Done for the day? Run `./destroy.sh`.**
