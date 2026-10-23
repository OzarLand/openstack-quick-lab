[← OzarLand home](https://github.com/OzarLand/ozarland)

# openstack-quick-lab

**Try OpenStack in about one hour on a single VM, break it on purpose, repair it with real runbooks, and delete
everything when you are done, with no risk of a surprise bill.**

Part of [OzarLand](https://github.com/OzarLand/ozarland), a knowledge-sharing space for OpenStack operators.

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
- **Guided exercises** in [`exercises/`](exercises/README.md): each one breaks one thing and repairs it with a runbook
  from [openstack-vm-runbooks](https://github.com/OzarLand/openstack-vm-runbooks) that was checked on a lab.
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

## Where the lab runs, and what it costs

| Variant | Runs on | Cost risk | What to do before you start |
|---|---|---|---|
| [`openstack-cloud`](variants/openstack-cloud/README.md) on **Felcloud** | [Felcloud](https://felcloud.io/), a prepaid cloud service built on OpenStack | Spending cannot exceed the credit loaded | Load only the credit you are ready to spend. [Felcloud's pricing page](https://felcloud.io/pricing) says: "Top up your balance and spend only what you loaded" (checked on 2026-10-23); billed per second (same page). At its listed prices on 2026-10-23, one full run (57 min) came to 0.19 TND (0.05 EUR), and each extra day the lab is left running costs 4.70 TND (1.37 EUR); with a floating IP, 0.20 TND and 5.06 TND (0.06 and 1.49 EUR): [details](variants/openstack-cloud/README.md#what-a-lab-cost-on-felcloud) |
| [`openstack-cloud`](variants/openstack-cloud/README.md) on a **pay-as-you-go** OpenStack cloud | Any OpenStack cloud billed by usage | Billed for every hour the VM, its volumes and its floating IPs exist, until you delete them | **Set a budget alert** in your provider's console before launching, and delete the lab when you are done |
| Personal machine | Your own computer or server, with hardware virtualisation | **No cloud cost** | Not written yet: contributions welcome, see [CONTRIBUTING.md](CONTRIBUTING.md) |

Felcloud is the variant recommended to start with, for one reason only: with a prepaid credit, a forgotten lab
cannot produce a bill larger than the credit. Any other provider can be added as a variant on equal terms; nothing
in the exercises depends on the provider.

The OzarLand maintainer has a professional connection with Felcloud.

## Delete everything when you are done

A lab left running keeps costing money on a pay-as-you-go cloud, and keeps using credit on a prepaid one.

1. Run the variant's delete command. For the OpenStack cloud variant: `./destroy.sh` in
   [`variants/openstack-cloud/`](variants/openstack-cloud/README.md). After asking, it deletes everything
   `create.sh` created (the VM, its key, security group, port, floating IP and root volume if any) and fails loudly
   if anything is left.
2. Check in your provider's console (or with `openstack server list`, `openstack volume list`,
   `openstack floating ip list`) that nothing from the lab is left.
3. On a pay-as-you-go cloud, check the next day that the usage really stopped.

Every exercise ends with the same reminder.

**Done for the day? Destroy the lab: every hour it exists costs money.**

## Exercises

| # | Exercise | Runbook used |
|---|---|---|
| 1 | [DHCP agents down: a new instance gets no address](exercises/01-dhcp-agents-down.md) | [New instance gets no IP](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/new-instance-gets-no-ip-dhcp-agents-down.md) |
| 2 | [Metadata agents down: a new instance gets no SSH key](exercises/02-metadata-agents-down.md) | [New instance boots without metadata](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/new-instance-boots-without-metadata.md) |
| 3 | [nova-compute down: instances keep running](exercises/03-nova-compute-down.md) | [nova-compute down, instances still running](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/recovery/nova-compute-down-instances-still-running.md) |
| 4 | [Restarting nova_libvirt without stopping instances](exercises/04-restart-nova-libvirt.md) | [Restarting nova_libvirt does not stop instances](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/lifecycle/restarting-nova-libvirt-does-not-stop-instances.md) |
| 5 | [Restarting the Open vSwitch agent without cutting the network](exercises/05-restart-ovs-agent.md) | [Restarting the OVS agent does not cut instances](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/restarting-the-ovs-agent-does-not-cut-instances.md) |
| 6 | [An instance unreachable from outside](exercises/06-instance-unreachable-from-outside.md) | [Instance unreachable from outside](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/instance-unreachable-from-outside.md) |

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
