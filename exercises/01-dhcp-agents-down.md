# Exercise 1. DHCP agents down: a new instance gets no address

**Goal:** see an instance that Nova reports `ACTIVE` but that never got an IP address, find why, and repair it.
**Time:** about 20 minutes.
**Runbook:** [New instance is ACTIVE but unreachable, it never got an IP address](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/new-instance-gets-no-ip-dhcp-agents-down.md)

## Before you start

Read [before every exercise](README.md#before-every-exercise). Check that the DHCP agent is alive:

```bash
openstack network agent list --agent-type dhcp
```

## 1. Break it

> ⚠️ **State-changing.** Stops the Neutron DHCP agent of the lab. Instances already running keep their address;
> new instances get none until the agent is started again. Disposable lab only.

```bash
sudo systemctl stop kolla-neutron_dhcp_agent-container.service
```

Wait a minute, then create a test instance:

```bash
openstack server create --image cirros --flavor m1.tiny --network demo-net --key-name mykey --wait ex1-test
```

## 2. What you should see

- `openstack server show ex1-test -c status -c addresses` says `ACTIVE`, and `addresses` shows an IP address: Neutron
  allocated it.
- The instance never received it. In its console log, the DHCP client asks and gets no answer. Wait about three
  minutes after the creation, then:

  ```bash
  openstack console log show ex1-test | grep -iE 'dhcp|lease'
  ```

  On the lab the runbook comes from, CirrOS printed `soliciting a DHCP lease`, then timed out after about three
  minutes. Run the command earlier and you only see `soliciting a DHCP lease`: CirrOS is still trying.

Before reading on, ask yourself: Nova says the instance is fine, so which service hands out addresses?

## 3. Diagnose and repair with the runbook

Open the runbook and follow it from **Quick checks** onwards:

1. Run its quick checks. Which one points at the cause? (Hint: `openstack network agent list --agent-type dhcp`.)
2. Find the matching cause in **Possible causes**.
3. Apply its **Resolution**: start the agent again.
4. Then the part for **instances created during the outage**: the lab review found that CirrOS did not retry on its
   own, and got its address after a reboot.

## 4. Check

Follow the runbook's **Verification**: the agent is alive, and a new test instance gets its lease.

```bash
openstack network agent list --agent-type dhcp
openstack console log show ex1-test | grep -iE 'lease|bound'
```

## 5. Clean up

If you stopped before the repair, start the service again first:

```bash
sudo systemctl start kolla-neutron_dhcp_agent-container.service
```

Then delete the test instance:

```bash
openstack server delete --wait ex1-test
```

**Done with the lab for today?** [Delete everything](../README.md#delete-everything-when-you-are-done): a running lab
keeps costing.
