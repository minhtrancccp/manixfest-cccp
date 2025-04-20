{
  config,
  lib,
  pkgs,

  admin,
  hostPlatform,

  flakeDefaultPackage,
  genericMapAttrs,
  quickGenAttrs,
  quickMapAttrs,

  inputs,
  ...
}:
let
  inherit (lib)
    attrsets
    meta
    modules
    trivial
    ;
  inherit (pkgs) firefox-addons;

  browserDesktopEntryRoots = [ "firefox-nightly" ];
  gitPath = meta.getExe pkgs.git;

  falseGenAttrs = quickGenAttrs false;
  trueGenAttrs = quickGenAttrs true;

  deepMergeAttrs =
    /*
      https://discourse.nixos.org/t/nix-function-to-merge-attributes-records-recursively-and-concatenate-arrays/2030
      https://stackoverflow.com/questions/54504685/nix-function-to-merge-attributes-records-recursively-and-concatenate-arrays
    */
    (
      values:
      if lib.length values == 1 then
        lib.head values
      else if lib.all lib.isList values then
        values |> lib.concatLists |> lib.lists.unique
      else if lib.all lib.isAttrs values then
        deepMergeAttrs values
      else
        lib.lists.last values
    )
    |> trivial.const
    |> lib.zipAttrsWith;

  extendFirefoxProfile =
    extraProfileConfig:
    modules.mkMerge [
      extraProfileConfig

      {
        extensions.packages = lib.attrValues {
          inherit (firefox-addons)
            darkreader
            proton-vpn
            re-enable-right-click
            tunnelbear-vpn-firefox
            ublock-origin
            ;
        };

        search.force = true;
        search.engines = {
          bing.metaData.hidden = true;

          ddg.metaData.hidden = true;

          wikipedia.metaData.alias = "@wk";
        };

        settings = # https://wiki.archlinux.org/title/Firefox
          modules.mkMerge [
            { "intl.accept_languages" = "en-gb"; }

            (falseGenAttrs [
              "browser.download.useDownloadDir"
              "browser.newtabpage.activity-stream.feeds.section.topstories"
              "browser.newtabpage.activity-stream.showSearch"
              "browser.newtabpage.activity-stream.showSponsoredTopSites"
              "browser.shell.checkDefaultBrowser"
              "browser.urlbar.showSearchSuggestionsFirst"
              "browser.urlbar.suggest.trending"

              "extensions.formautofill.addresses.enabled"
              "extensions.formautofill.creditCards.enabled"
              "extensions.pocket.enabled"

              "signon.rememberSignons"
            ])

            (trueGenAttrs [
              "browser.crashReports.unsubmittedCheck.autoSubmit2"
              "browser.tabs.haveShownCloseAllDuplicateTabsWarning"
              "browser.tabs.insertAfterCurrent"

              "findbar.highlightAll"

              "general.autoScroll"

              "intl.regional_prefs.use_os_locales"

              "media.videocontrols.picture-in-picture.video-toggle.has-used"

              "privacy.donottrackheader.enabled"
              "privacy.globalprivacycontrol.enabled"
            ])

            (
              [
                "file-picker"
                "location"
                "mime-handler"
                "open-uri"
                "settings"
              ]
              |> lib.map (option: "widget.use-xdg-desktop-portal.${option}")
              |> quickGenAttrs 1
            )
          ];
      }
    ];

  toYAML =
    /*
      https://github.com/NixOS/nixpkgs/blob/2631b0b7abcea6e640ce31cd78ea58910d31e650/pkgs/pkgs-lib/formats.nix#L110-L124
      https://kokada.dev/blog/generating-yaml-files-with-nix/
    */
    data:
    pkgs.runCommandLocal "toYAML"
      {
        json = builtins.toJSON data;
        nativeBuildInputs = lib.attrValues { inherit (pkgs) yamllint yq-go; };
        # passAsFile = [ "json" ]; # https://nix.dev/manual/nix/latest/language/advanced-attributes#adv-attr-passAsFile
      }
      ''
        yq --prettyPrint <<< "$json" > "$out"

        yamllint --config-data relaxed -- "$out" # https://yamllint.readthedocs.io/en/v1.37.0/configuration.html#default-configuration
      '';
in
{
  home = {
    editor = "vim";
    homeDirectory = "/home/${admin}";
    packages =
      lib.attrValues {
        inherit (pkgs)
          cbonsai
          cowsay
          cyberchef
          desed
          dmidecode
          element-desktop
          ffmpeg
          file
          gettext
          ghorg
          github-desktop
          glab
          hut
          hyperfine
          inetutils
          lolcat
          lsb-release
          markdownlint-cli2
          marktext
          mozlz4a
          nix-derivation
          play
          protonvpn-gui
          pup
          quick-lookup
          shellcheck
          sherlock
          shfmt
          showmethekey
          sl
          sops
          sqlitebrowser
          stremio
          taoup
          tokei
          tor-browser
          trash-cli
          unrar
          usbimager
          vhs
          vieb
          vlc
          wikiman
          wl-clipboard-rs
          yamllint
          yq-go
          ;
        inherit (pkgs.kdePackages)
          filelight
          kleopatra
          kmines
          konversation
          kweather
          ;
        inherit (inputs.codeberg-cli.packages.${hostPlatform}) codeberg-cli-dev;
      }
      ++ (
        {
          inherit (inputs)
            handlr-regex
            nix-converter
            nix-inspect
            nix-tree
            nixfmt
            nixpkgs-review
            plasma-manager
            statix
            xdg-ninja
            ;
        }
        |> lib.attrValues
        |> lib.map flakeDefaultPackage
      );
    preferXdgDirectories = true;
    stateVersion = trivial.release;
    username = admin;
    visualEditor = config.home.editor;

    pager.executable = meta.getExe config.home.pager.package;
    pager.package = pkgs.ov;

    sessionVariables = {
      MANPAGER = "${meta.getExe' pkgs.coreutils-full "env"} BATMAN_IS_BEING_MANPAGER=yes ${meta.getExe' pkgs.bat-extras.batman ".batman-wrapped"}"; # https://github.com/eth-p/bat-extras/blob/aef5a424b4b788eb6b8b2427dadb1376767b6535/src/batman.sh#L70
      MANROFFOPT = "-c"; # https://man.archlinux.org/man/groff.1.en#c
      SYSTEMD_PAGERSECURE = trivial.boolToString true; # https://unix.stackexchange.com/questions/730518/systemd-journalctl-unable-to-change-default-pager
    };
  };

  programs = modules.mkMerge [
    {
      atuin.settings = {
        dialect = "uk";
        enter_accept = true;
        keymap_mode = "auto";
        workspaces = true;

        sync.records = true;
      };

      bash = {
        historyControl = [ "ignoreboth" ];
        historyFile = "${config.xdg.stateHome}/bash/history"; # https://savannah.gnu.org/patch/?10431
        initExtra = lib.readFile ./auxiliary/init.bash;
        # profileExtra = ''[[ -r /run/secrets/nix_cccp_pat ]] && GH_TOKEN="$(sed -nr 's/.*github.com=(.*)\s.*/\1/p' /run/secrets/nix_cccp_pat )" && export GH_TOKEN'';

        sessionVariables.HISTTIMEFORMAT = "%c "; # https://man.archlinux.org/man/strftime.3#DESCRIPTION
      };

      bat.config.wrap = "never"; # https://noborus.github.io/ov/bat/index.html
      bat.extraPackages = lib.attrValues {
        inherit (pkgs.bat-extras)
          batdiff
          batgrep
          batman
          batwatch
          ;
      };

      chromium.package = pkgs.ungoogled-chromium;
      chromium.nativeMessagingHosts = [ pkgs.kdePackages.plasma-browser-integration ]; # https://github.com/NixOS/nixpkgs/blob/b024ced1aac25639f8ca8fdfc2f8c4fbd66c48ef/nixos/modules/services/desktop-managers/plasma6.nix#L350

      fd.hidden = true;

      firefox = {
        package = inputs.flake-firefox-nightly.packages.${hostPlatform}.firefox-nightly-bin;

        nativeMessagingHosts = [ pkgs.kdePackages.plasma-browser-integration ]; # https://github.com/NixOS/nixpkgs/blob/b024ced1aac25639f8ca8fdfc2f8c4fbd66c48ef/nixos/modules/services/desktop-managers/plasma6.nix#L346

        profiles = {
          synced.id = 3;

          twitch = extendFirefoxProfile {
            id = 2;

            extensions.packages = lib.attrValues { inherit (firefox-addons) betterttv; };

            settings."extensions.autoDisableScopes" = 0;
          };

          nsfw = extendFirefoxProfile {
            id = 1;

            extensions.packages = lib.attrValues {
              inherit (firefox-addons)
                bitwarden
                copy-selected-tabs-to-clipboard
                link-gopher
                reddit-enhancement-suite
                single-file
                violentmonkey
                wayback-machine
                ;
            };

            settings."browser.newtabpage.activity-stream.topSitesRows" = 2;
            settings."extensions.autoDisableScopes" = 0;
          };

          ${admin} = extendFirefoxProfile {
            containersForce = true;

            extensions.packages = lib.attrValues {
              inherit (firefox-addons)
                ask-historians-comment-helper
                auto-sort-bookmarks
                betterttv
                bitwarden
                bookmark-search-plus-2
                cookie-quick-manager
                copy-selected-tabs-to-clipboard
                enhancer-for-nebula
                link-gopher
                multi-account-containers
                plasma-integration
                reddit-enhancement-suite
                redirector
                refined-github
                search-by-image
                single-file
                sponsorblock
                translate-web-pages
                user-agent-string-switcher
                violentmonkey
                wayback-machine
                xkit-rewritten
                ;
            };

            containers.private = {
              id = 1; # so as to be visible when right-clicked

              color = "red";
              icon = "fingerprint";
            };

            search.order = [ ]; # Any engines that aren’t included in this list will be listed after these in an unspecified order.
            search.engines = {
              "NixOS Wiki" = {
                definedAliases = [ "@nw" ];
                icon = "https://wiki.nixos.org/favicon.ico";
                urls = [ { template = "https://wiki.nixos.org/w/index.php?search={searchTerms}"; } ];
              };
            };

            settings = modules.mkMerge [
              {
                "browser.newtabpage.activity-stream.topSitesRows" = 4;
                "browser.startup.page" = 3;
              }

              (falseGenAttrs [
                "browser.aboutConfig.showWarning"
                "browser.bookmarks.showMobileBookmarks"

                "devtools.webconsole.filter.error"
                "devtools.webconsole.filter.warn"
                "devtools.webconsole.input.editorOnboarding"

                # "xpinstall.signatures.required" # https://github.com/bpc-clone/bypass-paywalls-firefox-clean
              ])

              (trueGenAttrs [
                "browser.urlbar.keepPanelOpenDuringImeComposition"

                "devtools.everOpened"
                "devtools.webconsole.input.editor"
                "devtools.webconsole.timestampMessages"
              ])
            ];
          };
        };
      };

      gh.extensions = # https://github.com/topics/gh-extension
        lib.attrValues {
          inherit (pkgs)
            gh-dash
            gh-f
            gh-i
            gh-markdown-preview
            gh-notify
            gh-s
            ;
        };
      gh.settings.git_protocol = "ssh";

      git = {
        userEmail = "33189614+minhtrancccp@users.noreply.github.com";
        userName = "Minh Tran";

        delta.enable = true;

        extraConfig.merge.autoStash = true;
        extraConfig.push.autoSetupRemote = true;

        lfs.enable = true;

        signing.signByDefault = true;
      };

      gpg.homedir = "${config.xdg.dataHome}/gnupg";

      lazygit.settings.customCommands =
        /*
          https://github.com/jesseduffield/lazygit/issues/41
          https://github.com/jesseduffield/lazygit/wiki/Custom-Commands-Compendium
          https://stackoverflow.com/questions/65837109/when-should-i-use-git-push-force-if-includes
        */
        [
          {
            command = "${gitPath} push -- {{.SelectedRemote.Name}} {{.SelectedLocalCommit.Sha}}:{{.SelectedLocalBranch.Name}}";
            context = "commits";
            description = "Push a specific commit (and any preceding)";
            key = "P";
            loadingText = "Pushing commit...";
            stream = "yes";
          }

          {
            command = "${gitPath} push {{ if .Form.Arg }}--{{ .Form.Arg }} {{ end }}-- {{.Form.Remote}}";
            context = "global";
            description = "Push to a specific remote repository";
            key = "<c-P>";
            loadingText = "Pushing to chosen remote...";
            prompts = [
              {
                command = ''${meta.getExe pkgs.bash} -c "${gitPath} remote --verbose | ${meta.getExe pkgs.gnugrep} -- '\\s(push'"'';
                filter = "(?P<remote>.*)\\s+(?P<url>.*)\\s\\(push\\)";
                key = "Remote";
                labelFormat = "{{ .remote | bold | cyan }} {{ .url }}";
                title = "Which remote repository to push to?";
                type = "menuFromCommand";
                valueFormat = "{{ .remote }}";
              }

              {
                key = "Arg";
                options =
                  lib.map
                    (
                      arg:
                      attrsets.nameValuePair (if arg == "" then "normal" else lib.replaceStrings [ "-" ] [ " " ] arg) arg
                    )
                    [
                      ""
                      "force"
                      "force-with-lease"
                    ];
                title = "How to push?";
                type = "menu";
              }
            ];
          }

          {
            command = "${gitPath} commit --message '{{.Form.Type}}{{ if .Form.Scope }}({{ .Form.Scope }}){{ end }}{{.Form.Breaking}}: {{.Form.Message}}'";
            context = "global";
            description = "Create new conventional commit";
            key = "<c-v>";
            loadingText = "Creating conventional commit...";
            prompts = [
              {
                key = "Type";
                options =
                  attrsets.mapAttrsToList
                    (name: description: { inherit description; } // attrsets.nameValuePair name name)
                    {
                      build = "Changes that affect the build system or external dependencies";
                      chore = "Other changes that don't modify src or test files";
                      ci = "Changes to CI configuration files and scripts";
                      docs = "Documentation only changes";
                      feat = "A new feature";
                      fix = "A bug fix";
                      perf = "A code change that improves performance";
                      refactor = "A code change that neither fixes a bug nor adds a feature";
                      revert = "Reverts a previous commit";
                      style = "Changes that do not affect the meaning of the code";
                      test = "Adding missing tests or correcting existing tests";
                    };
                title = "Type of change";
                type = "menu";
              }

              {
                initialValue = "";
                key = "Scope";
                title = "Scope";
                type = "input";
              }

              {
                key = "Breaking";
                options = attrsets.attrsToList {
                  no = "";
                  yes = "!";
                };
                title = "Breaking change";
                type = "menu";
              }

              {
                initialValue = "";
                key = "Message";
                title = "message";
                type = "input";
              }

              {
                body = "Are you sure you want to commit?";
                key = "Confirm";
                title = "Commit";
                type = "confirm";
              }
            ];
          }
        ];
      lazygit.settings.git.overrideGpg = true; # https://github.com/jesseduffield/lazygit/discussions/2403

      man.generateCaches = true;

      nix-index-database.comma.enable = true;

      plasma = {
        configFile.kwinrc.Xwayland.Scale.value = 1;
        configFile.kwinrc.Xwayland.Scale.immutable = true;

        kwin.nightLight = {
          enable = true;

          mode = "location";

          location.latitude = "20.865139"; # https://geohack.toolforge.org/geohack.php?pagename=Haiphong&params=20_51_54.5_N_106_41_01.8_E_region:VN_type:city(2310280)
          location.longitude = "106.683833";
        };

        workspace.lookAndFeel = "org.kde.breezedark.desktop"; # https://develop.kde.org/docs/plasma/
      };

      ripgrep.arguments = [ "-S" ];

      yt-dlp.settings =
        {
          cookies-from-browser = "firefox";
        }
        // quickMapAttrs true {
          inherit (config.programs.yt-dlp.settings) live-from-start write-subs write-auto-subs;
        };
    }

    (genericMapAttrs
      (
        value:
        modules.mkMerge [
          { enable = true; }

          (attrsets.optionalAttrs ((value._type or null) == "flake") { package = flakeDefaultPackage value; })
          /*
            https://discourse.nixos.org/t/lib-modules-mkif-vs-lib-attrsets-optionalattrs-and-other-module-system-basics/42728
            https://wiki.nixos.org/wiki/The_Nix_Language_versus_the_NixOS_Module_System#If-then
          */
        ]
      )
      {
        inherit (config.programs)
          bash
          bat
          btop
          chromium
          fastfetch
          fd
          firefox
          fzf
          gh
          git
          gpg
          jq
          jqp
          khard
          lazygit
          mpv
          navi
          plasma
          ripgrep
          ssh
          yt-dlp
          zoxide
          ;
        inherit (inputs)
          atuin
          pay-respects
          ripgrep-all
          yazi
          ;
      }
    )
  ];

  services.gpg-agent = {
    enable = true;

    enableSshSupport = true; # https://wiki.gentoo.org/wiki/GnuPG#From_v2.3.7
    pinentryPackage = pkgs.pinentry-qt; # https://github.com/nix-community/home-manager/issues/908
  };

  xdg = {
    enable = true;

    configFile."ov/config.yaml".source =
      /*
        https://github.com/noborus/ov/blob/c48b4ec8574e6714f6efaaf0ca5d199eb7e0f98d/ov-less.yaml
        https://github.com/noborus/ov/blob/c48b4ec8574e6714f6efaaf0ca5d199eb7e0f98d/oviewer/config.go
      */
      toYAML (
        {
          General =
            {
              ColumnDelimiter = ",";
              Header = 0;
              MarkStyleWidth = 1;
              TabWidth = 4;
              WrapMode = true;

              Style = deepMergeAttrs [
                {
                  ColumnRainbow = lib.map (value: { Foreground = value; }) [
                    "white"
                    "crimson"
                    "aqua"
                    "lightsalmon"
                    "lime"
                    "blue"
                    "yellowgreen"
                  ];
                  MultiColorHighlight = lib.map (value: { Foreground = value; }) [
                    "red"
                    "aqua"
                    "yellow"
                    "fuchsia"
                    "lime"
                    "blue"
                    "grey"
                  ];

                  ColumnHighlight.Reverse = true;

                  JumpTargetLine.Underline = true;

                  OverLine.Underline = true;

                  Ruler.Foreground = "#CCCCCC";

                  SearchHighlight.Reverse = true;
                }

                (quickGenAttrs { Bold = true; } [
                  "Header"
                  "LineNumber"
                  "OverStrike"
                  "Ruler"
                ])

                (genericMapAttrs (value: { Background = value; }) {
                  Alternate = "gray";
                  MarkLine = "darkgoldenrod";
                  Ruler = "#333333";
                  SectionLine = "slateblue";
                  VerticalHeaderBorder = "#c0c0c0";
                })
              ];
            }
            // falseGenAttrs [
              "AlternateRows"
              "ColumnMode"
              "LineNumMode"
            ];

          KeyBind = {
            align_format = [ "ctrl+alt+f" ];
            alter_rows_mode = [ "C" ];
            backsearch = [ "?" ];
            begin_left = [ "shift+Home" ];
            bottom = [
              "End"
              ">"
              "G"
            ];
            cancel = [ "ctrl+c" ];
            close_all_filter = [ "ctrl+alt+k" ];
            close_doc = [ "alt+k" ];
            close_file = [
              "ctrl+F9"
              "ctrl+alt+s"
            ];
            column_mode = [ "c" ];
            column_width = [ "alt+o" ];
            convert_type = [ "ctrl+alt+t" ];
            delimiter = [ "F8" ];
            down = [
              "e"
              "ctrl+e"
              "j"
              "J"
              "ctrl+j"
              "Enter"
              "Down"
            ];
            end_right = [ "shift+End" ];
            exit = [
              "Escape"
              "q"
            ];
            filter = [ "&" ];
            fixed_column = [ "alt+f" ];
            follow_all = [ "ctrl+a" ];
            follow_mode = [ "F" ];
            follow_section = [ "F2" ];
            goto = [ ":" ];
            half_left = [ "ctrl+left" ];
            half_right = [ "ctrl+right" ];
            header = [ "H" ];
            header_column = [ "ctrl+alt+d" ];
            help = [
              "h"
              "ctrl+alt+c"
            ];
            hide_other = [ "alt+-" ];
            input_casesensitive = [ "alt+c" ];
            input_copy = [ "ctrl+c" ];
            input_incsearch = [ "alt+i" ];
            input_next = [ "Down" ];
            input_non_match = [ "!" ];
            input_paste = [ "ctrl+v" ];
            input_previous = [ "Up" ];
            input_regexp_search = [ "alt+r" ];
            input_smart_casesensitive = [ "alt+s" ];
            jump_target = [ "alt+j" ];
            last_section = [ "9" ];
            left = [ "left" ];
            line_number_mode = [ "alt+n" ];
            logdoc = [ "ctrl+alt+e" ];
            mark = [ "m" ];
            multi_color = [ "." ];
            next_backsearch = [ "N" ];
            next_doc = [ "]" ];
            next_mark = [ "alt+>" ];
            next_search = [ "n" ];
            next_section = [ "space" ];
            page_down = [
              "PageDown"
              "ctrl+v"
              "alt+space"
              "f"
              "z"
            ];
            page_half_down = [
              "d"
              "ctrl+d"
            ];
            page_half_up = [
              "u"
              "ctrl+u"
            ];
            page_up = [
              "PageUp"
              "b"
              "alt+v"
            ];
            plain_mode = [ "ctrl+F7" ];
            previous_doc = [ "[" ];
            previous_mark = [ "alt+<" ];
            previous_section = [ "^" ];
            rainbow_mode = [ "ctrl+F4" ];
            raw_format = [ "ctrl+alt+g" ];
            reload = [
              "R"
              "ctrl+r"
            ];
            remove_all_mark = [ "ctrl+delete" ];
            remove_mark = [ "M" ];
            right = [ "right" ];
            save_buffer = [ "s" ];
            search = [ "/" ];
            section_delimiter = [ "alt+d" ];
            section_header_num = [ "F7" ];
            section_start = [
              "ctrl+F3"
              "alt+s"
            ];
            set_view_mode = [
              "p"
              "P"
            ];
            set_write_exit = [ "ctrl+q" ];
            shrink_column = [ "alt+x" ];
            skip_lines = [ "ctrl+s" ];
            suspend = [ "ctrl+z" ];
            sync = [
              "r"
              "ctrl+l"
            ];
            tabwidth = [ "t" ];
            toggle_mouse = [ "ctrl+alt+r" ];
            toggle_ruler = [ "alt+shift+F9" ];
            top = [
              "Home"
              "g"
              "<"
            ];
            up = [
              "y"
              "Y"
              "ctrl+y"
              "k"
              "K"
              "ctrl+K"
              "Up"
            ];
            vertical_header = [ "ctrl+alt+b" ];
            watch = [
              "T"
              "ctrl+alt+w"
            ];
            watch_interval = [ "ctrl+w" ];
            width_left = [ "ctrl+shift+left" ];
            width_right = [ "ctrl+shift+right" ];
            wrap_mode = [
              "w"
              "W"
            ];
            write_exit = [ "Q" ];
          };

          Mode = {
            ini = {
              Align = true;
              ColumnDelimiter = " = ";
              ColumnMode = true;
              WrapMode = false;
            };

            markdown.SectionDelimiter = "^#";
            markdown.Style.SectionLine.Background = "blue";
          };
        }
        // trueGenAttrs [
          "Incsearch"
          "QuitSmall"
          "RegexpSearch"
          "SmartCaseSensitive"
        ]
      );
    configFile.shellcheckrc.text =
      /*
        https://github.com/koalaman/shellcheck/issues/2355
        https://www.shellcheck.net/wiki/Directive
      */
      "external-sources=true";

    mimeApps.enable = true; # Whether to manage $XDG_CONFIG_HOME/mimeapps.list.
    mimeApps.defaultApplications =
      attrsets.concatMapAttrs
        (
          type:
          attrsets.mapAttrs' (
            subtype: apps:
            apps
            |> lib.map (app: "${app}.desktop") # removable if an attr-based approach can be done
            |> attrsets.nameValuePair "${type}/${subtype}"
          )
        )
        {
          application = {
            x-extension-htm = browserDesktopEntryRoots;
            x-extension-html = browserDesktopEntryRoots;
            x-extension-shtml = browserDesktopEntryRoots;
            x-extension-xht = browserDesktopEntryRoots;
            x-extension-xhtml = browserDesktopEntryRoots;
            "xhtml+xml" = browserDesktopEntryRoots;
          };

          text.html = browserDesktopEntryRoots;

          x-scheme-handler = {
            chrome = browserDesktopEntryRoots;
            http = browserDesktopEntryRoots;
            https = browserDesktopEntryRoots;
          };
        };
  };
}
