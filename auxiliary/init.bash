# [from $NH_FLAKE/auxiliary/init.bash]

bash-init-test()
{
	init=$NH_FLAKE/auxiliary/init.bash

	# shellcheck disable=1090
	bash-lint "$init" && source "$init"
}

bash-lint()
{
	shellcheck "$@" && shfmt --binary-next-line --case-indent --func-next-line --list --simplify --space-redirects --write "$@"
}

gh-clone()
{
	gh s "$@" | rg --only-matching '[^/]+/[^/]+$' | xargs gh repo clone
}

headphones()
(
	mac=/run/secrets/the_executive_mac
	until [[ -r $mac ]]; do
		{
			bat --plain <<- EOF
				\`$mac\` is not readable
				regenerate it with \`nh os\` or \`nixos-rebuild\`
				should the funciton be terminated, press \`y\`
			EOF

			read -rn 1 && echo && [[ $REPLY == y ]] && return 1
		}
	done

	set -x

	until rfkill unblock bluetooth \
		&& bluetoothctl connect "$(< $mac)"; do # https://stackoverflow.com/questions/4227994/how-do-i-use-the-lines-of-a-file-as-arguments-of-a-command
		{
			switch_exit=$?

			bat --plain <<- EOF
				last command terminated with exit code $switch_exit
				should the funciton be terminated, press \`y\`
			EOF

			read -rn 1 && echo && [[ $REPLY == y ]] && return $switch_exit
		}
	done

	return 0
)

help()
{
	(
		set -x

		command help "$@" # 2> /dev/null

		if rg --quiet --word-regexp 'help|-h' <<< "$@"; then
			"$@"
		else
			"$@" --help
		fi
	) |& bat --number --language help
}

nix-config()
{
	nix config show | print-config --language nix
}

nixos-repl()
{
	nixos-rebuild repl --flake "$NH_FLAKE"
}

nixos-update()
(
	set -x

	cd "$NH_FLAKE" && until nmcli device wifi show && for nix_tree in ../*; do
		{
			nix flake update --flake "path:$(realpath "$nix_tree")"
			nix fmt -- "$nix_tree"/*.nix
		}
	done && batdiff --delta && nh os switch --verbose; do
		{
			switch_exit=$?

			bat --plain <<- EOF
				last command terminated with exit code $switch_exit
				see \`$NH_FLAKE/auxiliary/nixos-suggestion.md\` for suggestions
				should the funciton be terminated, press \`y\`
			EOF

			read -rn 1 && echo && [[ $REPLY == y ]] && return $switch_exit
		}
	done && return
)

path()
{
	paths=$(command printenv PATH | tr : '\n')

	bat --number --language url <<< "$paths"
	xargs --interactive -- ov --exec -- ls -l --almost-all --color --dereference --human-readable <<< "$paths"
}

print-config()
{
	BAT_PAGER="ov --align --column-mode --column-delimiter ' = '" bat --number "$@"
}

printenv()
{
	(($#)) && IFS='|' && local filter="/$*/"

	export -p | sed --quiet --regexp-extended "${filter}s/.+\s(.+)=(\".+)/\1 = \2/p" | sort | print-config --language env
}

todo()
{
	batgrep --case-sensitive '#\sTODO' "$@"
}

shell=$(basename "$SHELL")
for cmd in "berg completion" "warp-cli generate-completions"; do eval "$($cmd "$shell")"; done

complete -F _command help # https://stackoverflow.com/questions/35353719/is-it-possible-to-copy-the-tab-completion-of-a-command-for-my-linux-function
set -o vi

nmcli device wifi show && gh notify
taoup | rg --invert-match ^- | shuf --head-count 1 | cowsay -nf flaming-sheep | rg --invert-match '^\s[-_]*$' | lolcat
