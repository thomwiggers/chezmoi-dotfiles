# Claude Code. ~/.claude.json and ~/.claude/settings.json are rewritten by
# Claude Code itself, so they can't be store symlinks. As with the old chezmoi
# modify_ scripts, shared defaults are merged into whatever is there at
# activation time, without clobbering machine-local state.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.thom.claude;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  jq = lib.getExe pkgs.jq;

  # stdin: current file (may be empty); stdout: merged file.
  jsonMerge = pkgs.writeShellScript "claude-json-merge" ''
    set -euo pipefail

    input=$(cat)
    if [ -z "$input" ]; then
      input='{}'
    fi

    defaults='{
      "prStatusFooterEnabled": true,
      "workflowSizeGuideline": "small",
      "hasSeenAutoModeEntryWarning": true,
      "hasOpenedAgentsView": true
    }'

    printf '%s\n' "$input" | ${jq} --argjson defaults "$defaults" '
      . * $defaults
    '
  '';

  # Nix: the client talks to nix-daemon over its Unix socket. macOS can allow
  # just that socket; on Linux the seccomp filter is all-or-nothing, so every
  # Unix socket is opened. ~/.cache/nix holds the eval/fetcher caches; /nix
  # is only writable for single-user installs (nix-user-chroot, containers),
  # where Unix permissions don't already stop it.
  #
  # Python: uv/uvx and pip caches; ~/.local/share/uv holds uv-managed Pythons and
  # tools. pip uses ~/Library/Caches/pip on macOS.
  nixSocket =
    if isDarwin then
      ''"allowUnixSockets": ["/nix/var/nix/daemon-socket/socket"],''
    else
      ''"allowAllUnixSockets": true,'';

  # bubblewrap can't mount a fresh /proc inside unprivileged containers
  # (lxcfs overmounts it under LXC/Incus; Docker and Podman mask parts of
  # it), so reuse the container's /proc there. Set per host (thom.container).
  # The chezmoi-era key path stays denied: bootstrap.sh copies the identity
  # from there, and the old copy lingers until chezmoi is purged.
  settingsMerge = pkgs.writeShellScript "claude-settings-merge" ''
    set -euo pipefail

    input=$(cat)
    if [ -z "$input" ]; then
      input='{}'
    fi

    defaults='{
      "permissions": {
        "defaultMode": ${builtins.toJSON cfg.defaultMode}
      },
      "enabledPlugins": {
        "superpowers@claude-plugins-official": true,
        "claude-md-management@claude-plugins-official": true,
        "claude-code-setup@claude-plugins-official": true,
        "pyright-lsp@claude-plugins-official": true,
        "cc-plugin-you-should-know@builtin": true
      },
      "enableWorkflows": true,
      "sandbox": {
        "enabled": true,
        "failIfUnavailable": true,
        "enableWeakerNestedSandbox": ${lib.boolToString config.thom.container},
        "excludedCommands": [
          "git fetch", "git fetch *",
          "git pull", "git pull *",
          "git push", "git push *",
          "git clone *",
          "git ls-remote *",
          "git submodule update *",
          "gh", "gh *"
        ],
        "credentials": {
          "files": [
            { "path": "~/.ssh", "mode": "deny" },
            { "path": "~/.gnupg", "mode": "deny" },
            { "path": "~/.config/chezmoi/key.txt", "mode": "deny" },
            { "path": ${
              builtins.toJSON (lib.replaceStrings [ config.home.homeDirectory ] [ "~" ] config.thom.age.identity)
            }, "mode": "deny" },
            { "path": "~/.config/gh/hosts.yml", "mode": "deny" }${lib.optionalString isDarwin ''
              ,
                          { "path": "~/Library/Keychains", "mode": "deny" }''}
          ],
          "envVars": [
            { "name": "GH_TOKEN", "mode": "mask", "injectHosts": ["api.github.com", "github.com", "uploads.github.com"] },
            { "name": "GITHUB_TOKEN", "mode": "mask", "injectHosts": ["api.github.com", "github.com", "uploads.github.com"] },
            { "name": "GH_ENTERPRISE_TOKEN", "mode": "deny" },
            { "name": "GITHUB_ENTERPRISE_TOKEN", "mode": "deny" },
            { "name": "GITLAB_TOKEN", "mode": "deny" },
            { "name": "ANTHROPIC_API_KEY", "mode": "deny" },
            { "name": "OPENAI_API_KEY", "mode": "deny" },
            { "name": "HF_TOKEN", "mode": "deny" },
            { "name": "AWS_ACCESS_KEY_ID", "mode": "deny" },
            { "name": "AWS_SECRET_ACCESS_KEY", "mode": "deny" },
            { "name": "AWS_SESSION_TOKEN", "mode": "deny" },
            { "name": "NPM_TOKEN", "mode": "deny" },
            { "name": "UV_PUBLISH_TOKEN", "mode": "deny" },
            { "name": "TWINE_PASSWORD", "mode": "deny" },
            { "name": "CARGO_REGISTRY_TOKEN", "mode": "deny" }
          ]
        },
        "network": {
          ${nixSocket}
          "tlsTerminate": {},
          "allowedDomains": ["*", "api.github.com", "github.com", "uploads.github.com"]
        },
        "filesystem": {
          "allowRead": [
            "~/.gitattributes",
            "~/.gitconfig",
            "~/.gitignore",
            "~/.config/git",
            ${builtins.toJSON cfg.dotfilesDir}
          ],
          "allowWrite": [
            ${builtins.toJSON cfg.dotfilesDir},
            "~/.cache/nix",
            "~/.cache/uv",
            "~/.local/share/uv",
            "~/.cache/pip",${lib.optionalString isDarwin ''"~/Library/Caches/pip",''}
            "/nix"
          ]
        }
      },
      "outputStyle": "concise",
      "remoteControlAtStartup": true,
      "agentPushNotifEnabled": true,
      "theme": "auto",
      "tui": "fullscreen",
      "skipDangerousModePermissionPrompt": true
    }'

    allow='[
      "Bash(git add:*)",
      "Bash(git log:*)",
      "Bash(git status:*)"
    ]'

    # The Xcode command-line-tool shims (/usr/bin/python3, /usr/bin/git, /usr/bin/make)
    # write a lookup cache into the per-user temp dir; without write access there they
    # print a warning on every invocation before handing off to the real binary.
    # The path is derived from the account UUID, so resolve it at activation time
    # instead of hardcoding it. Both /var/... and its /private/... realpath are listed
    # because the sandbox matches on the resolved path.
    sandbox_write='[]'
    ${lib.optionalString isDarwin ''
      user_tmp="$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)"
      user_tmp="''${user_tmp%/}"
      if [ -n "$user_tmp" ]; then
        sandbox_write=$(${jq} -n --arg t "$user_tmp" '
          [$t] + (if ($t | startswith("/var/")) then ["/private" + $t] else [] end)
        ')
      fi
    ''}
    # macOS keychain CLI; the sandbox can't block keychain access via securityd.
    # gh runs outside the sandbox (excludedCommands) so it can read its token
    # from ~/.config/gh/hosts.yml or the keychain, which the sandbox denies.
    # Block the subcommands that print the token or run arbitrary code there.
    deny='[
      "Bash(security:*)",
      "Bash(/usr/bin/security:*)",
      "Bash(gh auth:*)",
      "Bash(gh config:*)",
      "Bash(gh alias:*)",
      "Bash(gh extension:*)",
      "Bash(gh ext:*)",
      "Read(~/.config/gh/hosts.yml)"
    ]'

    printf '%s\n' "$input" | ${jq} \
      --argjson defaults "$defaults" \
      --argjson allow "$allow" \
      --argjson deny "$deny" \
      --argjson sandbox_write "$sandbox_write" '
      . * $defaults
      # Older versions of this template wrote these to the wrong level; the
      # sandbox only reads sandbox.filesystem.allowRead/allowWrite.
      | del(.sandbox.allowRead, .sandbox.allowWrite)
      # Caveman plugin was previously enabled by this template; remove it.
      | del(.enabledPlugins["caveman@caveman"], .extraKnownMarketplaces.caveman)
      | .permissions.allow = (((.permissions.allow // []) + $allow) | unique)
      | if ($sandbox_write | length) > 0
        then .sandbox.filesystem.allowWrite = (((.sandbox.filesystem.allowWrite // []) + $sandbox_write) | unique)
        else . end
      | .permissions.deny = (((.permissions.deny // []) + $deny) | unique)
    '
  '';
in
{
  options.thom.claude = {
    dotfilesDir = lib.mkOption {
      type = lib.types.str;
      default = "~/.config/home-manager";
      description = ''
        Checkout of this repository, which Claude Code's sandbox may read and
        write. bootstrap.sh clones it here, where home-manager looks by
        default.
      '';
    };
    jsonMerge = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = jsonMerge;
      description = "Merge filter for ~/.claude.json (stdin to stdout); used by verify.sh.";
    };
    settingsMerge = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = settingsMerge;
      description = "Merge filter for ~/.claude/settings.json (stdin to stdout); used by verify.sh.";
    };
  };

  config.home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    thomMergeJson() {
      local target="$1" filter="$2" tmp
      if [[ -v DRY_RUN ]]; then
        echo "would merge Claude Code defaults into $target"
        return
      fi
      mkdir -p "$(dirname "$target")"
      tmp=$(umask 077 && mktemp "$target.XXXXXX")
      if "$filter" < <(cat "$target" 2>/dev/null || true) > "$tmp"; then
        chmod 600 "$tmp"
        mv -f "$tmp" "$target"
      else
        rm -f "$tmp"
        errorEcho "Failed to merge Claude Code defaults into $target"
      fi
    }
    thomMergeJson "$HOME/.claude.json" ${jsonMerge}
    thomMergeJson "$HOME/.claude/settings.json" ${settingsMerge}
    unset -f thomMergeJson
  '';
}
