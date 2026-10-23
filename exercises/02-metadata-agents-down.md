# Exercise 2. Metadata agents down: a new instance gets no SSH key

**Goal:** see an instance that has its address but not its SSH key, find where the key should have come from, and
repair it.
**Time:** about 20 minutes.
**Runbook:** [New instance has an address, but no SSH key, no user data, default hostname](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/new-instance-boots-without-metadata.md)

## Before you start

Read [before every exercise](README.md#before-every-exercise). Check that the metadata agent is alive:

```bash
openstack network agent list --agent-type metadata
```

## 1. Break it

> ⚠️ **State-changing.** Stops the Neutron metadata agent of the lab. Running instances are not affected; new
> instances boot without their key and user data. Disposable lab only.

```bash
sudo systemctl stop kolla-neutron_metadata_agent-container.service
```

Wait a minute, then create a test instance:

```bash
openstack server create --image cirros --flavor m1.tiny --network demo-net --key-name mykey --wait ex2-test
```

## 2. What you should see

- The instance is `ACTIVE` and has an address: DHCP worked.
- Its console log shows the metadata requests failing:

  ```bash
  openstack console log show ex2-test | grep -iE 'metadata|169.254|iid|datasource'
  ```

  On the lab the runbook comes from, CirrOS printed `failed 20/20 … request failed` and
  `failed to read iid from metadata`, waited about three minutes, then booted without its metadata.
- An SSH login with your key would be refused, because the key never reached the instance.

Before reading on: the instance got its address, so what is different about the SSH key?

## 3. Diagnose and repair with the runbook

Open the runbook and follow it:

1. Its quick checks: which one shows the agent down?
2. **Possible causes**, cause 1.
3. **Resolution**: start the agent again.
4. Then the part for **instances created during the outage**. The lab review found that a reboot is enough on
   CirrOS, which reads the metadata at every boot. The runbook also has a rebuild step, marked 🛑: it recreates the
   instance's disk. You do not need it for this exercise.

## 4. Check

Follow the runbook's **Verification**: the agent is alive, and after the reboot the console shows the metadata read.

```bash
openstack network agent list --agent-type metadata
openstack console log show ex2-test | grep -iE 'instance-id|successful'
```

## 5. Clean up

If you stopped before the repair, start the service again first:

```bash
sudo systemctl start kolla-neutron_metadata_agent-container.service
```

Then delete the test instance:

```bash
openstack server delete --wait ex2-test
```

**Done with the lab for today?** [Delete everything](../README.md#delete-everything-when-you-are-done): a running lab
keeps costing.
