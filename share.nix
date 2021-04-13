{ stdenv
, lib
, notebookDir
, python3
, npmLabextensions
}:

with builtins;

let
  baseName = "my-share-jupyter";
  version = "0.0.0";
in
stdenv.mkDerivation rec {
  name = (concatStringsSep "-" [baseName version]);

  src = ./share-src;

  buildInputs = [];

  buildPhase = ''
    runHook preBuild

    mkdir -p "$out"
    cp -r "${src}/"* "$out"

    ##################
    # Specify settings
    ##################

    # Specify a font for the Terminal to make the Powerline prompt look OK.

    # TODO: should we install the fonts as part of this Nix definition?
    # TODO: one setting is '"theme": "inherit"'. Where does it inherit from?
    #       is it @jupyterlab/apputils-extension:themes.theme?

    # already copied:
    # share-src/lab/settings/overrides.json

    # for other settings, open Settings > Advanced Settings Editor to take a look.

    ##################
    # specify configs
    ##################

    # TODO: which of way of specifying server configs is better?
    # 1. jupyter_server_config.json (single file w/ all jpserver_extensions.)
    # 2. jupyter_server_config.d/ (directory holding multiple config files)
    #                            jupyterlab.json
    #                            jupyterlab_code_formatter.json
    #                            ... 

    # TODO: I'm getting these messages when I run jupyter-server:
    # [W 2021-04-10 12:58:15.384 NotebookApp] 'notebook_dir' has moved from NotebookApp to ServerApp. This config will be passed to ServerApp. Be sure to update your config before our next release.
    # [W 2021-04-10 12:58:15.384 NotebookApp] 'contents_manager_class' has moved from NotebookApp to ServerApp. This config will be passed to ServerApp. Be sure to update your config before our next release.

    #----------------------
    # jupyter_server_config
    #----------------------
    # We need to set root_dir in config so that this command:
    #   direnv exec ~/Documents/myenv jupyter lab start
    # always results in root_dir being ~/Documents/myenv.
    # Otherwise, running that command from $HOME makes root_dir be $HOME.
    #
    # TODO: what is the difference between these two:
    # - ServerApp.jpserver_extensions
    # - NotebookApp.nbserver_extensions
    #
    # If I don't include jupyterlab_code_formatter in
    # ServerApp.jpserver_extensions, I get the following error
    #   Jupyterlab Code Formatter Error
    #   Unable to find server plugin version, this should be impossible,open a GitHub issue if you cannot figure this issue out yourself.


    # jupyter_server_config.json: this should set the notebook directory, but
    # it didn't work for me. It used my home directory as notebook directory. 
    #
    # maybe relevant: https://github.com/jupyterlab/jupyterlab/issues/9633

    substitute "${src}/config/jupyter_server_config.json" "$out/config/jupyter_server_config.json" --subst-var-by notebookDir "${notebookDir}"

    #------------------------
    # jupyter_notebook_config
    #------------------------
    # The packages listed by 'jupyter-serverextension list' come from
    # what is specified in ./config/jupyter_notebook_config.json.
    # Yes, as confusing as it may be, it does appear that 'server extensions'
    # are specified in jupyter_notebook_config, not jupyter_server_config.
    #
    # We hide the bare-bones python3 kernel in JupyterLab, b/c we want to see
    # our customized python kernel that has our desired packages, not the
    # default python kernel that has no packages. We do so with this bit:
    # "ensure_native_kernel": false
    # More discussion:
    # https://github.com/jupyter/notebook/issues/3674
    # https://github.com/tweag/jupyterWith/issues/101

    # jupyter_notebook_config.json: I think this is the old way of setting the
    # root_dir/notebook_dir, but setting it in jupyter_server_config.json
    # didn't work.

    substitute "${src}/config/jupyter_notebook_config.json" "$out/config/jupyter_notebook_config.json" --subst-var-by notebookDir "${notebookDir}"

    ##############
    # nbextensions
    ##############

    # TODO: what are nbextensions/nbserver_extensions vs. server extensions.
    # What should share-src/config/jupyter_notebook_config.json have for
    # NotebookApp.nbserver_extensions? I used to set "jupyter-js-widgets": true,
    # but with that, I was getting the following message:
    # [W 2021-04-10 12:58:15.565 ServerApp] The module 'jupyter-js-widgets' could not be found. Are you sure the extension is installed?
    #
    # so I removed it and now just have "jupyter_lsp": true, "jupytext": true

    mkdir -p "$out/nbextensions"

    # currently just jupytext and widgetsnbextension

    # load_nbextensions.json tells Jupyter which nbextensions to load.
    # In load_nbextensions.json, we specify:
    #
    #   "jupyter-js-widgets/extension": true,
    #   "jupytext/index": true
    #
    # '/extension' and '/index' refer to filenames extension.js and index.js:
    # * share/jupyter/nbextensions/jupyter-js-widgets/extension.js
    # * share/jupyter/nbextensions/jupytext/index.js
    #
    # Not completely sure what all is needed here.
    # Setting these may make jupyter-nbextension list say everything
    # is OK and validated, but it may not actually be needed.

    # already copied:
    # share-src/config/nbconfig/notebook.d/load_nbextensions.json

    # widgetsnbextension
    # It appears jupyter-js-widgets is the javascript for widgetsnbextension,
    # and that widgetsnbextension may possibly be just javascript.
    ln -s "${python3.pkgs.widgetsnbextension}/share/jupyter/nbextensions/jupyter-js-widgets" "$out/nbextensions/jupyter-js-widgets"

    # jupytext (note we install nb, lab and server extension components)
    ln -s "${python3.pkgs.jupytext}/share/jupyter/nbextensions/jupytext" "$out/nbextensions/jupytext"

    ##################################
    # prebuilt lab extensions
    # symlink dirs into share/jupyter
    ##################################

    mkdir -p "$out/labextensions"

    # Note the prebuilt lab extensions are distributed via PyPI as "python"
    # packages, even though they are really JS, HTML and CSS.
    #
    # Symlink targets may generally use snake_case, but not always.
    #
    # The lab extension code appears to be in two places in the python packge:
    # 1) lib/python3.8/site-packages/snake_case_pkg_name/labextension
    # 2) share/jupyter/labextensions/dash-case-pkg-name
    # These directories are identical, except share/... has file install.json.

    # TODO: can we just specify a list of prebuilt lab extensions and run each
    # one through a function in order to create all the required symlinks?

    # jupyterlab_hide_code
    #
    # When the symlink target is 'jupyterlab-hide-code' (dash-case), the lab extension
    # works, but not when the symlink target is 'jupyterlab_hide_code' (snake_case).
    #
    # When using target share/..., the command 'jupyter-labextension list'
    # adds some extra info to the end:
    #   jupyterlab-hide-code v3.0.1 enabled OK (python, jupyterlab_hide_code)
    # When using target lib/..., we get just this:
    #   jupyterlab-hide-code v3.0.1 enabled OK
    # This difference could be due to the install.json being in share/...
    #
    ln -s "${python3.pkgs.jupyterlab-hide-code}/share/jupyter/labextensions/jupyterlab-hide-code" "$out/labextensions/jupyterlab-hide-code"

    # @axlair/jupyterlab_vim
    mkdir -p "$out/labextensions/@axlair"
    ln -s "${python3.pkgs.jupyterlab-vim}/lib/${python3.libPrefix}/site-packages/jupyterlab_vim/labextension" "$out/labextensions/@axlair/jupyterlab_vim"

    # jupyterlab-vimrc
    ln -s "${python3.pkgs.jupyterlab-vimrc}/lib/${python3.libPrefix}/site-packages/jupyterlab-vimrc" "$out/labextensions/jupyterlab-vimrc"

    # @krassowski/jupyterlab-lsp
    mkdir -p "$out/labextensions/@krassowski"
    ln -s "${python3.pkgs.jupyterlab-lsp}/share/jupyter/labextensions/@krassowski/jupyterlab-lsp" "$out/labextensions/@krassowski/jupyterlab-lsp"

    # @ryantam626/jupyterlab_code_formatter
    mkdir -p "$out/labextensions/@ryantam626"
    #ln -s "${python3.pkgs.jupyterlab-code-formatter}/share/jupyter/labextensions/@ryantam626/jupyterlab_code_formatter" "$out/labextensions/@ryantam626/jupyterlab_code_formatter"
    ln -s "${python3.pkgs.jupyterlab-code-formatter}/lib/${python3.libPrefix}/site-packages/jupyterlab_code_formatter/labextension" "$out/labextensions/@ryantam626/jupyterlab_code_formatter"

    # jupyterlab-drawio
    ln -s "${python3.pkgs.jupyterlab-drawio}/lib/${python3.libPrefix}/site-packages/jupyterlab-drawio/labextension" "$out/labextensions/jupyterlab-drawio"

    # @aquirdturtle/collapsible_headings
    mkdir -p "$out/labextensions/@aquirdturtle"
    ln -s "${python3.pkgs.aquirdturtle-collapsible-headings}/share/jupyter/labextensions/@aquirdturtle/collapsible_headings" "$out/labextensions/@aquirdturtle/collapsible_headings"

    # jupyterlab-system-monitor depends on jupyterlab-topbar and jupyter-resource-usage

    # jupyterlab-topbar
    ln -s "${python3.pkgs.jupyterlab-topbar}/lib/${python3.libPrefix}/site-packages/jupyterlab-topbar/labextension" "$out/labextensions/jupyterlab-topbar-extension"

    # jupyter-resource-usage
    mkdir -p "$out/labextensions/@jupyter-server"
    ln -s "${python3.pkgs.jupyter-resource-usage}/share/jupyter/labextensions/@jupyter-server/resource-usage" "$out/labextensions/@jupyter-server/resource-usage"

    # jupyterlab-system-monitor
    ln -s "${python3.pkgs.jupyterlab-system-monitor}/lib/${python3.libPrefix}/site-packages/jupyterlab-system-monitor/labextension" "$out/labextensions/jupyterlab-system-monitor"

    # jupytext (note we install nb, lab and server extension components)
    ln -s "${python3.pkgs.jupytext}/lib/${python3.libPrefix}/site-packages/jupytext/labextension" "$out/labextensions/jupyterlab-jupytext"

    #---------------------------------
    # Prebuilt lab extensions from NPM
    #---------------------------------

    # Take a source lab extension from NPM and prebuild it for Nix.
    # It's probably better to just always use the prebuilt lab extensions
    # PyPi, but this is a demo to show it's possible to do NPM -> Nix.
    for d in $(ls -1 "${npmLabextensions}/labextensions"); do
      ln -s "${npmLabextensions}/labextensions/$d" "$out/labextensions/$d"
    done
    
    ###################
    # JupyterLab itself
    ###################

    mkdir -p "$out/lab"
    # TODO: why do I need to mess with permissions here?
    chmod -R +w "$out/lab/"
    for x in $(ls -1 "${python3.pkgs.jupyterlab}/share/jupyter/lab"); do
      if [ -e "$out/lab/$x" ]; then
        echo "$out/lab/$x already exists. Merge contents, prioritizing ${src}." >&2
        mv "$out/lab/$x" custom
        cp -r "${python3.pkgs.jupyterlab}/share/jupyter/lab/$x" "$out/lab/$x"
        chmod -R +w "$out/lab/$x"
        cp -r custom/* "$out/lab/$x/"
        chmod -R -w "$out/lab/$x"
      else
        ln -s "${python3.pkgs.jupyterlab}/share/jupyter/lab/$x" "$out/lab/$x"
      fi
    done
    chmod -R -w "$out/lab/"

    echo "share.nix out: $out"

    runHook postBuild
  '';

  # Should I move some of the buildPhase into here?
  installPhase =''
    echo 'installPhase' >&2
  '';

  meta = with lib;
    { description = "My share/jupyter content";
      maintainers = with maintainers; [ ariutta ];
      platforms = platforms.all;
    };
}
