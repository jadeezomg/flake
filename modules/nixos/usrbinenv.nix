# Override the default usrbinenv activation to use `mv -f` so it never prompts
# when /usr/bin/env already exists (e.g. on CachyOS or when re-running activation).
# Upstream uses `mv` without -f, which can ask "replace ... overriding mode?"
# and fail non-interactively.
{
  config,
  lib,
  ...
}: {
  config.system.activationScripts.usrbinenv = lib.mkForce (
    if config.environment.usrbinenv != null
    then ''
      mkdir -p /usr/bin
      chmod 0755 /usr/bin
      ln -sfn ${config.environment.usrbinenv} /usr/bin/.env.tmp
      mv -f /usr/bin/.env.tmp /usr/bin/env
    ''
    else ''
      rm -f /usr/bin/env
      if test -d /usr/bin; then rmdir --ignore-fail-on-non-empty /usr/bin; fi
      if test -d /usr; then rmdir --ignore-fail-on-non-empty /usr; fi
    ''
  );
}
