# Exercises

Six short exercises on the all-in-one lab, three on the multinode variant and two on its 3-controller size. Each
one breaks one thing on purpose, shows you what an operator would see, and walks you through the repair with a
runbook from [openstack-vm-runbooks](https://github.com/OzarLand/openstack-vm-runbooks) (exercises 10 and 11 use
pages of [kolla-ansible-deployment-patterns](https://github.com/OzarLand/kolla-ansible-deployment-patterns)
instead). The runbooks of exercises 1 to 7 were
checked on a lab (`status: lab-verified`); exercises 8 and 9 use a runbook still marked `status: draft`.

## How an exercise works

```mermaid
flowchart LR
    brk["Break<br/>something"] --> see["See the<br/>symptom"]
    see --> rb["Follow the<br/>runbook"]
    rb --> fix["Repair"]
    fix --> ok["Verify"]
```

Every page follows these steps in order, then cleans up what it created and reminds you to delete the lab.

> **Why the exercises use `systemctl`, not `docker`, to stop a service**
>
> Kolla-Ansible gives each container a systemd unit, `/etc/systemd/system/kolla-<container>-container.service`
> ([release note](https://github.com/openstack/kolla-ansible/blob/stable/2026.1/releasenotes/notes/add-systemd-container-control-b85dff9ec5fae313.yaml);
> [the code that writes the unit](https://github.com/openstack/kolla-ansible/blob/stable/2026.1/ansible/module_utils/kolla_systemd_worker.py)). It is still the case in
> 2026.1, the release of these labs.
>
> - The unit starts the container with `docker start -a <container>` and stops it with `docker stop`.
> - With Kolla-Ansible's default `docker_restart_policy: "unless-stopped"`
>   ([`ansible/group_vars/all/common.yml`](https://github.com/openstack/kolla-ansible/blob/stable/2026.1/ansible/group_vars/all/common.yml)), the unit gets `Restart=always`.
> - So `docker stop <container>` alone is undone: systemd starts the container again. `systemctl stop
>   kolla-<container>-container.service` keeps it stopped.
> - The delay before systemd restarts it (`RestartSec`) comes from `docker_client_timeout`: one tenth of it, minus one
>   second. It is 11 s with Kolla-Ansible's default of 120 s; these labs set 600 s, so **59 s**. On the 5-VM lab, a
>   `neutron_dhcp_agent` stopped with `docker stop` was running again about 70 s later
>   ([measurement](https://github.com/OzarLand/openstack-quick-lab/pull/13#issuecomment-6398277862)).
>
> The exercises use `docker` only to look (`docker ps`, `docker exec`, `docker logs`). On a deployment without these
> units (an older release, or another deployment tool), use that tool's own way to stop a service.

| # | Exercise | Time | What you learn |
|---|---|---|---|
| 1 | [DHCP agents down](01-dhcp-agents-down.md) | 20 min | An instance can be `ACTIVE` and still have no address |
| 2 | [Metadata agents down](02-metadata-agents-down.md) | 20 min | Where an instance gets its SSH key, and what happens without it |
| 3 | [nova-compute down](03-nova-compute-down.md) | 15 min | The control plane and the instances are separate: one can fail without the other |
| 4 | [Restarting nova_libvirt](04-restart-nova-libvirt.md) | 10 min | A restart that looks risky, and why it is not |
| 5 | [Restarting the Open vSwitch agent](05-restart-ovs-agent.md) | 10 min | The agent programs the network; it does not carry the traffic |
| 6 | [Instance unreachable from outside](06-instance-unreachable-from-outside.md) | 20 min | Security groups and floating IPs, checked in order |

### Multinode variant

These three need two computes: run them on the
[multinode variant](../variants/openstack-cloud-multinode/README.md), not on the all-in-one lab. They were
[run on a lab](https://github.com/OzarLand/openstack-quick-lab/pull/10#issuecomment-6397487220) on 2026-10-25 (multinode variant, 1 controller + 2 computes). Exercises 8 and 9 use a runbook still marked
`status: draft`.

| # | Exercise | Time | What you learn |
|---|---|---|---|
| 7 | [A compute goes down: fence it before you evacuate](07-compute-down-fence-before-evacuate.md) | 30 min | Why a compute must be off for sure before its instances are rebuilt elsewhere |
| 8 | [Drain a compute for planned maintenance](08-drain-a-compute-for-maintenance.md) | 30 min | Disable, move the instances away, work, enable: maintenance without downtime |
| 9 | [Live migration between the two computes](09-live-migration-between-computes.md) | 20 min | What moving a running instance costs its users, measured with a ping |

### Multinode variant, 3 controllers

These two need the 5-VM size of the multinode variant (`CONTROLLERS="3"`). They were
[run on a lab](https://github.com/OzarLand/openstack-quick-lab/pull/15#issuecomment-6399273095) on 2026-10-25
(multinode variant, 3 controllers + 2 computes).

| # | Exercise | Time | What you learn |
|---|---|---|---|
| 10 | [Lose one controller: what keeps working](10-lose-one-controller.md) | 40 min | The VIP moves, two of three is still a quorum, a hung controller costs more than a dead one, a controller rejoins |
| 11 | [Lose two controllers: quorum lost, and recovered](11-lose-two-controllers-quorum.md) | 30 to 45 min | Why a minority stops serving, when Galera recovers by itself, and how `mariadb-recovery` rebuilds the cluster when it does not |

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

Two things you will meet in every exercise:

- **Run the runbooks' `docker` and `systemctl` commands with `sudo`.** The runbooks write them without it (for
  example `docker ps -a …` and `systemctl start kolla-…`). Without `sudo`, the `ubuntu` user of the lab gets
  `permission denied while trying to connect to the docker API` and an authentication prompt.
- **`systemctl` prints a warning** such as `The unit file, source configuration file or drop-ins of
  kolla-…-container.service changed on disk. Run 'systemctl daemon-reload' to reload units.` It is harmless on
  these labs, and the command still worked: you do not need to run `daemon-reload`.

Wherever a page writes `<floating-ip>`, use the address printed by the `openstack floating ip create` command just
before it. Note it down: you will also need it in a second SSH session.

These exercises break things on purpose. Run them only on this disposable lab, never on a platform someone relies
on.

## When you are done

Delete the lab: [delete everything when you are done](../README.md#delete-everything-when-you-are-done).
