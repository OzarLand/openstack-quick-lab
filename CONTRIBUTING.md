# Contributing

This repository follows the OzarLand community rules: the
[code of conduct](https://github.com/OzarLand/ozarland/blob/main/CODE_OF_CONDUCT.md), the
[review and merge policy](https://github.com/OzarLand/ozarland/blob/main/docs/review-policy.md) and the
[content conventions](https://github.com/OzarLand/ozarland/tree/main/docs/conventions). The decision that created it
is [ADR-0009](https://github.com/OzarLand/ozarland/blob/main/docs/adr/0009-openstack-quick-lab-repository.md).

Contributions are welcome in three forms: a variant for another place to run the lab, a new exercise, and fixes to
what is here.

## Adding a variant for another provider

A variant lets the same lab run somewhere else: another OpenStack cloud with different requirements, a public cloud
that is not OpenStack, or a personal machine. Every variant is documented **on equal terms**: same structure, same
safety section, same review. No variant is required to follow the exercises.

### Layout

```text
variants/<variant-name>/
  README.md        # the guide, structured as below
  ...              # scripts: launch, delete, and anything they need
```

Use a generic name that says where the lab runs (`openstack-cloud`, `personal-machine`, `<provider>`), not a
product slogan.

### What the variant's README must contain

1. **Requirements:** account or hardware, quotas (vCPU, RAM, disk, floating IPs), the image used, network access
   (proxy, registry), the tools to install on your own machine.
2. **Cost risk**, in one of three forms, stated plainly at the top:
   - *Prepaid:* spending cannot exceed the credit loaded, with a link to the provider's own terms that say so;
   - *Pay-as-you-go:* how to set a budget alert on that provider, step by step, before launching;
   - *Personal machine:* no cloud cost; the resources it uses on the machine.
3. **Launch:** one documented command. Before creating anything, it shows an estimated cost per hour (or "no cloud
   cost") and asks for confirmation.
4. **Delete:** one documented command that removes everything the launch created, and how to check that nothing is
   left.
5. **Releases:** the OpenStack and Kolla-Ansible releases the scripts were last run on, and the date.
6. **Limits:** what the variant does not do, or does differently from the others.

### What a variant must not contain

- **No credentials or secrets**: no `clouds.yaml` with passwords, no application credentials, no `passwords.yml`, no
  real addresses or hostnames. Read them from the user's environment at run time. The
  [sensitive data](https://github.com/OzarLand/ozarland/blob/main/docs/conventions/sensitive-data.md) rules apply.
- **No marketing**: no prices beyond the cost estimate needed for safety, no promotional text, no logos, no
  referral links. Describe the provider factually, in one sentence.

### Testing

Run the launch and the delete end to end before opening the pull request, and say in its description on which
release, on which date, how long the launch took, and what it cost if anything. Then run at least the first
exercise on your variant.

## Adding an exercise

An exercise breaks one thing on the all-in-one lab and repairs it with an **existing runbook** of
[openstack-vm-runbooks](https://github.com/OzarLand/openstack-vm-runbooks), preferably one marked `lab-verified`. It
sends readers to the runbook; it does not copy it.

Follow the structure of the existing exercises: goal, time, before you start, break it (with its ⚠️ warning), what
you should see, diagnose and repair with the runbook, check, clean up, and the reminder to delete the lab. Every
exercise must work on every variant.

If an exercise shows the runbook is wrong or incomplete, open an issue or a pull request on the runbook too.

## Pull requests

- English only.
- One topic per pull request.
- Commits are signed off (`git commit -s`), as in every OzarLand repository (Developer Certificate of Origin).
