{
  pkgs,
  ...
}:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [
    pkgs.ghcid
    pkgs.git
    pkgs.gitleaks
    pkgs.pre-commit
    pkgs.rubyPackages.solargraph
    # Provides 'zlib.h', which is required by the Haskell 'req' package via the 'zlib' library dependency.
    # Without this, 'stack build' fails with: "fatal error: 'zlib.h' file not found".
    pkgs.zlib
  ];

  # https://devenv.sh/languages/
  # languages.rust.enable = true;

  # https://devenv.sh/processes/
  # processes.dev.exec = "${lib.getExe pkgs.watchexec} -n -- ls -la";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  scripts.download.exec = ''
    wget https://raw.githubusercontent.com/8ta4/prevalence-data/c79fd1ee936a5b05ad4fecc99b5232d2b9f14b4d/wiktionary.tsv
  '';
  scripts.hello.exec = ''
    echo hello from $GREET
  '';
  scripts.watch.exec = ''
    ghcid -a \
    -c 'stack ghci --ghci-options "-ghci-script ghcid.ghci" --no-load' \
    --no-height-limit \
    -r \
    -s ":set args fat.yaml" \
    -s ':set -Wprepositive-qualified-module' \
    -W
  '';

  # https://devenv.sh/basics/
  enterShell = ''
    hello         # Run scripts directly
    git --version # Use packages
    brew bundle
    export PATH="$HOME/.ghcup/bin:$PATH"
    ghcup install stack 3.11.1
    ghcup install hls 2.14.0.0
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;
  git-hooks.hooks = {
    end-of-file-fixer.enable = true;
    gitleaks = {
      enable = true;
      # https://github.com/gitleaks/gitleaks/blob/4c232b5014f7618360bd992b4c489cb055881c6b/.pre-commit-hooks.yaml#L4
      # Direct execution of gitleaks here results in '[git] fatal: cannot change to 'devenv.nix': Not a directory'.
      entry = "bash -c 'exec gitleaks git --redact --staged --verbose'";
    };
    # https://github.com/NixOS/nixfmt/blob/7cad8663932db4519d4c5b623becdcda655cef7c/README.md?plain=1#L165
    nixfmt.enable = true;
    ormolu.enable = true;
    prettier.enable = true;
    trim-trailing-whitespace.enable = true;
  };

  # See full reference at https://devenv.sh/reference/options/
}
