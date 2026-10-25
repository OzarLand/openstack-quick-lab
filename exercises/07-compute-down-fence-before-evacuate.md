# Exercise 7. A compute goes down: fence it before you evacuate

> **Multinode variant** only: it needs two computes. **Not yet run on a lab**: the commands and what you should see
> are written from the runbook and Nova's documentation, and are checked when the lab confirms them.

**Goal:** see a compute reported `down` while its instances may still be running, make sure it is really off
(fence it), and only then rebuild its instances on the other compute (evacuate).
**Time:** about 30 minutes (estimate, not yet run).
**Runbook:** [A compute host has failed: fence it before you evacuate](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/recovery/compute-host-failure-fence-before-evacuate.md)

## Before you start

Read [before every exercise](README.md#before-every-exercise) and the
[multinode variant's guide](../variants/openstack-cloud-multinode/README.md). This exercise uses two terminals:

- **Lab terminal:** logged in to controller 1, with the lab's admin credentials loaded.
- **Hosting terminal:** on your own computer, in the directory of the scripts, with the `OS_CLOUD` of your
  `config.env`: it talks to the cloud that hosts the lab VMs, not to the lab.

In the lab terminal, list the two computes and note their names, written `<compute-1>` and `<compute-2>` below:

```bash
openstack compute service list --service nova-compute
```

Create a test instance on `<compute-1>`, and check where it runs:

```bash
openstack server create --image cirros --flavor m1.tiny --network demo-net --key-name mykey \
  --availability-zone nova:<compute-1> --wait ex7-test
openstack server show ex7-test -c status -c OS-EXT-SRV-ATTR:host
```

In the hosting terminal, find the lab VM that is `<compute-1>`, written `<compute-1-vm>` below. The computes are
named in Nova like their VMs (`quicklab-multi-1-cmp-1` and `-cmp-2` with the default `PREFIX` and `LAB`), so it is
usually the same name:

```bash
openstack server list --name '^<prefix><lab>-'
```

To log in to a compute from controller 1, use the lab's key and the compute's address in `NETWORK` (the
[variant's guide](../variants/openstack-cloud-multinode/README.md#inside-the-lab) says where to find it):

```bash
ssh -i ~/.ssh/quicklab_ed25519 ubuntu@<compute-1-address>
```

## 1. Break it

> ⚠️ **State-changing.** Stops `nova-compute` on `<compute-1>`. Nova sees the compute as `down`; its instances keep
> running. Disposable lab only.

On `<compute-1>` (logged in from controller 1, as above):

```bash
sudo systemctl stop kolla-nova_compute-container.service
```

## 2. What you should see

- In the lab terminal, after about a minute, `<compute-1>` shows `down`:

  ```bash
  openstack compute service list --service nova-compute
  ```

- `ex7-test` is still `ACTIVE`, and on `<compute-1>` it still runs in the hypervisor:

  ```bash
  sudo docker exec nova_libvirt virsh list --all
  ```

Before reading on: Nova says the compute is `down`. If you rebuilt `ex7-test` on `<compute-2>` now, how many copies
of it would run, with the same address?

## 3. Diagnose and repair with the runbook

Follow the runbook from its **Quick checks**. Its order is the point of this exercise:

1. **Tell a dead host from a dead agent.** Here the host answers and its instances run: only the agent is down. On a
   real platform, this is where you would just start the agent again (as in [exercise 3](03-nova-compute-down.md)).
   Here, treat the compute as failed, and go on.
2. **Fence it before anything else.** Make sure the compute cannot run its instances any more. In the hosting
   terminal, power off its VM, the way a power controller would switch off a physical server:

   > 🛑 **Destructive.** Powers off `<compute-1-vm>`: every instance on it stops at once, without a clean shutdown.
   > Disposable lab only.

   ```bash
   openstack server stop <compute-1-vm>
   openstack server show <compute-1-vm> -c status    # SHUTOFF before you go on
   ```

3. **Tell Nova the compute is down**, so that it does not wait for it, as the runbook's **Resolution** shows:

   > ⚠️ **State-changing.** Marks `<compute-1>` as forced down in Nova.

   ```bash
   openstack compute service set --down <compute-1> nova-compute
   ```

4. **Evacuate** its instances to `<compute-2>`, following the runbook.

   > 🛑 **Destructive.** Evacuation rebuilds `ex7-test` on `<compute-2>` from its image: on this lab, without shared
   > storage, whatever was on its disk is lost. Disposable lab only.

## 4. Check

Follow the runbook's **Verification**:

```bash
openstack server show ex7-test -c status -c OS-EXT-SRV-ATTR:host    # ACTIVE, on <compute-2>
openstack server migration list --server ex7-test                    # the evacuation, done
```

Then bring `<compute-1>` back, as the runbook's last part shows: start its VM in the hosting terminal, check that
`nova-compute` starts and removes the old copy of `ex7-test` (`virsh list --all` on `<compute-1>` no longer shows it),
and only then lift the forced down.

> ⚠️ **State-changing.** Starts `<compute-1-vm>` and puts `<compute-1>` back in service.

```bash
openstack server start <compute-1-vm>                        # hosting terminal
openstack compute service set --up <compute-1> nova-compute  # lab terminal, once the old copy is gone
openstack compute service list --service nova-compute        # lab terminal: <compute-1> up again
```

## 5. Clean up

If you stopped half-way: in the hosting terminal, start `<compute-1-vm>` if it is `SHUTOFF`; on `<compute-1>`, start
`nova-compute` if it is stopped (`sudo systemctl start kolla-nova_compute-container.service`); in the lab terminal,
lift the forced down if you set it (`openstack compute service set --up <compute-1> nova-compute`). Then delete the test instance:

```bash
openstack server delete --wait ex7-test
```

**Done with the lab for today?** [Delete everything](../README.md#delete-everything-when-you-are-done): a running lab
keeps costing, and this one runs several VMs.
