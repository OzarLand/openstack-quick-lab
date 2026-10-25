[← OzarLand home](https://github.com/OzarLand/ozarland)

# openstack-quick-lab

**Try OpenStack in about one hour on a single VM. On a prepaid cloud you cannot spend more than your credit; on any
other cloud, set a budget alert first.**

Part of [OzarLand](https://github.com/OzarLand/ozarland), a knowledge-sharing space for OpenStack operators.

**Requires:** an OpenStack cloud account with a quota of 4 vCPU, 16 GB of RAM and 50 GB of disk (one VM). The
[multinode variant](variants/openstack-cloud-multinode/README.md) needs 12 vCPU and 32 GB (3 VMs) or 20 vCPU and 64 GB
(5 VMs). A variant for a personal machine with KVM, with no cloud cost, is
[wanted](https://github.com/OzarLand/openstack-quick-lab/issues/5).

> **In one minute (for managers)**
>
> - **What it is:** scripts that build a complete, disposable OpenStack (2026.1) on one virtual machine (or on 3 to 5
>   with the multinode variant), and eleven exercises where you break it on purpose and repair it with documented
>   procedures. For learning and for trying a procedure before production.
> - **What it costs:** one VM for about an hour. One full run measured on the reference cloud: about **0.05 EUR
>   (0.19 TND) for 57 minutes**. The script shows the estimated cost per hour and asks before creating anything.
> - **Multinode variant:** 3 VMs (1 controller, 2 computes), growing to 5
>   (3 controllers) with one setting, to practise migration, a failed compute and, with 5 VMs, a failed controller.
>   Measured: 0.52 TND (0.15 EUR) for a 65-minute run with 3 VMs; 1.05 TND (0.31 EUR) to build the 5-VM lab (73 min).
> - **The risk:** every VM costs money every hour it exists, until it is deleted. On a prepaid cloud, such as
>   [Felcloud](https://felcloud.io/), the recommended starting point, spending cannot go beyond the credit loaded.
>   On a pay-as-you-go cloud, set a budget alert first. One command deletes everything.
> - **Who can run it:** anyone comfortable with a terminal and SSH; no OpenStack knowledge needed to start.
> - **What it does not include:** high availability (except the multinode variant with 5 VMs), production use, block
>   storage (Cinder), load balancing (Octavia), or support. It is a learning lab, deleted after use.

## Who this is for

- You are new to OpenStack and learn by doing: you want a running cloud you can break and repair before you read
  about it.
- You are an operator who wants a disposable lab to try a runbook or a change before production.

You need basic Linux skills (SSH, `sudo`, editing a file). You do not need to know OpenStack yet: the
[newcomer path](https://github.com/OzarLand/ozarland/tree/main/newcomers) explains the vocabulary as you go.

## What you get

- An **all-in-one OpenStack** on one VM, deployed with [Kolla-Ansible](https://docs.openstack.org/kolla-ansible/latest/):
  OpenStack 2026.1 with Keystone, Glance, Nova, Neutron (Open vSwitch), Placement, Heat and Horizon, plus the test
  image, networks, key pair and test instance the exercises use. The variant's guide lists exactly what it creates.
- Or a **multinode OpenStack** on 3 VMs (1 controller, 2 computes) or 5 VMs (3 controllers, 2 computes), with the
  [multinode variant](variants/openstack-cloud-multinode/README.md): for moving instances between computes, a failed
  compute, and, with 5 VMs, a failed controller.
- **Guided exercises** in [`exercises/`](exercises/README.md): each one breaks one thing and repairs it with a
  documented procedure, most often a runbook from
  [openstack-vm-runbooks](https://github.com/OzarLand/openstack-vm-runbooks). The table [below](#exercises) says which
  variant each one needs, and which were run on a lab.
- **One command that deletes everything** the lab created, and checks that nothing is left.

The lab is built the way the [all-in-one lab pattern](https://github.com/OzarLand/kolla-ansible-deployment-patterns/blob/main/topologies/all-in-one-lab-on-a-single-vm.md)
describes. Each variant states the OpenStack and Kolla-Ansible releases its scripts were last run on.

## Quick start

1. **Choose where the lab runs** in the table below, and read that variant's cost line before anything else.
2. **Follow the variant's guide.** For an OpenStack cloud: [`variants/openstack-cloud/`](variants/openstack-cloud/README.md).
   `create.sh` shows the estimated cost per hour and asks you to confirm before creating anything; `deploy.sh` then
   deploys the lab in about an hour (57 minutes from `create.sh` to `destroy.sh` on the guide's last measured run).
3. **Do your first exercise:** [DHCP agents down](exercises/01-dhcp-agents-down.md). Then
   [delete everything](#delete-everything-when-you-are-done).

New to OpenStack? Start with the single-VM variant and exercises 1 to 6. Come to the
[multinode variant](variants/openstack-cloud-multinode/README.md) when you want to move instances between computes or
lose a controller: it costs two and a half to four and a half times as much per hour.

## Where the lab runs, and what it costs

| Variant | Runs on | Cost risk | What to do before you start |
|---|---|---|---|
| [`openstack-cloud`](variants/openstack-cloud/README.md) on **Felcloud** | [Felcloud](https://felcloud.io/), a prepaid cloud service built on OpenStack | Spending cannot exceed the credit loaded | Load only the credit you are ready to spend. [Felcloud's pricing page](https://felcloud.io/pricing) says: "Top up your balance and spend only what you loaded" (checked on 2026-10-23); billed per second (same page). At its listed prices on 2026-10-23, one full run (57 min) came to 0.19 TND (0.05 EUR), and each extra day the lab is left running costs 4.70 TND (1.37 EUR); with a floating IP, 0.20 TND and 5.06 TND (0.06 and 1.49 EUR): [details](variants/openstack-cloud/README.md#what-a-lab-cost-on-felcloud) |
| [`openstack-cloud`](variants/openstack-cloud/README.md) on a **pay-as-you-go** OpenStack cloud | Any OpenStack cloud billed by usage | Billed for every hour the VM, its volumes and its floating IPs exist, until you delete them | **Set a budget alert** in your provider's console before launching, and delete the lab when you are done |
| [`openstack-cloud-multinode`](variants/openstack-cloud-multinode/README.md), 3 or 5 VMs | Any OpenStack cloud with a quota of 12 vCPU and 32 GB of RAM (3 VMs) or 20 vCPU and 64 GB (5 VMs) | Billed for every hour each VM exists. At Felcloud's listed prices, 3 VMs: one full run (65 min) came to 0.52 TND (0.15 EUR), and each extra day costs 11.42 TND (3.34 EUR); 5 VMs: building the lab (73 min) came to 1.05 TND (0.31 EUR), and each extra day costs 20.83 TND (6.07 EUR): [details](variants/openstack-cloud-multinode/README.md#what-a-lab-cost-on-felcloud) | The same as for `openstack-cloud`: credit or budget alert first, and destroy the lab the same day |
| Personal machine | Your own computer or server, with hardware virtualisation | **No cloud cost** | Not written yet: [issue #5](https://github.com/OzarLand/openstack-quick-lab/issues/5); contributions welcome, see [CONTRIBUTING.md](CONTRIBUTING.md) |

Felcloud is the variant recommended to start with, for one reason only: with a prepaid credit, a forgotten lab
cannot produce a bill larger than the credit. Any other provider can be added as a variant on equal terms; nothing
in the exercises depends on the provider.

Felcloud was used to build and test OzarLand's labs because its prepaid model fits a lab with no surprise bill.

## Delete everything when you are done

A lab left running keeps costing money on a pay-as-you-go cloud, and keeps using credit on a prepaid one.

1. Run the variant's delete command: `./destroy.sh` in
   [`variants/openstack-cloud/`](variants/openstack-cloud/README.md) or
   [`variants/openstack-cloud-multinode/`](variants/openstack-cloud-multinode/README.md). After asking, it deletes
   everything `create.sh` created (the VMs, their key, security group, ports, floating IP and root volumes if any; the
   multinode variant's network too) and fails loudly if anything is left.
2. Check in your provider's console (or with `openstack server list`, `openstack volume list`,
   `openstack floating ip list`) that nothing from the lab is left.
3. On a pay-as-you-go cloud, check the next day that the usage really stopped.

Every exercise ends with the same reminder.

**Done for the day? Destroy the lab: every hour it exists costs money.**

## Exercises

Exercises 1 to 6 were written and run on the single-VM variant; 7 to 11 need the multinode variant, and 10 and 11
its 5-VM size. The
[exercises' guide](exercises/README.md) has the time and what each one teaches.

| # | Exercise | Variant | Procedure used | Run on a lab |
|---|---|---|---|---|
| 1 | [DHCP agents down: a new instance gets no address](exercises/01-dhcp-agents-down.md) | Single VM | [New instance gets no IP](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/new-instance-gets-no-ip-dhcp-agents-down.md) | Yes |
| 2 | [Metadata agents down: a new instance gets no SSH key](exercises/02-metadata-agents-down.md) | Single VM | [New instance boots without metadata](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/new-instance-boots-without-metadata.md) | Yes |
| 3 | [nova-compute down: instances keep running](exercises/03-nova-compute-down.md) | Single VM | [nova-compute down, instances still running](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/recovery/nova-compute-down-instances-still-running.md) | Yes |
| 4 | [Restarting nova_libvirt without stopping instances](exercises/04-restart-nova-libvirt.md) | Single VM | [Restarting nova_libvirt does not stop instances](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/lifecycle/restarting-nova-libvirt-does-not-stop-instances.md) | Yes |
| 5 | [Restarting the Open vSwitch agent without cutting the network](exercises/05-restart-ovs-agent.md) | Single VM | [Restarting the OVS agent does not cut instances](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/restarting-the-ovs-agent-does-not-cut-instances.md) | Yes |
| 6 | [An instance unreachable from outside](exercises/06-instance-unreachable-from-outside.md) | Single VM | [Instance unreachable from outside](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/instance-unreachable-from-outside.md) | Yes |
| 7 | [A compute goes down: fence it before you evacuate](exercises/07-compute-down-fence-before-evacuate.md) | Multinode | [Compute host failure: fence before evacuate](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/recovery/compute-host-failure-fence-before-evacuate.md) | Yes |
| 8 | [Drain a compute for planned maintenance](exercises/08-drain-a-compute-for-maintenance.md) | Multinode | [Moving instances off a host for maintenance](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/migration/moving-instances-off-a-host-for-maintenance.md) (draft) | Yes |
| 9 | [Live migration between the two computes](exercises/09-live-migration-between-computes.md) | Multinode | [Moving instances off a host for maintenance](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/migration/moving-instances-off-a-host-for-maintenance.md) (draft) | Yes |
| 10 | [Lose one controller: what keeps working](exercises/10-lose-one-controller.md) | Multinode, 5 VMs | [Three controllers and two computes](https://github.com/OzarLand/kolla-ansible-deployment-patterns/blob/main/topologies/three-controllers-two-computes-nested-in-an-openstack-cloud.md) (pattern) | Not yet |
| 11 | [Lose two controllers: quorum lost, and recovered](exercises/11-lose-two-controllers-quorum.md) | Multinode, 5 VMs | [MariaDB recovery](https://github.com/OzarLand/kolla-ansible-deployment-patterns/blob/main/deployment-errors/unattended-upgrades-during-deploy-breaks-the-mariadb-cluster.md#recover-the-failed-deploy) (deployment-error page) | Not yet |

## What this repository never contains

- No credentials: no cloud credentials, no `clouds.yaml` with secrets, no `passwords.yml`. Keep yours out of any
  fork or pull request.
- No marketing: no prices beyond the cost estimate shown before launch, no promotional text, no logos.

## Going further

- [OzarLand home](https://github.com/OzarLand/ozarland): what the community is and how it works.
- [Newcomer path](https://github.com/OzarLand/ozarland/tree/main/newcomers): the services, a glossary, how to read a
  runbook.
- [openstack-vm-runbooks](https://github.com/OzarLand/openstack-vm-runbooks) and
  [kolla-ansible-deployment-patterns](https://github.com/OzarLand/kolla-ansible-deployment-patterns): the pages the
  exercises come from.

## Contributing

New variants, exercises and fixes are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[Apache-2.0](LICENSE).
