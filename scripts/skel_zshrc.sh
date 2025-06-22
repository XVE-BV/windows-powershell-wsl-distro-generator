# /etc/skel/.zshrc

# Show XVE logo on login
echo "____  _______   _______________"
echo "\   \/  /\   \ /   /\_   _____/"
echo " \     /  \   Y   /  |    __)_ "
echo " /     \   \     /   |        \\"
echo "/___/\  \   \___/   /_______  /"
echo "      \_/                   \/ "
echo ""

# Jump straight into /apps on interactive shells
if [[ -o interactive && $(id -u) -ne 0 ]]; then
  cd /apps
fi

# Make nano the default editor
export VISUAL=nano
export EDITOR="$VISUAL"

# Laravel Sail function and shortcuts
sail() {
  if [ -f ./vendor/bin/sail ]; then
    zsh ./vendor/bin/sail "$@"
  else
    echo "❌ vendor/bin/sail not found"
  fi
}
alias s='sail '
alias sa='sail artisan '
alias sc='sail composer '
alias sm='sa migrate'
alias smf='sa migrate:fresh'
alias smfs='sa migrate:fresh --seed'
alias sus='s up -d'
alias sdown='s stop'

# Powerlevel10k instant prompt (if installed)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
source /opt/powerlevel10k/powerlevel10k.zsh-theme
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
