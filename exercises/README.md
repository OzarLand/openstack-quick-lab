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
- You are logged in to the lab VM over SSH, with `sudo`, and the OpenStack admin credentials are loaded as the
  variant's guide explains.
- You know the names the guide gave to the test image, flavor, tenant network, external network and key pair. The
  exercises write them `<image>`, `<flavor>`, `<tenant-network>`, `<external-network>` and `<key>`.

On the all-in-one lab, the controller, the network node and the compute are the same VM: every command runs there.

These exercises break things on purpose. Run them only on this disposable lab, never on a platform someone relies
on.

## When you are done

Delete the lab: [delete everything when you are done](../README.md#delete-everything-when-you-are-done).
