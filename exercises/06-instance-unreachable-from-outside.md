# Exercise 6. An instance unreachable from outside

**Goal:** make an instance unreachable from outside in two different ways, and find each cause with the runbook's
checks, in order.
**Time:** about 20 minutes.
**Runbook:** [Instance has its address and metadata, but is unreachable from outside](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/networking/instance-unreachable-from-outside.md)

## Before you start

Read [before every exercise](README.md#before-every-exercise). Create a security group that allows ping and SSH from
the external network, and an instance that uses it, with a floating IP. `10.99.0.0/24` is the lab's default external
range; if you changed `LAB_EXT_CIDR` in `config.env`, use your range instead.


```bash
openstack security group create ex6-sg
openstack security group rule create --ingress --protocol icmp --remote-ip 10.99.0.0/24 ex6-sg
openstack security group rule create --ingress --protocol tcp --dst-port 22 --remote-ip 10.99.0.0/24 ex6-sg
openstack server create --image cirros --flavor m1.tiny --network demo-net --key-name mykey \
  --security-group ex6-sg --wait ex6-test
openstack floating ip create public1
openstack server add floating ip ex6-test <floating-ip>
ping -c 3 <floating-ip>
```

The ping answers: that is the working state.

## 1. Break it, first way

> ⚠️ **State-changing.** Removes the ingress rules of the exercise's security group. Only `ex6-test` uses it.

```bash
openstack security group rule list --ingress ex6-sg
openstack security group rule delete <icmp-rule-id> <ssh-rule-id>
```

Ping and SSH time out. Now forget you did this, and follow the runbook's **Quick checks** in order. Which check finds
it? Then apply the matching **Resolution** to put the rules back.

## 2. Break it, second way

> ⚠️ **State-changing.** Removes the floating IP from the instance. The address stays allocated to your project.

```bash
openstack server remove floating ip ex6-test <floating-ip>
```

Follow the quick checks again from the start. Which one finds it this time? Apply the matching **Resolution**.

The runbook notes that a client on the external network's own segment, like the lab VM here, may see
`No route to host` instead of a timeout: nothing answers ARP for the address any more.

## 3. Go further

- The runbook's cause 3: try to remove `demo-net`'s subnet from its router while the floating IP is associated.
  On the runbook's lab, Neutron refused with HTTP 409. Why does it refuse?

  > ⚠️ **State-changing.** If Neutron accepts it (for example once the floating IP is gone), every instance of
  > `demo-net` loses its route to the outside. Undo: add the subnet back with the second command.

  ```bash
  openstack router remove subnet demo-router <demo-net-subnet>
  openstack router add subnet demo-router <demo-net-subnet>        # undo
  ```

  `openstack network show demo-net -c subnets` gives the subnet's ID.
- Read **Where the router lives**: on this lab (ML2/OVS), look at the `qrouter-` namespace and its NAT rule for your
  floating IP.

## 4. Check

Follow the runbook's **Verification**: the floating IP is on the right port, the rules are in place, ping and SSH
answer.

## 5. Clean up

```bash
openstack server delete --wait ex6-test
openstack floating ip delete <floating-ip>
openstack security group delete ex6-sg
```

**Done with the lab for today?** [Delete everything](../README.md#delete-everything-when-you-are-done): a running lab
keeps costing.
