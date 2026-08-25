<!--
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2020-2024 MDAD project contributors
SPDX-FileCopyrightText: 2020-2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Lidarr

This is an [Ansible](https://www.ansible.com/) role which installs [Lidarr](https://lidarr.audio/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Lidarr is a music collection manager for Usenet and BitTorrent users.

See the project's [documentation](https://wiki.servarr.com/lidarr) to learn what Lidarr does and why it might be useful to you.

## Adjusting the playbook configuration

To enable Lidarr with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# lidarr                                                               #
#                                                                      #
########################################################################

lidarr_enabled: true

########################################################################
#                                                                      #
# /lidarr                                                              #
#                                                                      #
########################################################################
```

### Set the hostname

To enable Lidarr you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
lidarr_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

### Protecting the web interface

> [!WARNING]
> Lidarr ships without authentication and this role does not add any by default. A Lidarr installed as described above is reachable by anyone who knows the hostname, and it hands its API key to them: the unauthenticated `/initialize.json` endpoint contains it, and that key is enough to drive the whole API. Configure one of the two options below before pointing DNS at the server.

The container image writes `<AuthenticationMethod>None</AuthenticationMethod>` into the configuration file Lidarr maintains for itself on first start, and Lidarr never asks you to create an account. Nothing in the installation process will warn you about this.

The first option is to put HTTP Basic authentication in front of Lidarr, which is what the [Bazarr role](https://github.com/mother-of-all-self-hosting/ansible-role-bazarr) does by default. Add the following configuration to your `vars.yml` file, replacing the credentials with your own:

```yaml
lidarr_container_labels_traefik_middleware_basic_auth_enabled: true
lidarr_container_labels_traefik_middleware_basic_auth_users: "user:$apr1$Ha9SbG5X$RTPTAKfKhx3F5FzFHwLKF."
```

The value is a `htpasswd`-formatted list of users, separated by commas. Generate one with `htpasswd -nb user password` (from the `apache2-utils` or `httpd-tools` package). If your `vars.yml` is processed by something that expands `$`, escape the dollar signs by doubling them.

The second option is to switch on Lidarr's own login, which is the better choice if you also reach Lidarr from a mobile app that cannot send Basic credentials. Lidarr reads these from the environment, so pass them through `lidarr_environment_variables_additional_variables`:

```yaml
lidarr_environment_variables_additional_variables: |
  LIDARR__AUTH__METHOD=Forms
  LIDARR__AUTH__REQUIRED=Enabled
```

Set them **before** the first installation and create your account on the login screen Lidarr then serves. Turning them on for an installation that has no user account yet locks you out of the web interface, since there is no account to log in with; recover by removing the variables, re-running the playbook, and creating the account from Lidarr's own *Settings -> General -> Security* page instead.

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `lidarr_environment_variables_additional_variables` variable

Settings that Lidarr keeps in the configuration file it maintains for itself can be overridden through the environment, using `LIDARR__<SECTION>__<SETTING>` names — `LIDARR__SERVER__URLBASE`, `LIDARR__LOG__LEVEL` and so on. The role does this for the port already (`lidarr_container_http_port` is passed as `LIDARR__SERVER__PORT`), so `lidarr_container_http_port` really does move the port Lidarr listens on rather than only the port the reverse-proxy is told about.

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, Lidarr becomes available at the specified hostname like `https://example.com`.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu lidarr` (or how you/your playbook named the service, e.g. `mash-lidarr`).
