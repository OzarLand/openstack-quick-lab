# Exercise 3. nova-compute down: instances keep running

**Goal:** stop the Nova agent of the compute and see that the instances do not notice, while the control plane
does.
**Time:** about 15 minutes.
**Runbook:** [nova-compute is down on a compute, but its instances are still running](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/recovery/nova-compute-down-instances-still-running.md)

## Before you start

Read [before every exercise](README.md#before-every-exercise). Create a test instance and note where it runs:

```bash
openstack server create --image cirros --flavor m1.tiny --network demo-net --key-name mykey --wait ex3-test
openstack server show ex3-test -c status -c OS-EXT-SRV-ATTR:instance_name
openstack compute service list --service nova-compute
```

## 1. Break it

> ⚠️ **State-changing.** Stops `nova-compute`, the agent that tells Nova about this compute. Running instances keep
> running; Nova can neither start, stop nor create instances on this compute until it is back. Disposable lab only.

```bash
sudo systemctl stop kolla-nova_compute-container.service
```

## 2. What you should see

- After about a minute (Nova's `service_down_time`, 60 s by default), the compute service shows `down`:

  ```bash
  openstack compute service list --service nova-compute
  ```

- The instance still runs in the hypervisor:

  ```bash
  sudo docker exec nova_libvirt virsh list --all
  ```

  `ex3-test` is the line named like its `OS-EXT-SRV-ATTR:instance_name` (for example `instance-00000004`). Any other
  line is another instance, such as `demo1`, the test instance the lab's scripts created.

Before reading on: what keeps an instance running, if not `nova-compute`?

## 3. Diagnose and repair with the runbook

Follow the runbook:

1. Its quick checks tell this case apart from a dead host: the host answers, `nova_libvirt` runs, only
   `nova_compute` is stopped.
2. Its diagnosis shows how to find why the agent stopped, before starting it again. Here, you know why.
3. **Resolution**: start the agent again.

## 4. Check

Follow the runbook's **Verification**: the compute service is `up`, the instance is still `ACTIVE`, and a new instance
can be created.

```bash
openstack compute service list --service nova-compute
openstack server show ex3-test -c status
```

## 5. Clean up

If you stopped before the repair, start the service again first:

```bash
sudo systemctl start kolla-nova_compute-container.service
```

Then delete the test instance:

```bash
openstack server delete --wait ex3-test
```

**Done with the lab for today?** [Delete everything](../README.md#delete-everything-when-you-are-done): a running lab
keeps costing.
