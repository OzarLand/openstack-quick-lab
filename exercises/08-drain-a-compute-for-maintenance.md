# Exercise 8. Drain a compute for planned maintenance

> **Multinode variant** only: it needs two computes. **Not yet run on a lab**: the commands and what you should see
> are written from the runbook and Nova's documentation, and are checked when the lab confirms them.

**Goal:** take a compute out of service without stopping anyone's instances: stop new instances landing on it, move
its instances to the other compute, work on it, and put it back.
**Time:** about 30 minutes (estimate, not yet run).
**Runbook:** [Moving instances off a host for maintenance](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/migration/moving-instances-off-a-host-for-maintenance.md) (`status: draft`: not yet
checked on a lab; it also covers live migration)

## Before you start

Read [before every exercise](README.md#before-every-exercise) and the
[multinode variant's guide](../variants/openstack-cloud-multinode/README.md). Work on the lab's controller, with the
lab's admin credentials loaded.

List the two computes and note their names, written `<compute-1>` (the one you will drain) and `<compute-2>` below:

```bash
openstack compute service list --service nova-compute
```

Create two test instances on `<compute-1>`:

```bash
for n in a b; do
  openstack server create --image cirros --flavor m1.tiny --network demo-net --key-name mykey \
    --availability-zone nova:<compute-1> --wait ex8-test-$n
done
openstack server list --host <compute-1> -c Name -c Status
```

## 1. Stop new instances landing on it

> ⚠️ **State-changing.** Disables the `nova-compute` service of `<compute-1>`: the scheduler no longer places new
> instances there. Instances already on it keep running.

```bash
openstack compute service set --disable --disable-reason "planned maintenance" <compute-1> nova-compute
openstack compute service list --service nova-compute
```

## 2. What you should see

- `<compute-1>` is `enabled: disabled` and still `up`: disabled is a scheduling decision, not a failure.
- A new instance created without a host goes to `<compute-2>`:

  ```bash
  openstack server create --image cirros --flavor m1.tiny --network demo-net --key-name mykey --wait ex8-new
  openstack server show ex8-new -c OS-EXT-SRV-ATTR:host
  ```

Before reading on: disabling a compute moved nothing. What will you do with `ex8-test-a` and `ex8-test-b`?

## 3. Drain it with the runbook

Follow the runbook from its **Quick checks**:

1. Its checks before moving anything: the other compute is `up` and has room, and the instances to move are listed.
2. Move each instance off `<compute-1>`, live, as the runbook's **Resolution** shows. On this lab the instances have no
   shared storage, so a live migration also copies their disk (block migration); the runbook says which option that
   takes.

   > ⚠️ **State-changing.** Live-migrates `ex8-test-a` and `ex8-test-b` to `<compute-2>`. They keep running; a ping
   > to them may lose a packet or two at the switch-over.

3. Check that nothing is left on the host before you work on it:

   ```bash
   openstack server list --all-projects --host <compute-1>    # empty
   ```

4. **The maintenance itself.** Here, reboot the compute VM, as you would for a kernel update. From your own computer,
   in the directory of the scripts, with the `OS_CLOUD` of your `config.env`:

   > ⚠️ **State-changing.** Reboots the lab VM that is `<compute-1>`. Nothing runs on it any more.

   ```bash
   openstack server list --name '^<prefix><lab>'      # find the VM that is <compute-1>
   openstack server reboot <compute-1-vm>
   ```

## 4. Check, and put it back

Follow the runbook's **Verification**: after the reboot, `<compute-1>` is `up` again, the moved instances are `ACTIVE`
on `<compute-2>`, and nothing was lost.

```bash
openstack compute service list --service nova-compute
openstack server list --host <compute-2> -c Name -c Status
```

Then put the compute back in service:

> ⚠️ **State-changing.** Enables `<compute-1>` again: the scheduler places new instances on it.

```bash
openstack compute service set --enable <compute-1> nova-compute
```

Instances do not move back on their own. Moving them back is the same live migration, in the other direction.

## 5. Clean up

If you stopped half-way, enable `<compute-1>` again first (the command above). Then delete the test instances:

```bash
openstack server delete --wait ex8-test-a ex8-test-b ex8-new
```

**Done with the lab for today?** [Delete everything](../README.md#delete-everything-when-you-are-done): a running lab
keeps costing, and this one runs several VMs.
