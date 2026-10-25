# Exercise 11. Lose two controllers: quorum lost, and recovered

> **Multinode variant, 3 controllers** only (`CONTROLLERS="3"`, 5 VMs). Run on a lab on 2026-10-25 (multinode variant,
> 3 controllers + 2 computes): see the [lab review](https://github.com/OzarLand/openstack-quick-lab/pull/15#issuecomment-6399273095).

**Goal:** make two of the three controllers fail at once, see the Galera cluster lose its quorum and the APIs stop,
then recover the cluster with Kolla-Ansible's `mariadb-recovery`.
**Time:** about 30 minutes, or 45 with the optional recovery of step 4.
**Procedure:** the recovery step of
[kolla-ansible deploy fails part-way because Ubuntu upgraded packages during the deploy](https://github.com/OzarLand/kolla-ansible-deployment-patterns/blob/main/deployment-errors/unattended-upgrades-during-deploy-breaks-the-mariadb-cluster.md#recover-the-failed-deploy)
(its `mariadb-recovery` part, with the warning and the backup it asks for)

## Before you start

Do [exercise 10](10-lose-one-controller.md) first: it sets up the two terminals, the VIP, the cluster checks and the
API loop this exercise uses. Controller 1 (`<prefix><lab>-ctl-1`) is the deploy host and stays up; you fail
controllers 2 and 3, whose VMs are `<ctl-2-vm>` and `<ctl-3-vm>` in the hosting terminal.

Check that the clusters are whole (`wsrep_cluster_size` `3`, `Primary`; RabbitMQ three running nodes) and start the
API loop again.

## 1. Break it

> 🛑 **Destructive.** Pauses two controllers at once: the remaining one is a minority and the database stops
> accepting writes; every OpenStack API fails until the cluster is recovered. Disposable lab only.

In the hosting terminal, both commands one after the other, without waiting:

```bash
openstack server pause <ctl-2-vm>
openstack server pause <ctl-3-vm>
```

## 2. What you should see

- The loop prints `FAILED` and keeps failing.
- On controller 1, Galera has lost its quorum: `wsrep_cluster_status` is `non-Primary` and `wsrep_cluster_size` `1`.
  The node refuses queries it cannot guarantee (`WSREP has not yet prepared node for application use`).
- RabbitMQ on controller 1 no longer sees its two peers.

Before reading on: controller 1's data is intact. Why does it refuse to serve it alone?

## 3. Bring the controllers back

> ⚠️ **State-changing.** Resumes the two controllers.

```bash
openstack server unpause <ctl-2-vm>     # hosting terminal
openstack server unpause <ctl-3-vm>
```

Wait a minute, then check Galera again on each controller. On the lab, the three nodes were back in one `Primary`
cluster of size `3` within about 25 s: a paused node keeps its state, and when it answers again Galera reforms the
cluster by itself. If that is what you see, go to step 5; step 4 is then optional. If not (no node `Primary`, or a
`mariadb` container restarting), the cluster needs the recovery of step 4.

Before reading on: what kind of failure would keep Galera from coming back on its own?

## 4. Recover the cluster (if Galera did not come back on its own)

You need this step when the nodes lost their state at the same time, for example after a power cut of the whole
control plane. After a pause, Galera usually recovers by itself (step 3) and you can skip it. To practise it anyway,
run it on the healthy cluster, as the lab did: it works the same way. On the lab it took 200 s, and each copy of the
data below was about 2.3 GB.

Follow the page's recovery step, from controller 1. Read its warning in full before you start: it is the reason this
step is marked destructive.

> 🛑 **Destructive.** `mariadb-recovery` stops MariaDB on every controller, bootstraps a new cluster from the node
> with the most advanced state, and makes the others rejoin with a full state transfer that replaces their data.
> Every OpenStack API is unavailable while it runs. Copy the data aside first, as the page shows. Disposable lab
> only.

On each controller, stop the `mariadb` container with its systemd unit, not with `docker stop`: systemd would start
it again about a minute later, in the middle of the copy (see
[why the exercises use `systemctl`](README.md)). Then copy the data volume aside and note the `seqno` of
`grastate.dat`, as the page shows:

> ⚠️ **State-changing.** Stops MariaDB on the controller and writes a copy of its data under `/root`.

```bash
sudo systemctl stop kolla-mariadb-container.service
sudo cp -a /var/lib/docker/volumes/mariadb /root/mariadb-before-recovery
sudo grep -E 'seqno|safe_to_bootstrap' /var/lib/docker/volumes/mariadb/_data/grastate.dat
```

Stop them one after the other: the last one stopped has the highest `seqno` and `safe_to_bootstrap: 1`, and
`mariadb-recovery` bootstraps from it.

Then, on controller 1:

```bash
source ~/kolla-venv/bin/activate
kolla-ansible mariadb-recovery -i ~/multinode
```

## 5. Check

**Check the clock of each controller you paused, before you judge the services.** A paused VM comes back with its
clock behind by about the time it was paused, and `timedatectl` may still say it is synchronised. Nova and Neutron
then read its heartbeats as old, and services flap between `up` and `down` from one call to the next. From
controller 1, compare each paused controller's clock with controller 1's:

```bash
date -u +%T; ssh -i ~/.ssh/quicklab_ed25519 ubuntu@<controller-address> 'date -u +%T'
```

If it is behind, step it:

> ⚠️ **State-changing.** Restarts the time service of the controller, which steps its clock.

```bash
ssh -i ~/.ssh/quicklab_ed25519 ubuntu@<controller-address> 'sudo systemctl restart systemd-timesyncd'
```

On the lab, the clock was 9 minutes behind after a 9-minute pause; once it was stepped, every service was `up` within
40 s and stayed so. The runbook [clock skew](https://github.com/OzarLand/openstack-vm-runbooks/blob/main/diagnostics/compute-clock-skew.md) explains the symptom on a compute; it is the same here.

Then follow the page's **Verification**, on each controller:

- `wsrep_cluster_size` `3`, `wsrep_cluster_status` `Primary`.
- `rabbitmqctl cluster_status` lists three running nodes. If RabbitMQ did not recover with the controllers, look at
  its container logs first.
- The loop shows `ok`, and `openstack compute service list` and `openstack network agent list` show every service
  `up`.
- An instance can be created:

  ```bash
  openstack server create --image cirros --flavor m1.tiny --network demo-net --key-name mykey --wait ex11-test
  ```

## 6. Clean up

If you stopped half-way, unpause both controllers first, and recover the cluster if it is not `Primary` (step 4).
Stop the loop with Ctrl-C. Once the cluster is `Primary` with 3 nodes, delete the copies of the data volumes you
made, on each controller:

> 🛑 **Destructive.** Deletes the copy of MariaDB's data: after this, the recovery cannot be undone from it.

```bash
sudo rm -rf /root/mariadb-before-recovery
```

Then delete the test instance:

```bash
openstack server delete --wait ex11-test
```

**Done with the lab for today?** [Delete everything](../README.md#delete-everything-when-you-are-done): a running lab
keeps costing, and this one runs 5 VMs.
