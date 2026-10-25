# Exercise 10. Lose one controller: what keeps working

> **Multinode variant, 3 controllers** only (`CONTROLLERS="3"`, 5 VMs). **Not yet run on a lab**: the 5-VM size was
> built and checked on 2026-10-25 (see the [variant's guide](../variants/openstack-cloud-multinode/README.md)), but
> this exercise has not been run on it yet. The commands and what you should see are written from Kolla-Ansible's
> documentation, and are checked when the lab confirms them. Values marked _to be confirmed_ are filled in from that
> run.

**Goal:** make one of the three controllers fail, see that the APIs keep answering through the virtual IP, that
keepalived moves the VIP if that controller held it, and that the Galera and RabbitMQ clusters keep their quorum;
then bring the controller back and watch it rejoin.
**Time:** about 30 minutes (estimate, not yet run).
**Pattern:** [Three controllers and two computes, nested inside an existing OpenStack cloud](https://github.com/OzarLand/kolla-ansible-deployment-patterns/blob/main/topologies/three-controllers-two-computes-nested-in-an-openstack-cloud.md)
(how the VIP, keepalived and the clusters are set up in this lab)

## Before you start

Read [before every exercise](README.md#before-every-exercise) and the
[multinode variant's guide](../variants/openstack-cloud-multinode/README.md). This exercise uses two terminals:

- **Lab terminal:** logged in to **controller 1** (`<prefix><lab>-ctl-1`), with the lab's admin credentials loaded.
  Controller 1 is also the deploy host: this exercise never stops it, so that its tools stay available.
- **Hosting terminal:** on your own computer, in the directory of the scripts, with the `OS_CLOUD` of your
  `config.env`: it talks to the cloud that hosts the lab VMs, not to the lab.

Note the VIP, written `<vip>` below. It is `kolla_internal_vip_address` in `/etc/kolla/globals.yml` on controller 1,
and `VIP` in `.state/<prefix><lab>/state.env` on your computer; the port that reserves it is `<prefix><lab>-vip`.

Find which controller holds the VIP. From controller 1, for each controller address in `~/multinode`:

```bash
ssh -i ~/.ssh/quicklab_ed25519 ubuntu@<controller-address> "ip -br addr | grep -F '<vip>'"
```

The controller that prints a line holds it. Pick the controller you will fail, written `<ctl-x>`: the VIP holder if
it is controller 2 or 3, otherwise controller 2. Its VM is `<ctl-x-vm>` in the hosting terminal.

Check the clusters before you break anything. On any controller:

```bash
sudo docker exec -it mariadb mariadb -u root -p -e "SHOW STATUS LIKE 'wsrep_cluster_%'"
sudo docker exec rabbitmq rabbitmqctl cluster_status
```

`mariadb` asks for the root password: it is `database_password` in `/etc/kolla/passwords.yml` on controller 1
(`sudo grep '^database_password' /etc/kolla/passwords.yml`). Type it at the prompt rather than after `-p`, so that it
stays out of your shell history and the process list.

`wsrep_cluster_size` is `3` and `wsrep_cluster_status` is `Primary`; RabbitMQ lists three running nodes. (The
2026.1 MariaDB image has no `mysql` client: use `mariadb`.)

In a second lab terminal, start a loop that calls an API through the VIP every 2 seconds, and leave it running:

```bash
while true; do date +%T; openstack token issue -f value -c expires >/dev/null && echo ok || echo FAILED; sleep 2; done
```

## 1. Break it

> 🛑 **Destructive.** Pauses `<ctl-x-vm>`: it stops answering at once, without leaving its clusters cleanly, the way
> a controller that hangs or loses its network would. Disposable lab only.

In the hosting terminal:

```bash
openstack server pause <ctl-x-vm>
```

A clean `openstack server stop` would let MariaDB and RabbitMQ leave their clusters in order; a pause does not, which
is the failure worth practising.

## 2. What you should see

- In the loop, a few `FAILED` lines at most, then `ok` again. If `<ctl-x>` held the VIP, keepalived moves it to
  another controller within a few seconds: check with the `ip -br addr` command above on the two others.
- Galera, on a remaining controller: `wsrep_cluster_size` `2`, `wsrep_cluster_status` still `Primary`. Two of three
  is a majority: the cluster keeps its quorum and accepts writes.
- RabbitMQ: `rabbitmqctl cluster_status` lists `<ctl-x>` among the nodes but not among the running ones.
- HAProxy stops sending requests to `<ctl-x>`'s APIs. Create an instance to check that the whole path still works:

  ```bash
  openstack server create --image cirros --flavor m1.tiny --network demo-net --key-name mykey --wait ex10-test
  ```

Before reading on: the cluster survived the loss of one controller. What would happen with two?
[Exercise 11](11-lose-two-controllers-quorum.md) answers.

## 3. Bring it back

> ⚠️ **State-changing.** Resumes `<ctl-x-vm>`.

```bash
openstack server unpause <ctl-x-vm>     # hosting terminal
```

## 4. Check

After a few minutes (_time to be confirmed_), on any controller:

- `wsrep_cluster_size` is `3` again, `Primary`: `<ctl-x>` rejoined Galera, with a state transfer if it missed too
  much.
- `rabbitmqctl cluster_status` lists three running nodes.
- The loop shows `ok`, and `openstack compute service list` and `openstack network agent list` show every service
  `up` again.

If `<ctl-x>` does not rejoin after about 10 minutes, look at the logs of its `mariadb` and `rabbitmq` containers
(`sudo docker logs --tail 50 mariadb`) before you do anything else.

## 5. Clean up

If you stopped half-way, unpause `<ctl-x-vm>` first (the command above). Stop the loop with Ctrl-C, then delete the
test instance:

```bash
openstack server delete --wait ex10-test
```

**Done with the lab for today?** [Delete everything](../README.md#delete-everything-when-you-are-done): a running lab
keeps costing, and this one runs 5 VMs.
