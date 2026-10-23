# Exercise 5. Restarting the Open vSwitch agent without cutting the network

**Goal:** restart the Neutron Open vSwitch agent and see that running instances keep their network, while new
instances wait for it.
**Time:** about 10 minutes.
**Runbook:** [I need to restart the Open vSwitch agent on a compute. Its instances keep their network](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/restarting-the-ovs-agent-does-not-cut-instances.md)

## Before you start

Read [before every exercise](README.md#before-every-exercise). Create an instance with a floating IP that answers
ping, as in [exercise 4](04-restart-nova-libvirt.md#before-you-start), and call it `ex5-test`.

## 1. Do it

In a second SSH session, leave a ping running:

```bash
ping -i 0.5 <floating-ip>
```

Then, in the first session:

> ⚠️ **State-changing.** Restarts the Open vSwitch agent. Running instances keep their network; ports created or
> changed during the restart wait for the agent. Disposable lab only.

```bash
sudo systemctl restart --no-block kolla-neutron_openvswitch_agent-container.service
```

`--no-block` gives the prompt back at once while the restart goes on, about a minute. Without it, `systemctl` waits
for the end of the restart, and the next command would come too late to see anything.

Right away, while the agent restarts, create a second instance and time how long it takes to become `ACTIVE`:

```bash
time openstack server create --image cirros --flavor m1.tiny --network demo-net --key-name mykey --wait ex5-second
```

## 2. What you should see

- The ping keeps answering. On the runbook's lab, no request was lost.
- The restart of the unit takes about a minute. During it,
  `sudo systemctl status kolla-neutron_openvswitch_agent-container.service` shows `deactivating (stop)`, then
  `active (running)` again (runbook's lab: about 70 s; 62 s on a later lab).
- The second instance waits for the agent. In a
  [later lab review of the runbook](https://github.com/OzarLand/openstack-vm-runbooks/pull/2#issuecomment-6334698855),
  an instance requested during the restart became `ACTIVE` after about 80 s instead of 18 s, and the agent was
  reported not alive for a few seconds at the end of the restart.

Before reading on: if the agent restarts, what keeps forwarding the packets?

## 3. Read the runbook

Read its **Diagnosis** and **Validity and limits**: what the agent does, what `ovs-vswitchd` does, and the setting
(`drop_flows_on_start`) that would make a restart cut the traffic.

## 4. Check

Follow the runbook's **Verification**: the agent is alive, the ping still answers, the flows are present.

## 5. Clean up

Stop the ping (Ctrl-C), then:

```bash
openstack server delete --wait ex5-test ex5-second
openstack floating ip delete <floating-ip>
```

**Done with the lab for today?** [Delete everything](../README.md#delete-everything-when-you-are-done): a running lab
keeps costing.
