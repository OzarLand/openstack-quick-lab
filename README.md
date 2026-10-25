[← OzarLand home](https://github.com/OzarLand/ozarland)

# openstack-quick-lab

**Scripts that build a complete, disposable OpenStack (2026.1) on a cloud VM in about an hour, exercises to break
and repair it, and one command that deletes it all.**

On a prepaid cloud you cannot spend more than your credit; on any other cloud, set a budget alert first. Part of
[OzarLand](https://github.com/OzarLand/ozarland), a knowledge-sharing space for OpenStack operators.

## Pick your lab

| | [Single VM](variants/openstack-cloud/README.md) (`openstack-cloud`) | [Multinode](variants/openstack-cloud-multinode/README.md) (`openstack-cloud-multinode`) |
|---|---|---|
| **What you can practise** | The core services: DHCP, metadata, Nova, Open vSwitch, security groups and floating IPs (exercises 1 to 6) | 3 VMs: live migration, a failed compute, host maintenance (exercises 7 to 9). 5 VMs: also a failed controller, Galera and RabbitMQ, VIP failover |
| **VMs and quota** | 1 VM: 4 vCPU, 16 GB RAM, 50 GB disk | 3 VMs: 12 vCPU, 32 GB RAM. 5 VMs (`CONTROLLERS="3"`): 20 vCPU, 64 GB RAM |
| **Time** | About 1 hour (57 min measured, `create.sh` to `destroy.sh`) | 3 VMs: 65 min measured, `create.sh` to `destroy.sh`. 5 VMs: 73 min measured, `create.sh` to the end of `deploy.sh` |
| **Cost of one run** | 0.19 TND (0.05 EUR); 0.20 TND (0.06 EUR) with a floating IP | 3 VMs: 0.52 TND (0.15 EUR). 5 VMs: 1.05 TND (0.31 EUR) to build the lab |
| **Cost of each forgotten day** | 4.70 TND (1.37 EUR); 5.06 TND (1.49 EUR) with a floating IP | 3 VMs: 11.42 TND (3.34 EUR). 5 VMs: 20.83 TND (6.07 EUR) |

New to OpenStack? Start with the single VM. The costs are the measured duration multiplied by the reference cloud's listed prices on
2026-10-23 (not an invoice); each guide has the details. Felcloud was used to build and test OzarLand's labs because
its prepaid model fits a lab with no surprise bill. Its [pricing page](https://felcloud.io/pricing) says: "Top up your
balance and spend only what you loaded." (checked on 2026-10-23).

On any cloud: on a **prepaid** one, load only the credit you are ready to spend; on a **pay-as-you-go** one, you are
billed for every hour the VMs, their volumes and floating IPs exist, so **set a budget alert** in your provider's
console before you start. A variant for a personal machine with KVM, with no cloud cost, is
[wanted](https://github.com/OzarLand/openstack-quick-lab/issues/5).

## How it works

```mermaid
flowchart LR
    cost["Your price per hour<br/>in config.env"] --> create["create.sh<br/>shows the cost, asks,<br/>creates the VMs"]
    create --> deploy["deploy.sh<br/>installs OpenStack"]
    deploy --> ex["Exercises<br/>break and repair"]
    ex --> destroy["destroy.sh<br/>deletes everything"]
    destroy --> check["Check that<br/>nothing is left"]
```

`create.sh` shows the estimated cost per hour and asks before creating anything. `deploy.sh` deploys OpenStack with
[Kolla-Ansible](https://docs.openstack.org/kolla-ansible/latest/). `destroy.sh` deletes what `create.sh` created and
fails loudly if anything is left.

## The three commands

You need an OpenStack cloud account, its `clouds.yaml`, `bash`, `ssh`, `python3` and the OpenStack client: the
guide lists them. In the variant's directory:

```bash
cp config.example.env config.env && $EDITOR config.env   # your cloud, network and price per hour
./create.sh     # shows what it will create and the cost, asks, creates
./deploy.sh     # about an hour; run it again after a failure, it resumes
./destroy.sh    # when you are done: deletes everything, after asking
```

Then do your first exercise: [DHCP agents down](exercises/01-dhcp-agents-down.md).

## Delete everything when you are done

> 🛑 **A lab left running keeps costing money** on a pay-as-you-go cloud, and keeps using credit on a prepaid one.
>
> 1. Run `./destroy.sh` in the variant's directory. After asking, it deletes everything `create.sh` created (VMs,
>    key, security group, ports, floating IP, root volumes if any) and fails loudly if anything is left.
> 2. Check in your provider's console, or with `openstack server list`, `openstack volume list` and
>    `openstack floating ip list`, that nothing from the lab is left.
> 3. On a pay-as-you-go cloud, check the next day that the usage really stopped.

Every exercise ends with the same reminder: **Done for the day? Destroy the lab: every hour it exists costs money.**

## Exercises

Each exercise breaks one thing on purpose and repairs it with a runbook from
[openstack-vm-runbooks](https://github.com/OzarLand/openstack-vm-runbooks). [All the exercises](exercises/README.md).

| # | Exercise | Needs | Runbook |
|---|---|---|---|
| 1 | [DHCP agents down: a new instance gets no address](exercises/01-dhcp-agents-down.md) | Single VM | [New instance gets no IP](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/new-instance-gets-no-ip-dhcp-agents-down.md) |
| 2 | [Metadata agents down: a new instance gets no SSH key](exercises/02-metadata-agents-down.md) | Single VM | [New instance boots without metadata](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/new-instance-boots-without-metadata.md) |
| 3 | [nova-compute down: instances keep running](exercises/03-nova-compute-down.md) | Single VM | [nova-compute down, instances still running](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/recovery/nova-compute-down-instances-still-running.md) |
| 4 | [Restarting nova_libvirt without stopping instances](exercises/04-restart-nova-libvirt.md) | Single VM | [Restarting nova_libvirt does not stop instances](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/lifecycle/restarting-nova-libvirt-does-not-stop-instances.md) |
| 5 | [Restarting the Open vSwitch agent without cutting the network](exercises/05-restart-ovs-agent.md) | Single VM | [Restarting the OVS agent does not cut instances](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/restarting-the-ovs-agent-does-not-cut-instances.md) |
| 6 | [An instance unreachable from outside](exercises/06-instance-unreachable-from-outside.md) | Single VM | [Instance unreachable from outside](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/instance-unreachable-from-outside.md) |
| 7 | [A compute goes down: fence it before you evacuate](exercises/07-compute-down-fence-before-evacuate.md) | Multinode | [Fence it before you evacuate](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/recovery/compute-host-failure-fence-before-evacuate.md) |
| 8 | [Drain a compute for planned maintenance](exercises/08-drain-a-compute-for-maintenance.md) | Multinode | [Moving instances off a host for maintenance (draft)](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/migration/moving-instances-off-a-host-for-maintenance.md) |
| 9 | [Live migration between the two computes](exercises/09-live-migration-between-computes.md) | Multinode | [Moving instances off a host for maintenance (draft)](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/migration/moving-instances-off-a-host-for-maintenance.md) |

> **In one minute (for managers)**
>
> - **What:** a complete, disposable OpenStack for learning and for trying a procedure before production.
> - **Cost:** one run on the single VM measured about 0.05 EUR (0.19 TND) for 57 minutes. The script shows the cost
>   per hour and asks first.
> - **Risk:** the VMs cost money every hour they exist. Use a prepaid cloud or a budget alert; one command deletes
>   everything.
> - **Who:** anyone comfortable with a terminal and SSH; no OpenStack knowledge needed to start.
> - **Not included:** production use, support, block storage (Cinder), load balancing (Octavia); high availability
>   only on the 5-VM multinode size.

## Going further

- Who this is for: newcomers who learn by doing, and operators who want a disposable lab to try a runbook. The
  [newcomer path](https://github.com/OzarLand/ozarland/tree/main/newcomers) explains the vocabulary as you go.
- How the labs are built: the [all-in-one lab pattern](https://github.com/OzarLand/kolla-ansible-deployment-patterns/blob/main/topologies/all-in-one-lab-on-a-single-vm.md)
  and the [multinode pattern](https://github.com/OzarLand/kolla-ansible-deployment-patterns/blob/main/topologies/three-controllers-two-computes-nested-in-an-openstack-cloud.md).
  Each guide states the releases its scripts were last run on.
- This repository never contains credentials (`clouds.yaml` with secrets, `passwords.yml`) or marketing. Keep yours
  out of any fork or pull request.
- New variants, exercises and fixes are welcome: [CONTRIBUTING.md](CONTRIBUTING.md). Any provider can be added as
  a variant on equal terms; nothing in the exercises depends on the provider.

## License

[Apache-2.0](LICENSE).
