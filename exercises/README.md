# Exercises

Six short exercises on the all-in-one lab. Each one breaks one thing on purpose, shows you what an operator would
see, and walks you through the repair with a runbook from
[openstack-vm-runbooks](https://github.com/OzarLand/openstack-vm-runbooks). Every runbook used here was checked on a
lab (`status: lab-verified`).

| # | Exercise | Time | What you learn |
|---|---|---|---|
| 1 | [DHCP agents down](01-dhcp-agents-down.md) | 20 min | An instance can be `ACTIVE` and still have no address |
| 2 | [Metadata agents down](02-metadata-agents-down.md) | 20 min | Where an instance gets its SSH key, and what happens without it |
| 3 | [nova-compute down](03-nova-compute-down.md) | 15 min | The control plane and the instances are separate: one can fail without the other |
| 4 | [Restarting nova_libvirt](04-restart-nova-libvirt.md) | 10 min | A restart that looks risky, and why it is not |
| 5 | [Restarting the Open vSwitch agent](05-restart-ovs-agent.md) | 10 min | The agent programs the network; it does not carry the traffic |
| 6 | [Instance unreachable from outside](06-instance-unreachable-from-outside.md) | 20 min | Security groups and floating IPs, checked in order |

## Before every exercise

- The lab is running, and you followed its variant's guide to the end.
- You are logged in to the lab VM over SSH, with `sudo`.
- The OpenStack client is loaded, with the admin credentials:

  ```bash
  source ~/kolla-venv/bin/activate
  . /etc/kolla/admin-openrc.sh
  ```

The lab's scripts run Kolla-Ansible's `init-runonce`, which creates the resources the exercises use (the
[variant's guide](../variants/openstack-cloud/README.md#inside-the-lab) lists them too):

| Resource | Name |
|---|---|
| Test image | `cirros` |
| Flavor | `m1.tiny` |
| Tenant network, behind the router `demo-router` | `demo-net` |
| External network | `public1` |
| Key pair | `mykey` |
| External network's address range | the `LAB_EXT_CIDR` variable of the launch script, `10.99.0.0/24` by default |

The exercises write the external range as `10.99.0.0/24`. If you changed `LAB_EXT_CIDR` in `config.env` before
launching the lab, use your range instead.

On the all-in-one lab, the controller, the network node and the compute are the same VM: every command runs there.

These exercises break things on purpose. Run them only on this disposable lab, never on a platform someone relies
on.

## When you are done

Delete the lab: [delete everything when you are done](../README.md#delete-everything-when-you-are-done).
