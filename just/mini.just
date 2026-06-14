# Mini host management — invoked as `just mini <cmd>` from any host that can
# `ssh mini`. Service ops live in the nested `llm` module (`just mini llm <cmd>`).
# Commit + push your flake changes first; deploy/pull pull origin/main on mini and
# build there. Override the target off-LAN with MINI_SSH=mini.quokka-qilin.ts.net.
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

mod llm "mini-llm.just"

mini_ssh := env('MINI_SSH', 'mini')

[doc('git pull --ff-only the flake on mini (no build)')]
pull:
    ssh {{mini_ssh}} 'bash -lc "git -C ~/.dotfiles/flake pull --ff-only"'

[doc('Pull newest flake on mini, then nh switch')]
deploy:
    ssh -t {{mini_ssh}} 'bash -lc "set -e; cd ~/.dotfiles/flake && git pull --ff-only && just switch-fast"'

[doc('Pull newest flake on mini, then build-dry (no activation)')]
deploy-dry:
    ssh -t {{mini_ssh}} 'bash -lc "set -e; cd ~/.dotfiles/flake && git pull --ff-only && just build-dry"'

[doc('Pull newest flake on mini, stage for next reboot')]
deploy-boot:
    ssh -t {{mini_ssh}} 'bash -lc "set -e; cd ~/.dotfiles/flake && git pull --ff-only && just build-boot"'

[doc('Open an interactive ssh shell on mini')]
ssh:
    ssh -t {{mini_ssh}}

[doc('Reboot mini (e.g. after deploy-boot)')]
reboot:
    ssh {{mini_ssh}} 'bash -lc "sudo systemctl reboot"'
