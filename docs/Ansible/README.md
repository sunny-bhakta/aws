# Ansible Starter Guide

This folder is your hands-on Ansible starting point.

## What is Ansible?

Ansible is an automation tool used in DevOps for:

- configuration management
- server setup
- application deployment
- orchestration tasks

### Detailed meaning with examples

1. **Configuration management**
  - Keep server configuration consistent across many machines.
  - Example: ensure all app servers have the same timezone, package versions, and SSH settings.

2. **Server setup (provisioning tasks)**
  - Prepare new servers automatically after they are created.
  - Example: create users, install Docker/Nginx, configure firewall rules, and create app directories.

3. **Application deployment**
  - Push and update application versions in a repeatable way.
  - Example: pull latest code, update `.env`, restart the app service, and verify status.

4. **Orchestration tasks**
  - Coordinate multi-step operations across multiple hosts/services in the correct order.
  - Example: stop app -> migrate DB -> deploy new version -> start app -> run health checks.

### Real-world mini scenario

Suppose you have 3 EC2 instances (`web1`, `web2`, `web3`) and want the same baseline setup:

- install `nginx`
- create `/opt/myapp`
- copy app config
- ensure `nginx` is running

With Ansible, you write this once in a playbook and run it against all 3 servers.
If you run the playbook again, Ansible changes only what is missing/different (idempotent behavior).

It is agentless (typically SSH-based), so you don’t install agents on target machines.

---

## Core concepts

- **Inventory**: list of target hosts
- **Playbook**: YAML automation steps
- **Task**: one operation (install package, copy file, start service)
- **Module**: reusable unit used by tasks (for example `ping`, `copy`, `apt`, `yum`, `service`)
- **Idempotent**: run multiple times, same final state

---

## Minimal file structure

```text
Ansible/
├── README.md
├── inventory.ini
└── playbook.yml
```

---

## Example inventory

Create `inventory.ini`:

```ini
[web]
server1 ansible_host=192.168.1.10 ansible_user=ubuntu
server2 ansible_host=192.168.1.11 ansible_user=ubuntu
```

---

