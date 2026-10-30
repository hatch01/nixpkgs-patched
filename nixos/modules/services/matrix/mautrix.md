# Mautrix bridges {#module-services-mautrix}

Connect Signal to a Matrix homeserver:

```nix
{
  services.mautrix.bridges.signal = {
    type = "signal";
    settings = {
      homeserver = {
        address = "http://localhost:8008";
        domain = "example.com";
      };
      bridge.permissions."@admin:example.com" = "admin";
    };
  };
}
```

[Mautrix](https://docs.mau.fi/bridges/) bridges connect Matrix to other messaging
networks. Configure each bridge through `services.mautrix.bridges.<name>`.

## Configure bridge instances {#module-services-mautrix-configuration}

Supported types are `discord`, `facebook`, `instagram`, `signal`, `telegram`, and
`whatsapp`. The module enables each configured instance by default. The instance
name determines the system user and systemd service (`mautrix-<name>`) and the
default state directory (`/var/lib/mautrix-<name>`). Set `dataDir` to override the
state directory beneath `/var/lib`.
Each instance must have its own state directory. To run multiple bridges of the
same type, also choose distinct listener ports, appservice IDs, bot usernames,
and user namespace templates in `settings`.

All types expose the same service-management options, but `settings` follows the
selected upstream bridge's schema. Discord uses the legacy Go schema and stores
database settings in `appservice.database`. The other profiles, including
Telegram, use bridgev2 and store database settings in `database`.
Use the package's example configuration as a reference.

The module configures SQLite by default. For PostgreSQL, configure a database and
role separately and preserve the system user name when using peer authentication.
For a PostgreSQL database on the same machine, add `postgresql.service` to the
instance's `serviceDependencies` so the bridge starts after the database.
Registration generation does not wait for the homeserver or database.

## Load secrets {#module-services-mautrix-secrets}

Load a double-puppeting secret from an environment file:

```nix
{
  services.mautrix.bridges.signal = {
    type = "signal";
    environmentFiles = [ "/run/secrets/matrix-bridges.env" ];
    settings = {
      homeserver.address = "http://localhost:8008";
      homeserver.domain = "example.com";
      bridge.permissions."@admin:example.com" = "admin";
      double_puppet.secrets."example.com" = "as_token:$SHARED_AS_TOKEN";
    };
  };
}
```

Set `SHARED_AS_TOKEN=your-secret` in the environment file. Never place production
secrets in a Nix string or a file copied to the Nix store.

The module loads `environmentFiles` in order for both registration and the bridge.
It expands references such as `$SECRET` and `${SECRET}` using `envsubst`.
Values must be suitable for substitution into the generated JSON configuration;
use the shared-secret variable below rather than textual substitution for
double-puppeting secrets containing characters that need escaping.

For every bridge, `MAUTRIX_BRIDGE_LOGIN_SHARED_SECRET` sets the double-puppeting
secret for the configured homeserver domain. It maps to `double_puppet.secrets`
for bridgev2 and `bridge.login_shared_secret_map` for the legacy schema.
The module also recognizes the older `MAUTRIX_<NETWORK>_BRIDGE_LOGIN_SHARED_SECRET`
variables (including `MAUTRIX_META_BRIDGE_LOGIN_SHARED_SECRET`). The common variable
takes precedence. Alternatively, reference any environment variable directly in
the appropriate `settings` entry, as in the example above.
The shared token must belong to a separate double-puppeting appservice registered
on the homeserver, not the bridge's own registration. See the upstream
[double-puppeting setup](https://docs.mau.fi/bridges/general/double-puppeting.html).
Restart the instance's registration service and then the bridge after updating
an environment file. Restart Synapse as well if application-service tokens changed.

Telegram supports native overrides with the `MAUTRIX_TELEGRAM_` prefix. Use two
underscores between configuration levels, for example
`MAUTRIX_TELEGRAM_NETWORK__API_ID`, `MAUTRIX_TELEGRAM_NETWORK__API_HASH`, and
`MAUTRIX_TELEGRAM_APPSERVICE__AS_TOKEN`. Use the common
`MAUTRIX_BRIDGE_LOGIN_SHARED_SECRET` variable for double puppeting: Telegram
interprets every variable with its native prefix as a configuration field.
Python-style single-underscore names and `json::` values do not apply to this
Go implementation.

The module uses explicitly configured application-service tokens first, then
tokens from the existing registration file. If neither source provides tokens,
the bridge generates them on first startup. The module regenerates registration
for configuration changes without rotating these tokens. Keep a backup of the
registration file along with the database.

::: {.warning}
For bridgev2, supply persistent encryption/signing keys through environment files
when enabling features that require them. Avoid `generate` for
`encryption.pickle_key`, `provisioning.shared_secret`, `public_media.signing_key`,
and `direct_media.server_key`: regenerating these on each start can make existing
data unreadable. The Meta profiles retain the legacy `mautrix.bridge.e2ee` pickle
key for database compatibility. Changing it requires a separate database migration.
:::

## Register with a homeserver {#module-services-mautrix-registration}

With a local Synapse, `registerToSynapse` defaults to `true`. A separate
`mautrix-<name>-registration.service` prepares the configuration and registration
before Synapse starts, including when Synapse workers are enabled. The bridge
starts after its configured homeserver dependencies. Generating registration
separately avoids a first-boot dependency cycle between the bridge and Synapse.

Synapse receives group access to the registration and traversal access to the
state directory; the runtime configuration is owner-only. No manual copies or
world-readable directory permissions are needed. Registrations disable rate limiting.

For a remote or non-Synapse homeserver, install the generated `registrationFile`
on that homeserver yourself and synchronize it after configuration changes.
`serviceDependencies` controls startup ordering, not remote registration.
See the upstream [registration instructions](https://docs.mau.fi/bridges/general/registering-appservices.html)
for homeserver-specific steps.

## Migrate from services.mautrix-* {#module-services-mautrix-migration}

<!-- Preserve links from historical release notes to the removed options. -->
[]{#opt-services.mautrix-discord.enable}
[]{#opt-services.mautrix-signal.enable}
[]{#opt-services.mautrix-whatsapp.enable}

`services.mautrix.bridges` replaces the individual modules without automatically
migrating upstream configuration or databases. Back up each state directory first.

| Old configuration | New configuration | Required `type` |
| --- | --- | --- |
| `services.mautrix-discord` | `services.mautrix.bridges.discord` | `discord` |
| `services.mautrix-signal` | `services.mautrix.bridges.signal` | `signal` |
| `services.mautrix-whatsapp` | `services.mautrix.bridges.whatsapp` | `whatsapp` |
| `services.mautrix-telegram` | `services.mautrix.bridges.telegram` | `telegram` |
| `services.mautrix-meta.instances.facebook` | `services.mautrix.bridges.meta-facebook` | `facebook` |
| `services.mautrix-meta.instances.instagram` | `services.mautrix.bridges.meta-instagram` | `instagram` |

1. Move each configuration to its new path, add `type`, and move `environmentFile`
   to `environmentFiles = [ oldPath ];`. Existing `enable = true`, `settings`,
   `registerToSynapse`, `package`, and `serviceDependencies` can be carried over.
   Do not copy an old Meta `serviceDependencies` list containing its own registration
   service: the module now adds that dependency automatically.
2. Keep the instance names above to retain service names, users, default state
   directories, database filenames, and registration filenames. For a custom Meta
   instance named `foo`, use `meta-foo`, select the appropriate network type, and
   retain its explicit network mode, appservice identity, and bot configuration.
3. The old Meta `dataDir` was relative to `/var/lib`; the new `dataDir` is absolute.
   Move the old top-level Meta `package` override into each instance.
4. Remove manual Synapse registration entries, supplementary groups, directory
   permission workarounds, and replacement registration `preStart` scripts. Put
   environment files in the new option so registration generation can read them too.
5. Old Meta instances shared the `mautrix-meta` group. Each instance now has its
   own group. Systemd manages the state directory's ownership; check permissions
   on externally managed database files and secrets when upgrading.

The Telegram profile uses the Go implementation. Migrate Python Telegram settings
and databases separately using the upstream migration instructions. In particular,
move database settings to `database`, Telegram API credentials to `network`,
and encryption settings to `encryption`. Use the native environment override
names described above instead of Python-style names.

Existing registrations retain their tokens unless explicitly overridden. The
new module regenerates registration metadata after changes, unlike the old
Signal, WhatsApp, and Telegram modules. Restart the homeserver after changing
registration metadata or tokens so it reloads the registration.
