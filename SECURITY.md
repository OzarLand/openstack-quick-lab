# Security policy

## What this policy covers

This repository contains scripts that create cloud resources and deploy OpenStack, and exercises that break and
repair a lab on purpose. Three kinds of security issues can arise:

1. **Sensitive data published by mistake**: a cloud credential, a `clouds.yaml` or `config.env` with secrets, a
   `passwords.yml`, a private key, a real hostname or address, an unredacted log. See
   [sensitive data](https://github.com/OzarLand/ozarland/blob/main/docs/conventions/sensitive-data.md).
2. **Unsafe scripts or exercises**: a script that exposes the lab more than it says (for example a security group open
   to the whole Internet), that sends credentials somewhere, or that changes or deletes resources it did not create;
   an exercise step that can cause damage beyond the disposable lab without the warning required by
   [risk warnings](https://github.com/OzarLand/ozarland/blob/main/docs/conventions/risk-warnings.md).
3. **A delete command that leaves resources behind**: it keeps costing money without the user knowing. If it involves
   nothing sensitive, open an issue with the "The lab failed at a step" form and say it is about `destroy`; it is
   handled first.

## How to report

**Do not open a public issue or discussion for the first two cases.**

Use GitHub private vulnerability reporting: "Report a vulnerability" in the Security tab of this repository. Only you
and the maintainers see the report. While the repositories are private, contact the organization owner directly on
GitHub instead. OzarLand has no e-mail contact.

Questions, errors and proposals that involve nothing sensitive go in a GitHub issue. Anything about the code of
conduct or a personal matter follows the [code of conduct](CODE_OF_CONDUCT.md#reporting).

Tell us which file and line, what you found, and what could go wrong. Do not include the sensitive data itself in the
report beyond what is needed to locate it. **If you published a credential by mistake, revoke or rotate it at your
provider first**, then report it.

## What to expect

- Acknowledgement within 5 business days.
- Sensitive data is removed promptly. If a secret was exposed, the contributor is contacted so they can rotate it,
  and the history is rewritten if needed.
- Unsafe scripts and exercises are corrected, or withdrawn until they are.
- Credit to the reporter in the fix, unless they prefer to stay anonymous.

## Vulnerabilities in OpenStack itself

A vulnerability in OpenStack, Kolla, Kolla-Ansible or another upstream project is reported to the
[OpenStack Vulnerability Management Team](https://security.openstack.org/), not here. We will help route it if you
are unsure.
