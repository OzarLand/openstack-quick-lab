# OpenStack on several VMs of an OpenStack cloud (multinode)

Three scripts give you a multinode OpenStack (2026.1, deployed with Kolla-Ansible) on several VMs of any OpenStack
cloud, and delete it all when you are done. It is the variant for what one VM cannot show: instances moving between
computes, a compute that dies, and, in its larger size, a controller that dies.

> **Status:** the scripts are being written and tested; they arrive in their own pull request, with measured timings
> and costs. Every value marked _to be measured_ below is filled in from that run. Until then, treat this page as the
> design of the variant, not as a tested procedure.

## The two sizes

The same scripts build both sizes; one setting in `config.env` chooses between them
(_name of the setting: given by the scripts' pull request_).

| Size | VMs | Roles | Required quota |
|---|---|---|---|
| **Small** (default) | 3 | 1 controller (also the network node), 2 computes | 12 vCPU, 48 GB RAM, 3 instances |
| **HA** | 5 | 3 controllers (also network nodes), 2 computes | 20 vCPU, 80 GB RAM, 5 instances |

Each VM uses the same flavor as the single-VM variant: 4 vCPU, 16 GB RAM, 50 GB disk. Add one floating IP to the
quota if you reach the lab from outside the cloud.

## The cost risk, before anything else

**Every VM costs money every hour it exists**, whether you use it or not, until you run `./destroy.sh`. This variant
runs three to five VMs, so it costs three to five times the single-VM variant per hour, and a lab forgotten overnight
costs three to five times as much too.

- **Prepaid cloud**: spending cannot go beyond the credit you loaded. Felcloud is prepaid: its
  [pricing page](https://felcloud.io/pricing) says *"Top up your balance and spend only what you loaded."* (checked
  on 2026-10-23), and it bills per second (same page). For another prepaid provider, check its own terms before you
  rely on it.
- **Pay-as-you-go cloud**: set a budget alert in your provider's console **before** you start, and destroy the lab
  the same day.
- `create.sh` prints the estimate from `COST_PER_HOUR` (the price of **one** VM, copied from your provider's price
  list) multiplied by the number of VMs, and waits for your confirmation. It refuses to start while `COST_PER_HOUR`
  is empty, exactly as in the single-VM variant.

### Estimated cost on Felcloud

> **Estimate, not a measurement.** These figures are the number of VMs multiplied by the listed price of one flavor.
> They are replaced by measured figures after the first full run.

Flavor `G0.basic.4c16g` (4 vCPU, 16 GB, 50 GB disk), pay-as-you-go, as listed on
[Felcloud's pricing page](https://felcloud.io/pricing) on 2026-10-23: 0.196 TND per hour per VM. The page says nothing
about taxes. A floating IP, if you use one, adds 0.015 TND per hour.

| | 3 VMs (small) | 5 VMs (HA) |
|---|---|---|
| Per hour, estimated | about 0.59 TND | about 0.98 TND |
| Each day the lab is left running, estimated | about 14 TND | about 23.5 TND |
| One full run, `create.sh` to `destroy.sh` | _to be measured_ | _to be measured_ |
| One exercise session, as used in practice | _to be measured_ | _to be measured_ |

On Felcloud, set `COST_PER_HOUR="0.196"` and `CURRENCY="TND"` (`0.211` with a floating IP on one VM).

## The three commands

| Script | What it does | Measured |
|---|---|---|
| `create.sh` | Creates the VMs, their key, security group and ports, and, if you want one, a floating IP. Shows the estimated cost per hour for all the VMs and asks before creating anything | _to be measured_ |
| `deploy.sh` | Installs Kolla-Ansible and deploys OpenStack across the VMs: the control plane on the controller(s), `nova-compute` on the two computes. Ends with a test instance on each compute | _to be measured_ |
| `destroy.sh` | Deletes everything `create.sh` created, after asking, and checks that nothing is left | _to be measured_ |

The same safety rules as the [single-VM variant](../openstack-cloud/README.md):

- **A cost estimate is required.** `create.sh` refuses to start without `COST_PER_HOUR`, unless you run
  `./create.sh --no-cost-estimate`.
- **Nothing is created before you confirm.** `create.sh` lists what it will create, with the estimated cost per hour,
  and waits for your answer.
- **Every resource is named from the prefix.** All the VMs, ports, volumes and the security group start with your
  `PREFIX` and `LAB` (default `quicklab-` and `1`), so `destroy.sh` finds them even if the creation failed half-way or
  `.state/` was lost (_exact names: given by the scripts' pull request_).
- **Destroy checks that nothing is left**, and fails loudly if anything is.

## What you need

- An account on an OpenStack cloud, with the quota of the size you choose (above).
- The same tools, `clouds.yaml`, network and access as the single-VM variant: see its
  [what you need](../openstack-cloud/README.md#what-you-need).
- **Nested virtualisation** on the hosting cloud, so that instances on the lab's computes run with KVM. Live migration
  between two computes works with `qemu` too, but is much slower.
- **For the HA size**: the hosting cloud must let the controllers share a virtual IP (allowed address pairs on their
  ports) and pass VRRP between them. The pattern below explains how to check it before you start.

## Steps

```bash
cp config.example.env config.env
$EDITOR config.env            # as for the single-VM variant, plus the size (3 or 5 VMs)
./create.sh                   # shows what it will create and the cost for all the VMs, asks, creates
./deploy.sh                   # time: to be measured
./destroy.sh                  # when you are done: deletes everything, after asking
```

How to log in to the controller and load the admin credentials: _to be filled in from the scripts_.

## What it lets you practise

With **3 VMs** (two computes):

- **Live migration** of a running instance from one compute to the other, without stopping it.
- **A compute that goes down**: fence it (make sure it is really off) before you evacuate its instances to the other
  compute.
- **Host maintenance**: disable a compute, drain it by migrating its instances away, work on it, put it back.
- **A build rescheduled on another compute**: when the first compute chosen fails the build, Nova retries on the
  other.

With **5 VMs** (three controllers), in addition:

- **Losing a controller**, and what the other two keep doing.
- **The Galera (MariaDB) and RabbitMQ clusters**: their state, a member that leaves and rejoins.
- **VIP failover**: keepalived moves the API's virtual IP to another controller.
- **Quorum recovery**: bringing a cluster back when too many members were lost at once.

The exercises written for this variant are listed in [`exercises/`](../../exercises/README.md), marked
*multinode variant*.

## How the lab is built

The design (one port per network, the virtual IP through allowed address pairs, the MTU of the hosting cloud, the
instance store on the computes, the settings that differ from Kolla-Ansible's defaults) follows the pattern
[Three controllers and two computes, nested inside an existing OpenStack cloud](https://github.com/OzarLand/kolla-ansible-deployment-patterns/blob/main/topologies/three-controllers-two-computes-nested-in-an-openstack-cloud.md).
Read it for the reasoning and the errors met while building such a lab; this page does not repeat it. Where the
scripts differ from that pattern (VM sizes, a deploy host or not), the scripts' pull request says so.

## Releases

_To be filled in from the first full run: OpenStack and Kolla-Ansible releases, the date, the cloud, and the timings
of each step._

## What it does not include

- **High availability with 3 VMs**: one controller is a single point of failure. Losing it stops the APIs, and, since
  the network services run on it too, routing and DHCP for the instances. Use the 5-VM size to practise HA.
- **Shared storage**: no Cinder, no Ceph. Instances live on the local disk of their compute, so live migration copies
  the disk (block migration) and evacuation rebuilds the instance from its image: the data on its disk is lost.
- **Load balancing (Octavia)**, production use, or support. It is a learning lab, deleted after use.
- **More than two computes**: enough to move instances, not to practise capacity planning.

**Done for the day? Run `./destroy.sh`: every VM costs money every hour it exists.**
