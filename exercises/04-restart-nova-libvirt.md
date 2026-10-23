# Exercise 4. Restarting nova_libvirt without stopping instances

**Goal:** restart the container that runs libvirt, the way a reconfigure or an upgrade does, and measure that the
instances keep running.
**Time:** about 10 minutes.
**Runbook:** [I need to restart nova_libvirt on a compute. Its instances keep running](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/lifecycle/restarting-nova-libvirt-does-not-stop-instances.md)

## Before you start

Read [before every exercise](README.md#before-every-exercise). You need an instance you can ping from the lab VM:
create one with a floating IP, and allow ping to it.

```bash
openstack server create --image <image> --flavor <flavor> --network <tenant-network> --key-name <key> --wait ex4-test
openstack floating ip create <external-network>
openstack server add floating ip ex4-test <floating-ip>
ping -c 3 <floating-ip>
```

If the ping does not answer, the security group does not allow ICMP: exercise 6 shows how to find and fix that.

Note the domain ID libvirt gives the instance:

```bash
sudo docker exec nova_libvirt virsh list
```

## 1. Do it

In a second SSH session, leave a ping running:

```bash
ping -i 0.5 <floating-ip>
```

Then, in the first session, follow the runbook's **Resolution** step:

> ⚠️ **State-changing.** Restarts libvirt. With Kolla-Ansible's default settings the runbook's lab saw no instance
> stop; check the runbook's preconditions before doing this on any platform someone relies on.

```bash
sudo systemctl restart kolla-nova_libvirt-container.service
```

## 2. What you should see

- The ping keeps answering. On the runbook's lab: 174 requests in the first minute, none lost.
- `sudo docker exec nova_libvirt virsh list` shows the **same domain ID** as before: libvirt took the running
  instance back; it did not start it again.

Before reading on: where does the instance actually run, if libvirt can restart under it?

## 3. Read the runbook

Read its **Diagnosis** and **Validity and limits**: why the instances survive, and which settings would change that.

## 4. Check

Follow the runbook's **Verification**.

## 5. Clean up

Stop the ping (Ctrl-C), then:

```bash
openstack server delete --wait ex4-test
openstack floating ip delete <floating-ip>
```

**Done with the lab for today?** [Delete everything](../README.md#delete-everything-when-you-are-done): a running lab
keeps costing.
