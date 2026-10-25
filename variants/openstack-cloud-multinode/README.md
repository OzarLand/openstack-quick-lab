# OpenStack on several VMs of an OpenStack cloud (multinode)

Three scripts give you a multinode OpenStack (2026.1, deployed with Kolla-Ansible) on several VMs of any OpenStack
cloud, in a little over an hour, and delete it all when you are done. It is the variant for what one VM cannot show:
instances moving between computes, a compute that dies, and, in its larger size, a controller that dies.

> **Status:** the 3-VM size was run end to end on 2026-10-25 (figures below). The 5-VM size is written in the
> scripts but not yet run: its figures are estimates until its own run.

## The two sizes

The same scripts build both sizes. One setting in `config.env`, `CONTROLLERS`, chooses between them: `"1"` (the
default) or `"3"`.

| Size | `CONTROLLERS` | VMs | Roles | Required quota |
|---|---|---|---|---|
| **Small** (default) | `"1"` | 3 | 1 controller (also the network node and the deploy host), 2 computes | 12 vCPU, 32 GB RAM, 3 instances |
| **HA** (not yet run) | `"3"` | 5 | 3 controllers (also network nodes; controller 1 is the deploy host), 2 computes | 20 vCPU, 64 GB RAM, 5 instances |

`create.sh` picks, for each role, the smallest flavor with at least 4 vCPU and 50 GB of disk: 16 GB of RAM for a
controller, 8 GB for a compute. Set `CONTROLLER_FLAVOR` or `COMPUTE_FLAVOR` to force one. The lab also needs, in the
quota, one network and its subnet (the lab's external network, which the scripts create), one port per VM plus one
per controller and one more for controller 1 (one more again for the virtual IP with 3 controllers), and one floating
IP if you reach the lab from outside the cloud.

## The cost risk, before anything else

**Every VM costs money every hour it exists**, whether you use it or not, until you run `./destroy.sh`. This variant
runs three to five VMs: per hour, it costs about two and a half (3 VMs) to four and a half (5 VMs) times the single-VM
variant on the cloud it was measured on, and a lab forgotten overnight costs that much more too.

- **Prepaid cloud**: spending cannot go beyond the credit you loaded. Felcloud is prepaid: its
  [pricing page](https://felcloud.io/pricing) says *"Top up your balance and spend only what you loaded."* (checked
  on 2026-10-23), and it bills per second (same page). For another prepaid provider, check its own terms before you
  rely on it.
- **Pay-as-you-go cloud**: set a budget alert in your provider's console **before** you start, and destroy the lab
  the same day.
- `create.sh` prints the estimate from `COST_PER_HOUR_CONTROLLER` and `COST_PER_HOUR_COMPUTE` (the price of one VM
  of each flavor, copied from your provider's price list), multiplied by the number of VMs of each role, plus
  `COST_PER_HOUR_EXTRA` (what your provider bills apart: root volumes, the floating IP). It shows the total per hour
  and per day and waits for your confirmation. It refuses to start while the two prices are empty, exactly as in the
  single-VM variant.

### What a lab cost on Felcloud

Prices from [Felcloud's pricing page](https://felcloud.io/pricing), pay-as-you-go, per hour, as listed on
2026-10-23 and checked again on 2026-10-25. The EUR prices are the page's own, not a conversion of the TND ones. The
page says nothing about taxes.

| Resource | Used by the lab | TND per hour | EUR per hour |
|---|---|---|---|
| Flavor `G0.basic.4c16g` (4 vCPU, 16 GB, 50 GB disk) | Each controller | 0.196 | 0.057 |
| Flavor `G0.basic.4c8g` (4 vCPU, 8 GB, 50 GB disk) | Each compute | 0.140 | 0.041 |
| Floating IP | Only if you set `FLOATING_NETWORK` | 0.015 | 0.005 |

| | 3 VMs (small), measured | 5 VMs (HA), **estimate, not yet run** |
|---|---|---|
| Per hour | 0.476 TND (0.139 EUR) | 0.868 TND (0.253 EUR) |
| Each day the lab is left running | 11.42 TND (3.34 EUR) | 20.83 TND (6.07 EUR) |
| One full run, `create.sh` to `destroy.sh` | 0.52 TND (0.15 EUR): 65 min 27 s, measured on 2026-10-25 | _to be measured_ |

The measured figures are the measured duration multiplied by the listed prices, not an amount read from an invoice.
The 5-VM figures are the listed prices of the flavors `create.sh` would choose, multiplied by the number of VMs.
Add 0.015 TND (0.005 EUR) per hour if you use a floating IP. The exercises add their own time, at the hourly rate
above.

On Felcloud, set `COST_PER_HOUR_CONTROLLER="0.196"`, `COST_PER_HOUR_COMPUTE="0.140"`, `COST_PER_HOUR_EXTRA="0"`
(`"0.015"` with a floating IP) and `CURRENCY="TND"`, or the EUR prices with `CURRENCY="EUR"`.

## The three commands

| Script | What it does | Measured (3 VMs) |
|---|---|---|
| `create.sh` | Creates the VMs, their key, security group and ports, the lab's external network, and, if you want one, a floating IP for controller 1. Shows the estimated cost per hour and per day for all the VMs and asks before creating anything | 3 min 15 s |
| `deploy.sh` | Prepares every VM, installs Kolla-Ansible on controller 1 and deploys OpenStack across the VMs: the control plane and the network services on the controller(s), `nova-compute` on the computes. Ends with a test instance on each compute and a live migration | 59 min 34 s |
| `destroy.sh` | Deletes everything `create.sh` created, after asking, and checks that nothing is left | 1 min 14 s |

The same safety rules as the [single-VM variant](../openstack-cloud/README.md):

- **A cost estimate is required.** `create.sh` refuses to start without `COST_PER_HOUR_CONTROLLER` and
  `COST_PER_HOUR_COMPUTE`, unless you run `./create.sh --no-cost-estimate`.
- **Nothing is created before you confirm.** `create.sh` lists what it will create, with the estimated cost per hour
  and per day, and waits for your answer.
- **Every resource is named from the prefix.** Everything starts with `${PREFIX}${LAB}-` (default
  `quicklab-multi-1-`): the VMs `quicklab-multi-1-ctl-1` (and `-ctl-2`, `-ctl-3` with 3 controllers),
  `quicklab-multi-1-cmp-1` and `-cmp-2`; their ports `<vm>-port`, and `<vm>-ext` on the controllers;
  `quicklab-multi-1-ctl-1-gw`; `quicklab-multi-1-vip` with 3 controllers; the network `quicklab-multi-1-ext` and its
  subnet; `quicklab-multi-1-sg`; `quicklab-multi-1-key`; `<vm>-root` when a flavor has no disk. The floating IP
  carries the lab's name in its description. `destroy.sh` finds them all by these names, even if the creation failed
  half-way or `.state/` was lost. It deletes **everything** in the project whose name starts with `${PREFIX}${LAB}-`
  (after listing it and asking), so keep `PREFIX` specific to the lab: never a prefix that other resources of your
  project share.
- **Destroy checks that nothing is left**: it lists every kind of resource again after deleting, and fails loudly if
  anything of the lab is still there.

## What you need

- An account on an OpenStack cloud, with the quota of the size you choose (above).
- The same tools, `clouds.yaml`, network and access as the single-VM variant: see its
  [what you need](../openstack-cloud/README.md#what-you-need).
- The right to create a network, a subnet and ports with port security disabled in your project: the lab's
  floating IPs live on a network the scripts create.
- **Nested virtualisation** on the hosting cloud, so that instances on the lab's computes run with KVM. Live migration
  between two computes works with `qemu` too, but is much slower.
- **For the HA size**: the hosting cloud must let the controllers share a virtual IP (allowed address pairs on their
  ports) and pass VRRP (IP protocol 112) between them; the scripts use keepalived in unicast mode, so multicast is not
  needed. Check it before you pay for 5 VMs: the pattern's
  [context](https://github.com/OzarLand/kolla-ansible-deployment-patterns/blob/main/topologies/three-controllers-two-computes-nested-in-an-openstack-cloud.md#context)
  lists what was measured on the hosting cloud before designing the lab, and its
  [network design](https://github.com/OzarLand/kolla-ansible-deployment-patterns/blob/main/topologies/three-controllers-two-computes-nested-in-an-openstack-cloud.md#network-design)
  shows how the virtual IP and VRRP are set up. If your provider's documentation does not say whether allowed address
  pairs are available, `openstack extension list --network | grep -i allowed-address-pairs` on your account tells
  you; whether VRRP passes, only your provider or a test between two VMs can tell.

## Steps

```bash
cp config.example.env config.env
$EDITOR config.env            # OS_CLOUD, NETWORK, SSH_FROM, the two prices; CONTROLLERS="3" for the HA size
./create.sh                   # shows what it will create and the cost for all the VMs, asks, creates
./deploy.sh                   # about an hour; can be run again after a failure, it resumes
ssh -i .state/<prefix><lab>/id_ed25519 ubuntu@<controller-1-address>
source ~/kolla-venv/bin/activate; . /etc/kolla/admin-openrc.sh
openstack server list          # demo1 and demo2, one on each compute
./destroy.sh                  # when you are done: deletes everything, after asking
```

`<controller-1-address>` is controller 1's floating IP if you set `FLOATING_NETWORK`, its address in `NETWORK`
otherwise; `deploy.sh` prints the full `ssh` command at the end.

## Inside the lab

Work on **controller 1**: it is the deploy host, and the OpenStack client and the admin credentials are there.

- **The computes' names** in Nova are their VM names (`quicklab-multi-1-cmp-1`, `-cmp-2` by default):
  `openstack compute service list --service nova-compute` lists them.
- **To log in to another VM of the lab** from controller 1, use the lab's key, which `deploy.sh` copied there:
  `ssh -i ~/.ssh/quicklab_ed25519 ubuntu@<address-in-NETWORK>`. The addresses are in
  `.state/<prefix><lab>/state.env` on your computer (`ADDR_cmp_1`, `ADDR_cmp_2`, …), and in the Kolla-Ansible
  inventory `~/multinode` on controller 1.
- **The test resources** are those of the single-VM variant (`cirros`, `m1.tiny`, `demo-net`, `public1`, `mykey`; see
  its [inside the lab](../openstack-cloud/README.md#inside-the-lab)), with two differences: `demo-net` is
  `10.98.0.0/24`, and there are two test instances, `demo1` and `demo2`, one on each compute (the smoke test then
  live-migrates `demo1`, so both may end on the same compute). The floating IPs of `public1` are reachable from
  controller 1.
- **Horizon**: `deploy.sh` prints the SSH tunnel command at the end, as in the single-VM variant.

## What it lets you practise

With **3 VMs** (two computes):

- **Live migration** of a running instance from one compute to the other, without stopping it.
- **A compute that goes down**: fence it (make sure it is really off) before you evacuate its instances to the other
  compute.
- **Host maintenance**: disable a compute, drain it by migrating its instances away, work on it, put it back.
- **A build rescheduled on another compute**: when the first compute chosen fails the build, Nova retries on the
  other.

With **5 VMs** (three controllers), once that size has been run, in addition:

- **Losing a controller**, and what the other two keep doing.
- **The Galera (MariaDB) and RabbitMQ clusters**: their state, a member that leaves and rejoins.
- **VIP failover**: keepalived moves the API's virtual IP to another controller.
- **Quorum recovery**: bringing a cluster back when too many members were lost at once.

The exercises written for this variant are listed in [`exercises/`](../../exercises/README.md), marked
*multinode variant*.

## How the lab is built

The design follows the pattern
[Three controllers and two computes, nested inside an existing OpenStack cloud](https://github.com/OzarLand/kolla-ansible-deployment-patterns/blob/main/topologies/three-controllers-two-computes-nested-in-an-openstack-cloud.md).
Read it for the reasoning and the errors met while building such a lab; this page does not repeat it. Where the
scripts differ from that pattern:

| Pattern | These scripts | Why |
|---|---|---|
| A separate deploy host, with its own registry, proxy and NTP | Controller 1 is the deploy host; images from quay.io (or your `DOCKER_REGISTRY`), your `HTTPS_PROXY` and `NTP_SERVER` if you need them | One VM fewer to pay for |
| Controllers of about 8 vCPU and 16 GB | Controllers of 4 vCPU and 16 GB (computes as in the pattern: 4 vCPU, 8 GB) | The smallest flavors that ran the 3-VM lab; set `CONTROLLER_FLAVOR` for bigger controllers |
| keepalived in multicast | keepalived in unicast (3 controllers) | Some cloud networks drop multicast |
| A dedicated volume for each compute's instance store | The compute's own disk, at Kolla-Ansible's default location | Simpler; a full instance store can then fill the compute's root file system |
| 1 controller: not covered | No HAProxy, no keepalived, no ProxySQL; the API address is controller 1's | One controller needs no load balancer |

## Releases

Last run on 2026-10-25, 3-VM size, on Felcloud: OpenStack 2026.1, Kolla-Ansible 22.2.0, ansible-core 2.20.10, images
from quay.io through an HTTPS proxy, Ubuntu 24.04 VMs with nested KVM.

| Step of `deploy.sh` | Time |
|---|---|
| Prepare every VM (in parallel) | 3 min 20 s |
| Install Kolla-Ansible on controller 1 | 1 min 05 s |
| Write the configuration | 7 s |
| `bootstrap-servers` | 4 min 22 s |
| `prechecks` | 48 s |
| `pull` (images from quay.io) | 18 min 48 s |
| `deploy` | 22 min 06 s |
| `post-deploy`, client | 24 s |
| Smoke test (an instance on each compute, ping and SSH, a live migration) | 8 min 32 s |

During the smoke test, `demo1` live-migrated from one compute to the other in 35 s; a ping every 0.2 s lost 43 of
166 replies, about 8.6 s, around the switch-over.

The 5-VM size: _to be measured_.

## When something fails

- `deploy.sh` prints the failing task of `kolla-ansible` and keeps the logs on controller 1, in `~/.quicklab/`. Fix
  the cause and run `./deploy.sh` again: it skips the steps already done.
- To start again from scratch: `./destroy.sh`, then `./create.sh`.

## What it does not include

- **High availability with 3 VMs**: one controller is a single point of failure. Losing it stops the APIs, and, since
  the network services run on it too, routing and DHCP for the instances. Use the 5-VM size to practise HA.
- **Shared storage**: no Cinder, no Ceph. Instances live on the local disk of their compute, so live migration copies
  the disk (block migration) and evacuation rebuilds the instance from its image: the data on its disk is lost.
- **Load balancing (Octavia)**, production use, or support. It is a learning lab, deleted after use.
- **More than two computes** by default (`COMPUTES` accepts up to 4, not tested): enough to move instances, not to
  practise capacity planning.

**Done for the day? Run `./destroy.sh`: every VM costs money every hour it exists.**
