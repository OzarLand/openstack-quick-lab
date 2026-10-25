# Exercise 9. Live migration between the two computes

> **Multinode variant** only: it needs two computes. **Not yet run on a lab**: the commands and what you should see
> are written from the runbook and Nova's documentation, and are checked when the lab confirms them.

**Goal:** move a running instance from one compute to the other while you ping it, and measure what its users would
notice.
**Time:** about 20 minutes (estimate, not yet run).
**Runbook:** [Moving instances off a host for maintenance](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/migration/moving-instances-off-a-host-for-maintenance.md) (`status: draft`: not yet
checked on a lab; it also covers live migration)

## Before you start

Read [before every exercise](README.md#before-every-exercise) and the
[multinode variant's guide](../variants/openstack-cloud-multinode/README.md). Work on controller 1, with the lab's
admin credentials loaded, in two SSH sessions.

List the two computes and note their names, written `<compute-1>` and `<compute-2>` below:

```bash
openstack compute service list --service nova-compute
```

Create a test instance on `<compute-1>`, with a floating IP:

```bash
openstack server create --image cirros --flavor m1.tiny --network demo-net --key-name mykey \
  --availability-zone nova:<compute-1> --wait ex9-test
openstack floating ip create public1 -f value -c floating_ip_address
openstack server add floating ip ex9-test <floating-ip>
```

Wait about 30 seconds, then check that it answers, from controller 1 (the floating IPs of `public1` are reachable
from there):

```bash
ping -c 3 <floating-ip>
```

## 1. Start watching

In the second session, ping the instance every 0.2 seconds and leave it running:

```bash
ping -i 0.2 -D <floating-ip>
```

## 2. Migrate it live

Follow the runbook's **Resolution** for a live migration to a chosen host. On this lab the instances have no shared
storage, so the migration also copies the disk (block migration); the runbook says which option that takes.

> ⚠️ **State-changing.** Live-migrates `ex9-test` from `<compute-1>` to `<compute-2>`. It keeps running; a few pings
> may be lost at the switch-over. Disposable lab only.

Follow its progress:

```bash
openstack server migration list --server ex9-test
openstack server show ex9-test -c status -c OS-EXT-SRV-ATTR:host
```

## 3. What you should see

- The status goes `MIGRATING`, then `ACTIVE` again, and the host changes from `<compute-1>` to `<compute-2>`.
- In the second session, stop the ping with Ctrl-C and read its summary: how many packets were lost, and for how
  long? Note it: that is what a user of this instance would have noticed. For comparison, the variant's smoke test
  measured 43 replies lost out of 166, about 8.6 s, for a live migration of 35 s on 2026-10-25.
- On `<compute-2>`, the instance now runs in the hypervisor; on `<compute-1>`, it is gone. On each compute (from
  controller 1: `ssh -i ~/.ssh/quicklab_ed25519 ubuntu@<compute-address>`):

  ```bash
  sudo docker exec nova_libvirt virsh list --all
  ```

Before reading on: the disk was copied over the network while the instance kept writing to it. What does a
migration do when the instance writes faster than the network copies?

## 4. Check

Follow the runbook's **Verification**: the migration is `completed`, the instance is `ACTIVE` on `<compute-2>`, it
still answers, and you can still log in to it.

```bash
openstack server migration list --server ex9-test
ping -c 3 <floating-ip>
ssh -i ~/.ssh/id_ecdsa cirros@<floating-ip> uptime    # the uptime did not restart: same instance, still running
```

## 5. Clean up

```bash
openstack server delete --wait ex9-test
openstack floating ip delete <floating-ip>
```

**Done with the lab for today?** [Delete everything](../README.md#delete-everything-when-you-are-done): a running lab
keeps costing, and this one runs several VMs.
