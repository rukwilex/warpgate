# Warpgate command line

`warpgate` does everything the app does from a terminal. This file is generated from the action registry by `packages/warpgate_cli/tool/gen_docs.dart`. Do not edit it by hand.

## Quick start

```sh
warpgate-cli --install
warpgate hosts add prod deploy@10.0.0.5
warpgate known-hosts trust prod
warpgate exec prod -- uptime
warpgate cp prod:/var/log/app.log ./
warpgate completion zsh > ~/.zfunc/_warpgate
warpgate doctor
```

In the app, Settings → Command line installs and removes the command too.

## How hosts and paths are written

- A host is a label, an id, the start of an id, or `user@host[:port]`.
- `@web` means every host in the group `web`. Commands that take many hosts also accept `a,b,@web`.
- A remote path is `host:path`, and `host:` alone is the home folder. Anything else is local. To force a local path that contains a colon, write `./a:b`.
- A host written as `user@host` that is not saved signs in with ssh-agent, then the unencrypted keys in `~/.ssh`, then asks for a password.

## Standalone and attached

Without the app, the command uses the same database as the app directly. With the app running:

- Reads and SSH work still run in the command, so they stay fast.
- Changes go through the app so its screens update at once. Changes made with `--no-app` show up in the app within a second.
- Commands that show something in the app need it. They start it, or say how, and wait up to 10 seconds.

`--no-app` forces standalone mode.

### Secrets

Saved passwords and keys are read the first time they are needed:

1. From the file in `WARPGATE_MASTER_KEY_FILE`, for machines with no keychain. The file must be readable only by you.
2. From the running app, one secret at a time. The app refuses while it is locked.
3. From secure storage: the keychain on macOS, the system keyring through `secret-tool` on Linux, Windows data protection on Windows.

`warpgate` never prints a secret, with one exception that asks first: `warpgate mcp token show`.

### Profiles

`--profile work` or `WARPGATE_PROFILE=work` keeps a separate set of hosts, keys and settings. `WARPGATE_HOME` moves the data folder.

## Host keys

An unknown key is shown and asked about in a terminal. With no terminal it is refused with exit code 5, so run `warpgate known-hosts trust <host>` first. A changed key is always refused with no terminal, and a terminal has to type `trust`.

## Output

- Tables go to stdout. Progress goes to stderr, and only when stdout is a terminal.
- `--json` prints one object on stdout and nothing else. Every object has a `schema` field such as `warpgate.hosts.list/1`. The number changes when a field is removed or changes meaning.
- Errors with `--json` go to stderr: `{"schema":"warpgate.error/1","code":3,"kind":"notFound","message":"...","hint":"..."}`.
- Color follows the terminal, `--no-color` and `NO_COLOR`.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | General error |
| 2 | Usage error |
| 3 | Not found |
| 4 | Authentication failed |
| 5 | Host key mismatch or not trusted |
| 6 | Connection failed |
| 7 | Partial failure on a multi-host command |
| 130 | Interrupted |

On `exec` and `ssh` with one host, the code is the one the remote command returned.

## Flags for every command

```
-h, --help              Show help
    --version           Print the version
    --json              Print stable JSON on stdout
    --quiet             Print only what was asked for
    --no-color          Turn off color. NO_COLOR also works
-y, --yes               Skip confirmations
-v, --verbose           Print more detail on stderr
    --profile <NAME>    Use a separate set of hosts, keys and settings
    --no-app            Do not talk to the running app
```

## Commands

### Connect

#### warpgate ssh

```
Open an interactive shell on a host, or run one command

Usage:
  warpgate ssh [flags] <host> [command...]

Arguments:
  host     Host label, id or user@host[:port]
  command  Command to run instead of a shell

Flags:
  -L, --local-forward <SPEC>    Forward a local port: [bind:]port:host:hostport. Can be repeated
  -R, --remote-forward <SPEC>   Forward a remote port: port:host:hostport. Can be repeated
  -D, --dynamic-forward <SPEC>  Start a SOCKS proxy: [bind:]port. Can be repeated
  -J, --jump <HOST>             Connect through this host
      --tmux                    Attach the persistent tmux session

Examples:
  warpgate ssh prod
  warpgate ssh deploy@10.0.0.5:2222 uptime
  warpgate ssh prod -L 8080:localhost:80 -J bastion

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.

JSON schema `warpgate.ssh/1`:

```json
{
  "type": "object",
  "properties": {
    "exit_code": {
      "type": "integer"
    }
  }
}
```

#### warpgate exec

```
Run a command on one host or many in parallel

Usage:
  warpgate exec [flags] <targets> -- <command...>

Arguments:
  targets  Hosts: a label, @group, or a comma-separated list
  command  Command to run, after --

Flags:
  -p, --parallel <N>     Hosts to run at once. Default: 8
  -t, --timeout <TIME>   Stop waiting after this long, such as 30s or 5m. On several hosts the default is 60s
      --stop-on-failure  Run hosts one at a time and stop at the first failure

On one host the exit code is the remote command's. On several hosts it is 0 when all succeed and 7 when any fail.

Examples:
  warpgate exec prod -- uptime
  warpgate exec @web --parallel 4 -- systemctl restart nginx
  warpgate exec a,b,c --json -- df -h /

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: destructive.
MCP tools: `run_command`, `run_on_hosts`.

JSON schema `warpgate.exec/1`:

```json
{
  "type": "object",
  "properties": {
    "results": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "host": {
            "type": "string"
          },
          "exit_code": {
            "type": "integer",
            "nullable": true
          },
          "stdout": {
            "type": "string"
          },
          "stderr": {
            "type": "string"
          },
          "duration_ms": {
            "type": "integer"
          },
          "timed_out": {
            "type": "boolean"
          },
          "error": {
            "type": "string",
            "nullable": true
          }
        }
      }
    },
    "succeeded": {
      "type": "integer"
    },
    "failed": {
      "type": "integer"
    }
  }
}
```

#### warpgate open

```
Open or focus the app at a host

Usage:
  warpgate open [flags] [host]

Arguments:
  host  Host label, id or user@host[:port]

Flags:
      --files             Open files instead of a terminal
      --local             Open a local terminal
      --split <SIDE>      Split the focused pane instead of a new tab. One of: right, down
      --workspace <NAME>  Workspace to open it in

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate open
  warpgate open prod --files
  warpgate open staging --split right --workspace ops

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `session.local`, `sftp.new`.

JSON schema `warpgate.open/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

### Hosts and groups

#### warpgate hosts list

```
List saved hosts

Usage:
  warpgate hosts list [flags]

Flags:
  -g, --group <GROUP>  Only hosts in this group
      --tag <TAG>      Only hosts with this tag

Examples:
  warpgate hosts list
  warpgate hosts list --group web
  warpgate hosts list --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.
MCP tools: `list_hosts`.

JSON schema `warpgate.hosts.list/1`:

```json
{
  "type": "object",
  "properties": {
    "hosts": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "label": {
            "type": "string"
          },
          "address": {
            "type": "string"
          },
          "port": {
            "type": "integer"
          },
          "username": {
            "type": "string"
          },
          "auth": {
            "type": "string"
          },
          "key_id": {
            "type": "string",
            "nullable": true
          },
          "group": {
            "type": "string",
            "nullable": true
          },
          "tags": {
            "type": "array",
            "items": {
              "type": "string"
            }
          },
          "jump_host_id": {
            "type": "string",
            "nullable": true
          },
          "tmux": {
            "type": "boolean"
          },
          "mcp_permission": {
            "type": "string"
          },
          "status": {
            "type": "string"
          }
        }
      }
    }
  }
}
```

#### warpgate hosts show

```
Show the settings of one host

Usage:
  warpgate hosts show <host>

Arguments:
  host  Host label, id or user@host[:port]

Examples:
  warpgate hosts show prod
  warpgate hosts show prod --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.hosts.show/1`:

```json
{
  "type": "object",
  "properties": {
    "host": {
      "type": "object",
      "properties": {
        "id": {
          "type": "string"
        },
        "label": {
          "type": "string"
        },
        "address": {
          "type": "string"
        },
        "port": {
          "type": "integer"
        },
        "username": {
          "type": "string"
        },
        "auth": {
          "type": "string"
        },
        "key_id": {
          "type": "string",
          "nullable": true
        },
        "group": {
          "type": "string",
          "nullable": true
        },
        "tags": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "jump_host_id": {
          "type": "string",
          "nullable": true
        },
        "tmux": {
          "type": "boolean"
        },
        "mcp_permission": {
          "type": "string"
        },
        "status": {
          "type": "string"
        }
      }
    },
    "forwards": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "host": {
            "type": "string"
          },
          "kind": {
            "type": "string"
          },
          "bind_host": {
            "type": "string"
          },
          "bind_port": {
            "type": "integer"
          },
          "target_host": {
            "type": "string"
          },
          "target_port": {
            "type": "integer"
          },
          "auto_start": {
            "type": "boolean"
          },
          "state": {
            "type": "string",
            "nullable": true
          }
        }
      }
    }
  }
}
```

#### warpgate hosts add

```
Save a new host

Usage:
  warpgate hosts add [flags] <label> <target>

Arguments:
  label   Name to show for this host
  target  Address as user@host[:port]

Flags:
      --auth <METHOD>   How to sign in. One of: password, key, keyboardInteractive, agent. Default: agent
  -i, --key <KEY>       Saved key to sign in with
  -g, --group <GROUP>   Group to put it in
      --tag <TAG>       Tag. Can be repeated
  -J, --jump <HOST>     Jump host
      --password-stdin  Read the password from stdin
      --tmux            Keep sessions alive in tmux

Examples:
  warpgate hosts add prod deploy@10.0.0.5
  warpgate hosts add db root@db.local:2222 --auth key --key work -g data
  printf %s "$PW" | warpgate hosts add lab me@lab --auth password --password-stdin

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.hosts.add/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    },
    "label": {
      "type": "string"
    }
  }
}
```

#### warpgate hosts edit

```
Change the settings of a saved host

Usage:
  warpgate hosts edit [flags] <host>

Arguments:
  host  Host label, id or user@host[:port]

Flags:
      --label <NAME>       New label
      --address <ADDRESS>  New address
  -p, --port <N>           New port
  -u, --user <NAME>        New user name
      --auth <METHOD>      How to sign in. One of: password, key, keyboardInteractive, agent
  -i, --key <KEY>          Saved key to sign in with
  -g, --group <GROUP>      Group, or "none"
  -J, --jump <HOST>        Jump host, or "none"
      --tag <TAG>          Replace tags. Can be repeated
      --mcp <LEVEL>        Claude Code access. One of: off, readOnly, full
      --password-stdin     Read a new password from stdin
      --clear-password     Forget the saved password

Examples:
  warpgate hosts edit prod --port 2222
  warpgate hosts edit prod --group web --tag eu --tag live
  warpgate hosts edit prod --mcp readOnly

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.hosts.edit/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    },
    "label": {
      "type": "string"
    }
  }
}
```

#### warpgate hosts rm

```
Remove a saved host and its password

Usage:
  warpgate hosts rm <host>

Arguments:
  host  Host label, id or user@host[:port]

Examples:
  warpgate hosts rm old-box
  warpgate hosts rm old-box --yes

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: destructive.

JSON schema `warpgate.hosts.rm/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    },
    "label": {
      "type": "string"
    }
  }
}
```

#### warpgate hosts test

```
Connect to a host and report how long it took

Usage:
  warpgate hosts test <host>

Arguments:
  host  Host label, id or user@host[:port]

Examples:
  warpgate hosts test prod
  warpgate hosts test deploy@10.0.0.5 --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.hosts.test/1`:

```json
{
  "type": "object",
  "properties": {
    "label": {
      "type": "string"
    },
    "ok": {
      "type": "boolean"
    },
    "duration_ms": {
      "type": "integer"
    },
    "server": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate hosts import-ssh-config

```
Add hosts from an OpenSSH config file

Usage:
  warpgate hosts import-ssh-config [file]

Arguments:
  file  Config file. Defaults to ~/.ssh/config

Examples:
  warpgate hosts import-ssh-config
  warpgate hosts import-ssh-config ./ssh_config

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.hosts.import-ssh-config/1`:

```json
{
  "type": "object",
  "properties": {
    "imported": {
      "type": "integer"
    }
  }
}
```

#### warpgate hosts export

```
Print saved hosts as an OpenSSH config, without secrets

Usage:
  warpgate hosts export [flags]

Flags:
      --format <FORMAT>  Output format. One of: ssh-config, json. Default: ssh-config

Examples:
  warpgate hosts export > hosts.conf
  warpgate hosts export --format json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.hosts.export/1`:

```json
{
  "type": "object",
  "properties": {
    "content": {
      "type": "string"
    },
    "count": {
      "type": "integer"
    }
  }
}
```

#### warpgate groups list

```
List host groups

Usage:
  warpgate groups list

Examples:
  warpgate groups list
  warpgate groups list --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.
MCP tools: `list_groups`.

JSON schema `warpgate.groups.list/1`:

```json
{
  "type": "object",
  "properties": {
    "groups": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "hosts": {
            "type": "array",
            "items": {
              "type": "string"
            }
          }
        }
      }
    }
  }
}
```

#### warpgate groups add

```
Create a host group

Usage:
  warpgate groups add <name>

Arguments:
  name  Group name

Examples:
  warpgate groups add web
  warpgate groups add "EU data"

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.groups.add/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    },
    "name": {
      "type": "string"
    }
  }
}
```

#### warpgate groups rm

```
Remove a group. Its hosts stay saved, ungrouped

Usage:
  warpgate groups rm <group>

Arguments:
  group  Group name or id

Examples:
  warpgate groups rm web
  warpgate groups rm web --yes

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: destructive.

JSON schema `warpgate.groups.rm/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    },
    "name": {
      "type": "string"
    }
  }
}
```

#### warpgate groups move

```
Move hosts into a group, or out with "none"

Usage:
  warpgate groups move <group> <hosts...>

Arguments:
  group  Group name, or "none"
  hosts  Hosts to move

Examples:
  warpgate groups move web prod staging
  warpgate groups move none old-box

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.groups.move/1`:

```json
{
  "type": "object",
  "properties": {
    "moved": {
      "type": "integer"
    }
  }
}
```

#### warpgate groups open

```
Open every host in a group in a grid in the app

Usage:
  warpgate groups open [group]

Arguments:
  group  Group name or id

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate groups open web
  warpgate groups open

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `group.open`.

JSON schema `warpgate.groups.open/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

### Keys

#### warpgate keys list

```
List saved SSH keys

Usage:
  warpgate keys list

Examples:
  warpgate keys list
  warpgate keys list --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.keys.list/1`:

```json
{
  "type": "object",
  "properties": {
    "keys": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "algorithm": {
            "type": "string"
          },
          "fingerprint": {
            "type": "string"
          },
          "public_key": {
            "type": "string"
          },
          "created_at": {
            "type": "string"
          },
          "has_passphrase": {
            "type": "boolean"
          }
        }
      }
    }
  }
}
```

#### warpgate keys generate

```
Create a new SSH key

Usage:
  warpgate keys generate [flags] <name>

Arguments:
  name  Key name

Flags:
  -t, --type <TYPE>  Key type. One of: ed25519, rsa. Default: ed25519

Examples:
  warpgate keys generate work
  warpgate keys generate legacy --type rsa

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.keys.generate/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    },
    "name": {
      "type": "string"
    },
    "algorithm": {
      "type": "string"
    },
    "fingerprint": {
      "type": "string"
    },
    "public_key": {
      "type": "string"
    },
    "created_at": {
      "type": "string"
    },
    "has_passphrase": {
      "type": "boolean"
    }
  }
}
```

#### warpgate keys import

```
Save a private key from a file

Usage:
  warpgate keys import [flags] <file>

Arguments:
  file  Private key file

Flags:
  -n, --name <NAME>       Key name. Defaults to the file name
      --passphrase-stdin  Read the passphrase from stdin

Examples:
  warpgate keys import ~/.ssh/id_ed25519
  warpgate keys import ./deploy.pem --name deploy

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.keys.import/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    },
    "name": {
      "type": "string"
    },
    "algorithm": {
      "type": "string"
    },
    "fingerprint": {
      "type": "string"
    },
    "public_key": {
      "type": "string"
    },
    "created_at": {
      "type": "string"
    },
    "has_passphrase": {
      "type": "boolean"
    }
  }
}
```

#### warpgate keys export-public

```
Print the public half of a key

Usage:
  warpgate keys export-public <key>

Arguments:
  key  Key name or id

Examples:
  warpgate keys export-public work
  warpgate keys export-public work >> authorized_keys

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.keys.export-public/1`:

```json
{
  "type": "object",
  "properties": {
    "public_key": {
      "type": "string"
    }
  }
}
```

#### warpgate keys install

```
Add a key to a host's authorized_keys

Usage:
  warpgate keys install <key> <host>

Arguments:
  key   Key name or id
  host  Host label, id or user@host[:port]

Examples:
  warpgate keys install work prod
  warpgate keys install work deploy@10.0.0.5

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.

JSON schema `warpgate.keys.install/1`:

```json
{
  "type": "object",
  "properties": {
    "key": {
      "type": "string"
    },
    "host": {
      "type": "string"
    }
  }
}
```

#### warpgate keys rm

```
Delete a saved key

Usage:
  warpgate keys rm <key>

Arguments:
  key  Key name or id

Examples:
  warpgate keys rm old
  warpgate keys rm old --yes

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: destructive.

JSON schema `warpgate.keys.rm/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    },
    "name": {
      "type": "string"
    }
  }
}
```

#### warpgate known-hosts list

```
List trusted host keys

Usage:
  warpgate known-hosts list

Examples:
  warpgate known-hosts list
  warpgate known-hosts list --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.known-hosts.list/1`:

```json
{
  "type": "object",
  "properties": {
    "known_hosts": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "endpoint": {
            "type": "string"
          },
          "key_type": {
            "type": "string"
          },
          "fingerprint": {
            "type": "string"
          },
          "added_at": {
            "type": "string"
          }
        }
      }
    }
  }
}
```

#### warpgate known-hosts rm

```
Forget a trusted host key

Usage:
  warpgate known-hosts rm <endpoint>

Arguments:
  endpoint  Endpoint as address:port, or a host label

Examples:
  warpgate known-hosts rm 10.0.0.5:22
  warpgate known-hosts rm prod --yes

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: destructive.

JSON schema `warpgate.known-hosts.rm/1`:

```json
{
  "type": "object",
  "properties": {
    "endpoint": {
      "type": "string"
    }
  }
}
```

#### warpgate known-hosts trust

```
Fetch the key of a host, show it and save it

Usage:
  warpgate known-hosts trust [flags] <host>

Arguments:
  host  Host label, id or user@host[:port]

Flags:
      --fingerprint <FINGERPRINT>  Only trust this exact fingerprint

Examples:
  warpgate known-hosts trust prod
  warpgate known-hosts trust prod --fingerprint "SHA256:abc"

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.

JSON schema `warpgate.known-hosts.trust/1`:

```json
{
  "type": "object",
  "properties": {
    "endpoint": {
      "type": "string"
    },
    "key_type": {
      "type": "string"
    },
    "fingerprint": {
      "type": "string"
    },
    "added_at": {
      "type": "string"
    }
  }
}
```

### Files

#### warpgate ls

```
List a remote or local folder

Usage:
  warpgate ls [flags] <path>

Arguments:
  path  host:path, or a local path

Flags:
  -l, --long          Show size, owner and modified time
  -a, --all           Include hidden files
      --tree          Show folders as a tree
      --sort <FIELD>  Sort order. One of: name, size, time. Default: name

Also: warpgate files ls

Examples:
  warpgate ls prod:/var/log
  warpgate ls -la prod:~
  warpgate ls --tree --sort size staging:/srv/app

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.
MCP tools: `sftp_list`.

JSON schema `warpgate.files.ls/1`:

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string"
    },
    "entries": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          },
          "path": {
            "type": "string"
          },
          "type": {
            "type": "string"
          },
          "size": {
            "type": "integer"
          },
          "modified": {
            "type": "string",
            "nullable": true
          },
          "mode": {
            "type": "string",
            "nullable": true
          },
          "permissions": {
            "type": "string"
          },
          "owner": {
            "type": "string",
            "nullable": true
          },
          "group": {
            "type": "string",
            "nullable": true
          }
        }
      }
    }
  }
}
```

#### warpgate cat

```
Print a remote file

Usage:
  warpgate cat <path>

Arguments:
  path  host:path

Also: warpgate files cat

Examples:
  warpgate cat prod:/etc/hostname
  warpgate cat prod:/var/log/app.log | grep ERROR

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.
MCP tools: `sftp_read_file`.

JSON schema `warpgate.files.cat/1`:

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string"
    },
    "size": {
      "type": "integer"
    },
    "content": {
      "type": "string"
    }
  }
}
```

#### warpgate get

```
Download from a host to this device

Usage:
  warpgate get [flags] <source> [target]

Arguments:
  source  host:path
  target  Local path. Defaults to the current folder

Flags:
  -r, --recursive  Include folders
      --resume     Continue a partial file
      --verify     Compare sha256 after each file

Also: warpgate files get

Examples:
  warpgate get prod:/var/log/app.log
  warpgate get -r prod:/srv/app ./backup
  warpgate get --resume prod:/data/big.tar .

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.
MCP tools: `sftp_download`.

JSON schema `warpgate.files.get/1`:

```json
{
  "type": "object",
  "properties": {
    "transfers": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "status": {
            "type": "string"
          },
          "source": {
            "type": "string"
          },
          "target": {
            "type": "string"
          },
          "total_bytes": {
            "type": "integer"
          },
          "done_bytes": {
            "type": "integer"
          },
          "bytes_per_second": {
            "type": "integer"
          },
          "origin": {
            "type": "string"
          },
          "error": {
            "type": "string",
            "nullable": true
          }
        }
      }
    },
    "failed": {
      "type": "integer"
    }
  }
}
```

#### warpgate put

```
Upload from this device to a host

Usage:
  warpgate put [flags] <source> <target>

Arguments:
  source  Local path, or - for stdin
  target  host:path

Flags:
  -r, --recursive  Include folders
      --resume     Continue a partial file
      --verify     Compare sha256 after each file

Also: warpgate files put

Examples:
  warpgate put ./app.tar prod:/tmp/
  warpgate put -r ./site staging:/srv/
  echo hello | warpgate put - prod:/tmp/note.txt

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.
MCP tools: `sftp_upload`, `sftp_write_file`.

JSON schema `warpgate.files.put/1`:

```json
{
  "type": "object",
  "properties": {
    "transfers": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "status": {
            "type": "string"
          },
          "source": {
            "type": "string"
          },
          "target": {
            "type": "string"
          },
          "total_bytes": {
            "type": "integer"
          },
          "done_bytes": {
            "type": "integer"
          },
          "bytes_per_second": {
            "type": "integer"
          },
          "origin": {
            "type": "string"
          },
          "error": {
            "type": "string",
            "nullable": true
          }
        }
      }
    },
    "failed": {
      "type": "integer"
    }
  }
}
```

#### warpgate cp

```
Copy between any two places, including two hosts

Usage:
  warpgate cp [flags] <source...>

Arguments:
  source  host:path or a local path. The last one is the target

Flags:
  -r, --recursive             Include folders
      --move                  Delete the source after a verified copy
      --resume                Continue a partial file
      --direct                Use rsync or scp on the source host when it can reach the target
      --verify                Compare sha256 after each file
      --queue                 Add to the app queue and return at once. Needs the app
      --on-conflict <ACTION>  When a file exists. One of: ask, overwrite, skip, rename

The last path is the target. A target that ends in / or is a folder receives the source inside it.

Also: warpgate files cp

Examples:
  warpgate cp prod:/var/log/app.log staging:/tmp/
  warpgate cp -r --verify ./site prod:/srv/
  warpgate cp --direct --move prod:/data/big.tar backup:/data/

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.
MCP tools: `transfer_between_hosts`.

JSON schema `warpgate.files.cp/1`:

```json
{
  "type": "object",
  "properties": {
    "transfers": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "status": {
            "type": "string"
          },
          "source": {
            "type": "string"
          },
          "target": {
            "type": "string"
          },
          "total_bytes": {
            "type": "integer"
          },
          "done_bytes": {
            "type": "integer"
          },
          "bytes_per_second": {
            "type": "integer"
          },
          "origin": {
            "type": "string"
          },
          "error": {
            "type": "string",
            "nullable": true
          }
        }
      }
    },
    "failed": {
      "type": "integer"
    }
  }
}
```

#### warpgate mv

```
Rename or move within one host

Usage:
  warpgate mv <source> <target>

Arguments:
  source  host:path
  target  New path on the same host

Also: warpgate files mv

Examples:
  warpgate mv prod:/tmp/a.txt prod:/tmp/b.txt
  warpgate mv prod:/tmp/a.txt /srv/a.txt

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.

JSON schema `warpgate.files.mv/1`:

```json
{
  "type": "object",
  "properties": {
    "source": {
      "type": "string"
    },
    "target": {
      "type": "string"
    }
  }
}
```

#### warpgate rm

```
Delete a file or folder

Usage:
  warpgate rm [flags] <path>

Arguments:
  path  host:path or a local path

Flags:
  -r, --recursive  Include folders and everything in them

Also: warpgate files rm

Examples:
  warpgate rm prod:/tmp/old.log
  warpgate rm -r prod:/tmp/build --yes

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: destructive.

JSON schema `warpgate.files.rm/1`:

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string"
    }
  }
}
```

#### warpgate mkdir

```
Create a folder

Usage:
  warpgate mkdir [flags] <path>

Arguments:
  path  host:path or a local path

Flags:
  -p, --parents  Create missing parent folders

Also: warpgate files mkdir

Examples:
  warpgate mkdir prod:/srv/app
  warpgate mkdir -p prod:/srv/app/releases/42

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.

JSON schema `warpgate.files.mkdir/1`:

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string"
    }
  }
}
```

#### warpgate chmod

```
Change the permissions of a file or folder

Usage:
  warpgate chmod <mode> <path>

Arguments:
  mode  Octal mode, such as 640
  path  host:path or a local path

Also: warpgate files chmod

Examples:
  warpgate chmod 640 prod:/srv/app/.env
  warpgate chmod 755 prod:/srv/app/run.sh

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.

JSON schema `warpgate.files.chmod/1`:

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string"
    },
    "mode": {
      "type": "string"
    }
  }
}
```

#### warpgate stat

```
Show details of a file or folder

Usage:
  warpgate stat <path>

Arguments:
  path  host:path or a local path

Also: warpgate files stat

Examples:
  warpgate stat prod:/etc/hosts
  warpgate stat prod:/srv --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.files.stat/1`:

```json
{
  "type": "object",
  "properties": {
    "entry": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string"
        },
        "path": {
          "type": "string"
        },
        "type": {
          "type": "string"
        },
        "size": {
          "type": "integer"
        },
        "modified": {
          "type": "string",
          "nullable": true
        },
        "mode": {
          "type": "string",
          "nullable": true
        },
        "permissions": {
          "type": "string"
        },
        "owner": {
          "type": "string",
          "nullable": true
        },
        "group": {
          "type": "string",
          "nullable": true
        }
      }
    }
  }
}
```

#### warpgate edit

```
Open a remote file in $EDITOR and upload it on save

Usage:
  warpgate edit <path>

Arguments:
  path  host:path

Also: warpgate files edit

Examples:
  warpgate edit prod:/etc/nginx/nginx.conf
  EDITOR=nano warpgate edit prod:~/.bashrc

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.

JSON schema `warpgate.files.edit/1`:

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string"
    },
    "uploaded": {
      "type": "boolean"
    }
  }
}
```

#### warpgate find

```
Find files by name under a folder

Usage:
  warpgate find [flags] <path> <pattern>

Arguments:
  path     host:path or a local path
  pattern  Name pattern, with * and ?

Flags:
      --max <N>  Stop after this many matches. Default: 1000

Also: warpgate files find

Examples:
  warpgate find prod:/var/log "*.gz"
  warpgate find prod:/srv "config.*" --max 20

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.files.find/1`:

```json
{
  "type": "object",
  "properties": {
    "matches": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          },
          "path": {
            "type": "string"
          },
          "type": {
            "type": "string"
          },
          "size": {
            "type": "integer"
          },
          "modified": {
            "type": "string",
            "nullable": true
          },
          "mode": {
            "type": "string",
            "nullable": true
          },
          "permissions": {
            "type": "string"
          },
          "owner": {
            "type": "string",
            "nullable": true
          },
          "group": {
            "type": "string",
            "nullable": true
          }
        }
      }
    },
    "truncated": {
      "type": "boolean"
    }
  }
}
```

#### warpgate du

```
Add up the size of a folder

Usage:
  warpgate du <path>

Arguments:
  path  host:path or a local path

Also: warpgate files du

Examples:
  warpgate du prod:/var/log
  warpgate du prod:/srv --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.files.du/1`:

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string"
    },
    "total": {
      "type": "integer"
    },
    "files": {
      "type": "integer"
    },
    "children": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          },
          "size": {
            "type": "integer"
          }
        }
      }
    }
  }
}
```

#### warpgate files toggle

```
Show or hide files next to the focused terminal

Usage:
  warpgate files toggle

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate files toggle
  warpgate files toggle --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `sftp.here`.

JSON schema `warpgate.files.toggle/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate files here

```
Open files at the folder of the focused terminal, in a new pane

Usage:
  warpgate files here

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate files here
  warpgate files here --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `sftp.split`.

JSON schema `warpgate.files.here/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate files dual

```
Open a two-pane file browser in the app

Usage:
  warpgate files dual

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate files dual
  warpgate files dual --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `sftp.dual`.

JSON schema `warpgate.files.dual/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

### Transfers and forwards

#### warpgate transfers list

```
List transfers from the app and the CLI

Usage:
  warpgate transfers list [flags]

Flags:
      --status <STATUS>  Only this status. One of: queued, running, paused, completed, failed, canceled

Examples:
  warpgate transfers list
  warpgate transfers list --status failed
  warpgate transfers list --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.
MCP tools: `list_transfers`.

JSON schema `warpgate.transfers.list/1`:

```json
{
  "type": "object",
  "properties": {
    "transfers": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "status": {
            "type": "string"
          },
          "source": {
            "type": "string"
          },
          "target": {
            "type": "string"
          },
          "total_bytes": {
            "type": "integer"
          },
          "done_bytes": {
            "type": "integer"
          },
          "bytes_per_second": {
            "type": "integer"
          },
          "origin": {
            "type": "string"
          },
          "error": {
            "type": "string",
            "nullable": true
          }
        }
      }
    }
  }
}
```

#### warpgate transfers watch

```
Follow transfers until they finish

Usage:
  warpgate transfers watch [id]

Arguments:
  id  Only this transfer

Examples:
  warpgate transfers watch
  warpgate transfers watch 3f2a --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.transfers.watch/1`:

```json
{
  "type": "object",
  "properties": {
    "transfers": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "status": {
            "type": "string"
          },
          "source": {
            "type": "string"
          },
          "target": {
            "type": "string"
          },
          "total_bytes": {
            "type": "integer"
          },
          "done_bytes": {
            "type": "integer"
          },
          "bytes_per_second": {
            "type": "integer"
          },
          "origin": {
            "type": "string"
          },
          "error": {
            "type": "string",
            "nullable": true
          }
        }
      }
    }
  }
}
```

#### warpgate transfers pause

```
Pause a transfer

Usage:
  warpgate transfers pause <id>

Arguments:
  id  Transfer id

Examples:
  warpgate transfers pause 3f2a
  warpgate transfers pause 3f2a --json

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.transfers.pause/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    }
  }
}
```

#### warpgate transfers resume

```
Resume a paused transfer

Usage:
  warpgate transfers resume <id>

Arguments:
  id  Transfer id

With the app running, the app continues it. Otherwise this command runs it until it ends.

Examples:
  warpgate transfers resume 3f2a
  warpgate --no-app transfers resume 3f2a

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.

JSON schema `warpgate.transfers.resume/1`:

```json
{
  "type": "object",
  "properties": {
    "transfers": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "status": {
            "type": "string"
          },
          "source": {
            "type": "string"
          },
          "target": {
            "type": "string"
          },
          "total_bytes": {
            "type": "integer"
          },
          "done_bytes": {
            "type": "integer"
          },
          "bytes_per_second": {
            "type": "integer"
          },
          "origin": {
            "type": "string"
          },
          "error": {
            "type": "string",
            "nullable": true
          }
        }
      }
    },
    "failed": {
      "type": "integer"
    }
  }
}
```

#### warpgate transfers cancel

```
Cancel a queued or running transfer

Usage:
  warpgate transfers cancel <id>

Arguments:
  id  Transfer id

Examples:
  warpgate transfers cancel 3f2a
  warpgate transfers cancel 3f2a --yes

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: destructive.
MCP tools: `cancel_transfer`.

JSON schema `warpgate.transfers.cancel/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    }
  }
}
```

#### warpgate transfers retry

```
Run a failed or cancelled transfer again

Usage:
  warpgate transfers retry <id>

Arguments:
  id  Transfer id, or "failed" for all failed

Examples:
  warpgate transfers retry 3f2a
  warpgate transfers retry failed

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.

JSON schema `warpgate.transfers.retry/1`:

```json
{
  "type": "object",
  "properties": {
    "transfers": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "status": {
            "type": "string"
          },
          "source": {
            "type": "string"
          },
          "target": {
            "type": "string"
          },
          "total_bytes": {
            "type": "integer"
          },
          "done_bytes": {
            "type": "integer"
          },
          "bytes_per_second": {
            "type": "integer"
          },
          "origin": {
            "type": "string"
          },
          "error": {
            "type": "string",
            "nullable": true
          }
        }
      }
    },
    "failed": {
      "type": "integer"
    }
  }
}
```

#### warpgate transfers clear

```
Remove finished transfers from the list

Usage:
  warpgate transfers clear

Examples:
  warpgate transfers clear
  warpgate transfers clear --json

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.transfers.clear/1`:

```json
{
  "type": "object",
  "properties": {
    "cleared": {
      "type": "integer"
    }
  }
}
```

#### warpgate forward list

```
List saved port forwards

Usage:
  warpgate forward list [flags]

Flags:
      --host <HOST>  Only this host

Examples:
  warpgate forward list
  warpgate forward list --host prod --json

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: read.

JSON schema `warpgate.forward.list/1`:

```json
{
  "type": "object",
  "properties": {
    "forwards": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "host": {
            "type": "string"
          },
          "kind": {
            "type": "string"
          },
          "bind_host": {
            "type": "string"
          },
          "bind_port": {
            "type": "integer"
          },
          "target_host": {
            "type": "string"
          },
          "target_port": {
            "type": "integer"
          },
          "auto_start": {
            "type": "boolean"
          },
          "state": {
            "type": "string",
            "nullable": true
          }
        }
      }
    }
  }
}
```

#### warpgate forward add

```
Save a port forward on a host

Usage:
  warpgate forward add [flags] <host>

Arguments:
  host  Host label, id or user@host[:port]

Flags:
  -L, --local <SPEC>    Local forward: [bind:]port:host:hostport
  -R, --remote <SPEC>   Remote forward: port:host:hostport
  -D, --dynamic <SPEC>  SOCKS proxy: [bind:]port
      --auto-start      Start it when the app connects to the host

Examples:
  warpgate forward add prod -L 8080:localhost:80
  warpgate forward add prod -D 1080 --auto-start

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.forward.add/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    },
    "host": {
      "type": "string"
    }
  }
}
```

#### warpgate forward rm

```
Remove a saved port forward

Usage:
  warpgate forward rm <id>

Arguments:
  id  Forward id

Examples:
  warpgate forward rm 3f2a
  warpgate forward rm 3f2a --yes

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: destructive.

JSON schema `warpgate.forward.rm/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    }
  }
}
```

#### warpgate forward start

```
Start a saved port forward in the app

Usage:
  warpgate forward start <id>

Arguments:
  id  Forward id

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate forward start 3f2a
  warpgate forward start 3f2a --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.

JSON schema `warpgate.forward.start/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate forward stop

```
Stop a running port forward in the app

Usage:
  warpgate forward stop <id>

Arguments:
  id  Forward id

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate forward stop 3f2a
  warpgate forward stop 3f2a --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.

JSON schema `warpgate.forward.stop/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

### Snippets

#### warpgate snippets list

```
List saved snippets

Usage:
  warpgate snippets list

Examples:
  warpgate snippets list
  warpgate snippets list --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.snippets.list/1`:

```json
{
  "type": "object",
  "properties": {
    "snippets": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "body": {
            "type": "string"
          },
          "variables": {
            "type": "array",
            "items": {
              "type": "string"
            }
          }
        }
      }
    }
  }
}
```

#### warpgate snippets add

```
Save a snippet. Use {{name}} or {{name|default}} for variables

Usage:
  warpgate snippets add <name> [body]

Arguments:
  name  Snippet name
  body  Command text. Reads stdin when left out

Examples:
  warpgate snippets add restart "sudo systemctl restart {{service}}"
  warpgate snippets add cleanup < cleanup.sh

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.snippets.add/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    },
    "name": {
      "type": "string"
    }
  }
}
```

#### warpgate snippets edit

```
Change a snippet, in $EDITOR when no body is given

Usage:
  warpgate snippets edit [flags] <snippet> [body]

Arguments:
  snippet  Snippet name or id
  body     New command text

Flags:
      --name <NAME>  New name

Examples:
  warpgate snippets edit restart
  warpgate snippets edit restart "sudo service {{service}} restart"

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.snippets.edit/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    },
    "name": {
      "type": "string"
    }
  }
}
```

#### warpgate snippets rm

```
Delete a snippet

Usage:
  warpgate snippets rm <snippet>

Arguments:
  snippet  Snippet name or id

Examples:
  warpgate snippets rm restart
  warpgate snippets rm restart --yes

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: destructive.

JSON schema `warpgate.snippets.rm/1`:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string"
    },
    "name": {
      "type": "string"
    }
  }
}
```

#### warpgate snippets run

```
Run a snippet on hosts

Usage:
  warpgate snippets run [flags] <snippet>

Arguments:
  snippet  Snippet name or id

Flags:
      --on <TARGETS>    Hosts: a label, @group, or a comma-separated list
      --var <K=V>       Variable as key=value. Can be repeated
  -p, --parallel <N>    Hosts to run at once. Default: 8
  -t, --timeout <TIME>  Stop waiting after this long. Default: 60s

Examples:
  warpgate snippets run restart --on prod --var service=nginx
  warpgate snippets run cleanup --on @web --parallel 2

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: destructive.
Palette: `snippets.run`.

JSON schema `warpgate.snippets.run/1`:

```json
{
  "type": "object",
  "properties": {
    "results": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "host": {
            "type": "string"
          },
          "exit_code": {
            "type": "integer",
            "nullable": true
          },
          "stdout": {
            "type": "string"
          },
          "stderr": {
            "type": "string"
          },
          "duration_ms": {
            "type": "integer"
          },
          "timed_out": {
            "type": "boolean"
          },
          "error": {
            "type": "string",
            "nullable": true
          }
        }
      }
    },
    "succeeded": {
      "type": "integer"
    },
    "failed": {
      "type": "integer"
    }
  }
}
```

### Sessions and the app

#### warpgate sessions list

```
List terminal sessions open in the app

Usage:
  warpgate sessions list

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate sessions list
  warpgate sessions list --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: read.
MCP tools: `list_sessions`.

JSON schema `warpgate.sessions.list/1`:

```json
{
  "type": "object",
  "properties": {
    "sessions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "session_id": {
            "type": "string"
          },
          "host_id": {
            "type": "string",
            "nullable": true
          },
          "host_label": {
            "type": "string",
            "nullable": true
          },
          "workspace": {
            "type": "string"
          },
          "status": {
            "type": "string"
          },
          "opened_by": {
            "type": "string"
          }
        }
      }
    }
  }
}
```

#### warpgate sessions open

```
Open a terminal on a host in the app

Usage:
  warpgate sessions open [flags] [host]

Arguments:
  host  Host label, id or user@host[:port]

Flags:
      --workspace <NAME>  Workspace to open it in

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate sessions open prod
  warpgate sessions open prod --workspace ops

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
MCP tools: `open_session`.
Palette: `session.new`.

JSON schema `warpgate.sessions.open/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate sessions close

```
Close a terminal session and its pane

Usage:
  warpgate sessions close <session>

Arguments:
  session  Session id. Run warpgate sessions list to see them

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate sessions close 3f2a
  warpgate sessions close 3f2a --yes

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: destructive.
MCP tools: `close_session`.

JSON schema `warpgate.sessions.close/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate sessions focus

```
Bring a session to the front in the app

Usage:
  warpgate sessions focus [session]

Arguments:
  session  Session id. Run warpgate sessions list to see them

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate sessions focus 3f2a
  warpgate sessions focus

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `palette.switcher`.

JSON schema `warpgate.sessions.focus/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate sessions send

```
Type text into a session. Use \r for Enter

Usage:
  warpgate sessions send <session> <text>

Arguments:
  session  Session id. Run warpgate sessions list to see them
  text     Text to type

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate sessions send 3f2a "ls -la\r"
  warpgate sessions send 3f2a "exit\r"

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: destructive.
MCP tools: `send_input`.

JSON schema `warpgate.sessions.send/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate sessions read

```
Print the last lines of a session

Usage:
  warpgate sessions read [flags] <session>

Arguments:
  session  Session id. Run warpgate sessions list to see them

Flags:
  -n, --lines <N>  How many lines. Default: 100

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate sessions read 3f2a
  warpgate sessions read 3f2a --lines 500 > out.txt

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: read.
MCP tools: `read_terminal`.

JSON schema `warpgate.sessions.read/1`:

```json
{
  "type": "object",
  "properties": {
    "session_id": {
      "type": "string"
    },
    "text": {
      "type": "string"
    }
  }
}
```

#### warpgate broadcast

```
Type the same text into several sessions

Usage:
  warpgate broadcast <sessions...> -- <text...>

Arguments:
  sessions  Session ids, then --
  text      Text to type, after --

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate broadcast 3f2a 9c1d -- "uptime\r"
  warpgate broadcast 3f2a 9c1d 77ab -- "exit\r"

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: destructive.

JSON schema `warpgate.broadcast.send/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate broadcast toggle

```
Broadcast typing to all terminals in the active tab

Usage:
  warpgate broadcast toggle

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate broadcast toggle
  warpgate broadcast toggle --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `broadcast.toggle`.

JSON schema `warpgate.broadcast.toggle/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate broadcast stop

```
Stop broadcasting

Usage:
  warpgate broadcast stop

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate broadcast stop
  warpgate broadcast stop --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `broadcast.clear`.

JSON schema `warpgate.broadcast.stop/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate workspaces list

```
List workspaces

Usage:
  warpgate workspaces list

Examples:
  warpgate workspaces list
  warpgate workspaces list --json

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: read.
MCP tools: `list_workspaces`.

JSON schema `warpgate.workspaces.list/1`:

```json
{
  "type": "object",
  "properties": {
    "workspaces": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "active": {
            "type": "boolean"
          },
          "tabs": {
            "type": "integer"
          }
        }
      }
    }
  }
}
```

#### warpgate workspaces open

```
Switch to a workspace in the app

Usage:
  warpgate workspaces open <workspace>

Arguments:
  workspace  Workspace name or id

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate workspaces open ops
  warpgate workspaces open Main

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.

JSON schema `warpgate.workspaces.open/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate workspaces save

```
Save the active tab so it can be opened again

Usage:
  warpgate workspaces save <name>

Arguments:
  name  Name to save it under

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate workspaces save incident
  warpgate workspaces save "web grid"

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.

JSON schema `warpgate.workspaces.save/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate workspaces rm

```
Delete a workspace and close its tabs

Usage:
  warpgate workspaces rm <workspace>

Arguments:
  workspace  Workspace name or id

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate workspaces rm old
  warpgate workspaces rm old --yes

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: destructive.

JSON schema `warpgate.workspaces.rm/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate workspaces new

```
Create a workspace

Usage:
  warpgate workspaces new [name]

Arguments:
  name  Workspace name

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate workspaces new ops
  warpgate workspaces new

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `workspace.new`.

JSON schema `warpgate.workspaces.new/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate workspaces rename

```
Rename the active workspace

Usage:
  warpgate workspaces rename [name]

Arguments:
  name  New name

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate workspaces rename ops
  warpgate workspaces rename

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `workspace.rename`.

JSON schema `warpgate.workspaces.rename/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate workspaces switch

```
Switch to a workspace by position

Usage:
  warpgate workspaces switch <index>

Arguments:
  index  Position, from 1 to 9. One of: 1, 2, 3, 4, 5, 6, 7, 8, 9

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate workspaces switch 1
  warpgate workspaces switch 3

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `workspace.1`, `workspace.2`, `workspace.3`, `workspace.4`, `workspace.5`, `workspace.6`, `workspace.7`, `workspace.8`, `workspace.9`.

JSON schema `warpgate.workspaces.switch/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate layouts list

```
List saved layouts and presets

Usage:
  warpgate layouts list

Examples:
  warpgate layouts list
  warpgate layouts list --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.layouts.list/1`:

```json
{
  "type": "object",
  "properties": {
    "layouts": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string"
          },
          "name": {
            "type": "string"
          },
          "saved_at": {
            "type": "string"
          }
        }
      }
    },
    "presets": {
      "type": "array",
      "items": {
        "type": "string"
      }
    }
  }
}
```

#### warpgate layouts apply

```
Arrange the active tab with a preset, or open a saved layout

Usage:
  warpgate layouts apply [layout]

Arguments:
  layout  Preset or saved layout name

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate layouts apply grid
  warpgate layouts apply incident

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `layout.columns`, `layout.grid`, `layout.mainStack`, `layout.rows`, `layout.open`.

JSON schema `warpgate.layouts.apply/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate layouts save

```
Save the active tab as a layout

Usage:
  warpgate layouts save [name]

Arguments:
  name  Layout name

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate layouts save incident
  warpgate layouts save

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `layout.save`.

JSON schema `warpgate.layouts.save/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate panes split

```
Split the focused pane

Usage:
  warpgate panes split <side>

Arguments:
  side  Where to split. One of: right, down

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate panes split right
  warpgate panes split down

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `pane.splitRight`, `pane.splitDown`.

JSON schema `warpgate.panes.split/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate panes close

```
Close the focused pane

Usage:
  warpgate panes close

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate panes close
  warpgate panes close --yes

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: destructive.
Palette: `pane.close`.

JSON schema `warpgate.panes.close/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate panes maximize

```
Maximize or restore the focused pane

Usage:
  warpgate panes maximize

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate panes maximize
  warpgate panes maximize --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `pane.maximize`.

JSON schema `warpgate.panes.maximize/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate panes focus

```
Move focus to a neighboring pane

Usage:
  warpgate panes focus <direction>

Arguments:
  direction  Direction. One of: left, right, up, down

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate panes focus left
  warpgate panes focus down

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `pane.focusLeft`, `pane.focusRight`, `pane.focusUp`, `pane.focusDown`.

JSON schema `warpgate.panes.focus/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate panes grow

```
Move the divider of the focused pane

Usage:
  warpgate panes grow <direction>

Arguments:
  direction  Direction. One of: left, right, up, down

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate panes grow right
  warpgate panes grow up

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `pane.growLeft`, `pane.growRight`, `pane.growUp`, `pane.growDown`.

JSON schema `warpgate.panes.grow/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate panes swap

```
Swap the focused pane with a neighbor

Usage:
  warpgate panes swap <side>

Arguments:
  side  Neighbor to swap with. One of: right, down

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate panes swap right
  warpgate panes swap down

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `pane.swapRight`, `pane.swapDown`.

JSON schema `warpgate.panes.swap/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate panes to-tab

```
Move the focused pane to a new tab

Usage:
  warpgate panes to-tab

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate panes to-tab
  warpgate panes to-tab --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `pane.toTab`.

JSON schema `warpgate.panes.to-tab/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate tabs next

```
Go to the next tab

Usage:
  warpgate tabs next

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate tabs next
  warpgate tabs next --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `tab.next`.

JSON schema `warpgate.tabs.next/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate tabs previous

```
Go to the previous tab

Usage:
  warpgate tabs previous

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate tabs previous
  warpgate tabs previous --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `tab.previous`.

JSON schema `warpgate.tabs.previous/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate go

```
Show a screen in the app

Usage:
  warpgate go <screen>

Arguments:
  screen  Screen to show. One of: hosts, keys, sessions, transfers, forwards, snippets, multi-exec, settings, activity

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate go transfers
  warpgate go settings

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `multiExec.open`, `nav.hosts`, `nav.keys`, `transfers.open`, `nav.forwards`, `nav.snippets`, `nav.workbench`, `settings.open`, `nav.mcp`.

JSON schema `warpgate.go/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate app palette

```
Open the command palette in the app

Usage:
  warpgate app palette

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate app palette
  warpgate app palette --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `palette.open`.

JSON schema `warpgate.app.palette/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate app sidebar

```
Show or hide the sidebar

Usage:
  warpgate app sidebar

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate app sidebar
  warpgate app sidebar --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `sidebar.toggle`.

JSON schema `warpgate.app.sidebar/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate app lock

```
Lock Warpgate

Usage:
  warpgate app lock

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate app lock
  warpgate app lock --json

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `app.lock`.

JSON schema `warpgate.app.lock/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

#### warpgate app zoom

```
Change the text size of the focused terminal

Usage:
  warpgate app zoom <direction>

Arguments:
  direction  Which way. One of: in, out, reset

Needs the app. Warpgate starts if it is not running.

Examples:
  warpgate app zoom in
  warpgate app zoom reset

Run warpgate --help for flags that work on every command.
```

Needs the app, and starts it if it is not running. Permission: write.
Palette: `terminal.zoomIn`, `terminal.zoomOut`, `terminal.zoomReset`.

JSON schema `warpgate.app.zoom/1`:

```json
{
  "type": "object",
  "properties": {
    "done": {
      "type": "boolean"
    },
    "session_id": {
      "type": "string",
      "nullable": true
    }
  }
}
```

### Settings, backup and Claude Code

#### warpgate settings list

```
List every setting and its value

Usage:
  warpgate settings list

Examples:
  warpgate settings list
  warpgate settings list --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.settings.list/1`:

```json
{
  "type": "object",
  "properties": {
    "settings": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "key": {
            "type": "string"
          },
          "value": {},
          "default": {},
          "type": {
            "type": "string"
          },
          "choices": {
            "type": "array",
            "items": {
              "type": "string"
            }
          }
        }
      }
    }
  }
}
```

#### warpgate settings get

```
Print the value of one setting

Usage:
  warpgate settings get <key>

Arguments:
  key  Setting name

Examples:
  warpgate settings get transferConcurrency
  warpgate settings get accent --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.settings.get/1`:

```json
{
  "type": "object",
  "properties": {
    "key": {
      "type": "string"
    },
    "value": {},
    "default": {},
    "type": {
      "type": "string"
    },
    "choices": {
      "type": "array",
      "items": {
        "type": "string"
      }
    }
  }
}
```

#### warpgate settings set

```
Change one setting

Usage:
  warpgate settings set <key> <value>

Arguments:
  key    Setting name
  value  New value

Examples:
  warpgate settings set transferConcurrency 5
  warpgate settings set themeMode dark

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: write.

JSON schema `warpgate.settings.set/1`:

```json
{
  "type": "object",
  "properties": {
    "key": {
      "type": "string"
    },
    "value": {},
    "default": {},
    "type": {
      "type": "string"
    },
    "choices": {
      "type": "array",
      "items": {
        "type": "string"
      }
    }
  }
}
```

#### warpgate settings reset

```
Reset one setting, or all of them

Usage:
  warpgate settings reset [key]

Arguments:
  key  Setting name. Leave out to reset all

Examples:
  warpgate settings reset accent
  warpgate settings reset --yes

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: destructive.

JSON schema `warpgate.settings.reset/1`:

```json
{
  "type": "object",
  "properties": {
    "reset": {
      "type": "integer"
    }
  }
}
```

#### warpgate backup export

```
Write an encrypted backup. Asks for a passphrase

Usage:
  warpgate backup export [flags] <file>

Arguments:
  file  File to write

Flags:
      --with-secrets      Include private keys and passwords
      --passphrase-stdin  Read the passphrase from stdin

Examples:
  warpgate backup export ~/warpgate.backup
  warpgate backup export ~/full.backup --with-secrets

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.backup.export/1`:

```json
{
  "type": "object",
  "properties": {
    "file": {
      "type": "string"
    },
    "with_secrets": {
      "type": "boolean"
    }
  }
}
```

#### warpgate backup import

```
Restore an encrypted backup. Asks for the passphrase

Usage:
  warpgate backup import [flags] <file>

Arguments:
  file  Backup file

Flags:
      --passphrase-stdin  Read the passphrase from stdin

Examples:
  warpgate backup import ~/warpgate.backup
  warpgate backup import ~/warpgate.backup --yes --passphrase-stdin < pass.txt

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: destructive.

JSON schema `warpgate.backup.import/1`:

```json
{
  "type": "object",
  "properties": {
    "hosts": {
      "type": "integer"
    },
    "keys": {
      "type": "integer"
    },
    "snippets": {
      "type": "integer"
    }
  }
}
```

#### warpgate mcp serve

```
Run a stdio MCP server for Claude Code

Usage:
  warpgate mcp serve

Examples:
  warpgate mcp serve
  claude mcp add warpgate -- warpgate mcp serve

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.

#### warpgate mcp status

```
Show whether Claude Code access is on

Usage:
  warpgate mcp status

Examples:
  warpgate mcp status
  warpgate mcp status --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.mcp.status/1`:

```json
{
  "type": "object",
  "properties": {
    "state": {
      "type": "string"
    },
    "enabled": {
      "type": "boolean"
    },
    "port": {
      "type": "integer"
    },
    "allowed": {
      "type": "integer"
    },
    "tools": {
      "type": "integer"
    }
  }
}
```

#### warpgate mcp token show

```
Print the Claude Code access token. Asks first

Usage:
  warpgate mcp token show

Examples:
  warpgate mcp token show
  warpgate mcp token show --yes

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: destructive.

JSON schema `warpgate.mcp.token.show/1`:

```json
{
  "type": "object",
  "properties": {
    "token": {
      "type": "string"
    }
  }
}
```

#### warpgate mcp token rotate

```
Replace the Claude Code access token

Usage:
  warpgate mcp token rotate

Examples:
  warpgate mcp token rotate
  warpgate mcp token rotate --yes

Run warpgate --help for flags that work on every command.
```

Goes through the app when it is running, otherwise writes the database directly. Permission: destructive.

JSON schema `warpgate.mcp.token.rotate/1`:

```json
{
  "type": "object",
  "properties": {
    "rotated": {
      "type": "boolean"
    }
  }
}
```

#### warpgate mcp install

```
Print the claude mcp add command, or run it

Usage:
  warpgate mcp install [flags]

Flags:
      --run  Run the command instead of printing it

Examples:
  warpgate mcp install
  warpgate mcp install --run

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.

JSON schema `warpgate.mcp.install/1`:

```json
{
  "type": "object",
  "properties": {
    "command": {
      "type": "string"
    },
    "ran": {
      "type": "boolean"
    }
  }
}
```

### Setup

#### warpgate completion

```
Print a completion script for your shell

Usage:
  warpgate completion <shell>

Arguments:
  shell  Shell. One of: bash, zsh, fish, powershell

Examples:
  warpgate completion zsh > ~/.zfunc/_warpgate
  source <(warpgate completion bash)

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.completion/1`:

```json
{
  "type": "object",
  "properties": {
    "script": {
      "type": "string"
    }
  }
}
```

#### warpgate doctor

```
Check the install, PATH, secure storage, app and ssh-agent

Usage:
  warpgate doctor

Examples:
  warpgate doctor
  warpgate doctor --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.doctor/1`:

```json
{
  "type": "object",
  "properties": {
    "checks": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          },
          "ok": {
            "type": "boolean"
          },
          "detail": {
            "type": "string"
          },
          "fix": {
            "type": "string",
            "nullable": true
          }
        }
      }
    },
    "ok": {
      "type": "boolean"
    }
  }
}
```

#### warpgate version

```
Print the version

Usage:
  warpgate version

Examples:
  warpgate version
  warpgate version --json

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.version/1`:

```json
{
  "type": "object",
  "properties": {
    "version": {
      "type": "string"
    },
    "schema_version": {
      "type": "integer"
    }
  }
}
```

#### warpgate help

```
Show help for a command

Usage:
  warpgate help [command...]

Arguments:
  command  Command

Examples:
  warpgate help
  warpgate help cp
  warpgate help hosts add

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: read.

JSON schema `warpgate.help/1`:

```json
{
  "type": "object",
  "properties": {
    "help": {
      "type": "string"
    }
  }
}
```

#### warpgate install

```
Add warpgate to your PATH

Usage:
  warpgate install

Examples:
  warpgate-cli --install
  warpgate install

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: write.

JSON schema `warpgate.install/1`:

```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string"
    },
    "needs_new_shell": {
      "type": "boolean"
    }
  }
}
```

#### warpgate uninstall

```
Remove warpgate from your PATH

Usage:
  warpgate uninstall

Examples:
  warpgate uninstall
  warpgate uninstall --yes

Run warpgate --help for flags that work on every command.
```

Runs in the command. No app needed. Permission: destructive.

JSON schema `warpgate.uninstall/1`:

```json
{
  "type": "object",
  "properties": {
    "removed": {
      "type": "boolean"
    }
  }
}
```

## Scripting examples

Restart a service on a group, one host at a time, and stop at the first failure:

```sh
warpgate exec @web --stop-on-failure -- sudo systemctl restart nginx
```

Check which hosts failed:

```sh
warpgate exec @web --json -- systemctl is-active nginx \
  | jq -r '.results[] | select(.exit_code != 0) | .host'
```

Copy the latest backup from prod to staging, directly when staging can be reached from prod:

```sh
latest=$(warpgate exec prod -- ls -1t /var/backups | head -n 1)
warpgate cp --verify "prod:/var/backups/$latest" staging:/tmp/
warpgate cp --direct "prod:/var/backups/$latest" staging:/tmp/
```

Open a 2x2 layout of four hosts in the app:

```sh
warpgate open web-1
warpgate open web-2 --split right
warpgate open web-3 --split right
warpgate open web-4 --split right
warpgate layouts apply grid
```

Add a host from a script, with the password on stdin so it stays out of your shell history:

```sh
printf %s "$PW" | warpgate hosts add lab me@lab --auth password --password-stdin
```

Tell apart what went wrong:

```sh
warpgate exec prod -- true
case $? in
  0) echo fine ;;
  4) echo "credentials rejected" ;;
  5) echo "host key not trusted" ;;
  6) echo "could not connect" ;;
esac
```
