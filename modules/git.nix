# git, gh and gpg. Ported from dot_gitconfig.tmpl, dot_gitignore,
# dot_gitattributes, dot_config/gh/private_config.yml and
# private_dot_gnupg/gpg.conf.
{ lib, pkgs, ... }:
{
  programs.git = {
    enable = true;

    # Written to ~/.config/git/ignore and ~/.config/git/attributes, which git
    # reads by default, so core.excludesfile/attributesfile are not needed.
    ignores = [
      ".ropeproject/"
      "*.bak"
      ".DS_Store"
      ".gdb_history"
      ".env"
      ""
      "**/.claude/settings.local.json"
      ""
      "**/.claude/.cc-writes/"
    ];
    attributes = [
      "* text=auto"
      ""
      "*.pdf   binary"
      "*.png   binary"
      "*.jpe?g binary"
      "*.gif   binary"
      "*.eps   binary"
      ""
      "*.c     text diff=cpp"
      "*.h     text diff=cpp"
      "*.cpp   text diff=cpp"
      "*.hpp   text diff=cpp"
      ""
      "*.md    text diff=markdown"
      ""
      "*.tex   text diff=tex"
      "*.bib   text diff=bibtex"
      ""
      "*.py    text diff=python"
      ""
      "*.rb    text diff=ruby"
      ""
      "*.rs    text diff=rust"
      ""
      "*.sh    text diff=bash"
      "*.zsh   text diff=bash"
    ];

    settings = {
      user = {
        name = "Thom Wiggers";
        email = "thom@thomwiggers.nl";
        signingkey = "4871E82F";
      };
      alias = {
        br = "branch";
        ci = "commit";
        co = "checkout";
        df = "diff";
        g = "grep -I";
        smp = "submodule -q foreach git pull -q origin master";
        st = "status";
        count = "!git shortlog -sn";
        tree = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
        branch-name = "!git rev-parse --abbrev-ref HEAD";
        publish = "!git push -u origin $(git branch-name)";
      };
      color = {
        diff = "auto";
        status = "auto";
        branch = "auto";
        ui = "auto";
      };
      "color \"branch\"" = {
        current = "yellow reverse";
        local = "yellow";
        remote = "green";
      };
      "color \"diff\"" = {
        meta = "yellow bold";
        frag = "magenta bold";
        old = "red bold";
        new = "green bold";
      };
      "color \"status\"" = {
        added = "yellow";
        changed = "green";
        untracked = "cyan";
      };
      core = {
        editor = "vim";
        eol = "lf";
        autocrlf = false;
        whitespace = "trailing-space";
        pager = "delta";
      };
      apply.whitespace = "fix";
      mergetool.keepBackup = false;
      # log fixed conflicts
      rerere.enabled = true;
      help.autocorrect = 1;
      diff.colorMoved = "default";
      "diff \"exif\"".textconv = "exiftool";
      github.user = "thomwiggers";
      push = {
        default = "simple";
        autoSetupRemote = true;
      };
      merge = {
        tool = "vimdiff";
        conflictstyle = "diff3";
      };
      commit.gpgsign = false;
      transfer.fsckobjects = true;
      fetch.fsckobjects = true;
      receive.fsckobjects = true;
      branch.autoSetupRebase = "local";
      pull = {
        ff = "only";
        rebase = true;
      };
      rebase = {
        missingCommitsCheck = "error";
        autoStash = true;
      };
      submodule = {
        fetchJobs = 0;
        recurse = true;
      };
      interactive.diffFilter = "delta --color-only";
      delta = {
        syntax-theme = "Visual Studio Dark+";
        navigate = true;
        features = "line-numbers";
        hyperlinks = true;
      };
      init.defaultBranch = "main";
    };
  };

  # Configured through programs.git.settings above (core.pager) so delta pages
  # every git command, as before, rather than the module's per-command pagers.
  home.packages = [ pkgs.delta ];

  programs.gh = {
    enable = true;
    # Adds `credential "https://github.com"` / gist helpers to git config.
    gitCredentialHelper.enable = true;
    settings = {
      # What protocol to use when performing git operations. Supported values: ssh, https
      git_protocol = "https";
      # What editor gh should run when creating issues, pull requests, etc. If blank, will refer to environment.
      editor = "";
      # When to interactively prompt. This is a global config that cannot be overridden by hostname. Supported values: enabled, disabled
      prompt = "enabled";
      # A pager program to send command output to, e.g. "less". Set the value to "cat" to disable the pager.
      pager = "";
      # Aliases allow you to create nicknames for gh commands
      aliases = {
        co = "pr checkout";
        localmerge = ''!gh pr checkout $1 && branch=`git branch --show-current` && git switch main && git merge --no-ff - && git branch -d "$branch"'';
      };
      # The path to a unix socket through which send HTTP connections. If blank, HTTP traffic will be handled by net/http.DefaultTransport.
      http_unix_socket = "";
      # What web browser gh should use when opening URLs. If blank, will refer to environment.
      browser = "";
    };
  };

  # Riseup OpenPGP best practices
  # https://help.riseup.net/en/security/message-security/openpgp/best-practices
  programs.gpg = {
    enable = true;
    # Keyrings and trustdb stay as they are; only gpg.conf is managed.
    mutableKeys = true;
    mutableTrust = true;
    # mkForce drops the module's own defaults (s2k-*, no-symkey-cache, ...),
    # which the old gpg.conf did not set.
    settings = lib.mkForce {
      # The default key to sign with.
      default-key = "915D4ED34871E82F";

      # behavior
      utf8-strings = true;
      no-emit-version = true;
      no-comments = true;
      keyid-format = "0xlong";
      with-fingerprint = true;
      list-options = "show-uid-validity";
      verify-options = "show-uid-validity";
      use-agent = true;

      # keyserver
      keyserver-options = [
        "no-honor-keyserver-url"
        "include-revoked"
        "no-auto-key-retrieve"
      ];

      # algorithm and ciphers
      personal-cipher-preferences = "AES256 AES192 AES CAST5";
      personal-digest-preferences = "SHA256 SHA512 SHA384 SHA224";
      cert-digest-algo = "SHA256";
      default-preference-list = "SHA256 SHA512 SHA384 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed";

      # Options
      ask-cert-level = true;
      default-cert-level = "3";
    };
  };
}
