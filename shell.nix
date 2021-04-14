with builtins;
#14

let
  # TODO: rename these directory variables to match what Jupyter uses.
  # https://jupyter.readthedocs.io/en/latest/use/jupyter-directories.html
  # https://jupyterlab.readthedocs.io/en/stable/user/directories.html#jupyterlab-application-directory
  # https://jupyter-notebook.readthedocs.io/en/stable/config.html
  # https://jupyter-server.readthedocs.io/en/latest/search.html?q=jupyter_server_config.json
  # https://jupyterlab.readthedocs.io/en/stable/user/directories.html

  # set notebook root_dir in specs/jupyter_server_config.json
  # ServerApp.root_dir

  # and/or specs/jupyter_notebook_config.json
  # NotebookApp.notebook_dir
  # "notebook_dir": "/home/ariutta/Documents/pfocr2ndex/notebooks",

  repoDir = toString ./.;
  # in some cases, notebookDir will be the same as repoDir
  notebookDir = "${repoDir}/notebooks";

  # for local settings, workspaces, etc.
  mutableJupyterDir = "${repoDir}/.share/jupyter";

  # Path to the JupyterWith folder.
  jupyterWithPath = builtins.fetchGit {
    url = https://github.com/tweag/jupyterWith;
    rev = "35eb565c6d00f3c61ef5e74e7e41870cfa3926f7";
  };

  # Path to the poetry2nix folder.
  poetry2nixPath = builtins.fetchGit {
    url = https://github.com/nix-community/poetry2nix;
    rev = "e72ff71c3cc8bbc708dbc13941888eb08a65f651";
  };

  # for dev
  #myoverlay = import ../mynixpkgs/overlay.nix;
  # for prod
  myoverlay = import (builtins.fetchGit {
    url = https://github.com/ariutta/mynixpkgs;
    rev = "ebd930f4d67ff658084281a9a71c6400ac2b912a";
    ref = "main";
  });

  # Importing overlays
  overlays = [
    # makes poetry2nix available
    (import "${poetry2nixPath}/overlay.nix")
    myoverlay
    # jupyterWith overlays
    # Only necessary for Haskell kernel
    (import "${jupyterWithPath}/nix/haskell-overlay.nix")
    # Necessary for Jupyter
    (import "${jupyterWithPath}/nix/python-overlay.nix")
    (import "${jupyterWithPath}/nix/overlay.nix")
  ];

  # Your Nixpkgs snapshot, with JupyterWith packages.
  pkgs = import <nixpkgs> { inherit overlays; config.allowUnfree = true; };

  # 'jupyter-kernelspec list' makes everything lowercase and joins the
  # internal kernel name with this descriptor. Example for descriptor 'mypkgs':
  #   ipython_mypkgs
  #   ir_mypkgs
  #
  # In the JupyterLab GUI, we see the language name joined to the descriptor
  # with a dash. Example for descriptor 'mypkgs':
  #   Python3 - mypkgs
  #   R - mypkgs
  kernel_descriptor = "mypkgs";

  #########################
  # R
  #########################

  myRPackages = p: with p; [
    pacman

    tidyverse
    # tidyverse includes the following:
    # * ggplot2 
    # * purrr   
    # * tibble  
    # * dplyr   
    # * tidyr   
    # * stringr 
    # * readr   
    # * forcats 

    feather
    knitr
  ];

  myR = [ pkgs.R ] ++ (myRPackages pkgs.rPackages);

  irkernel = jupyter.kernels.iRWith {
    # Identifier that will appear on the Jupyter interface.
    name = kernel_descriptor;
    # Libraries to be available to the kernel.
    packages = myRPackages;
    # Optional definition of `rPackages` to be used.
    # Useful for overlaying packages.
    rPackages = pkgs.rPackages;
  };

  #########################
  # Python
  #########################

  jupyterExtraPythonResult = pkgs.callPackage ./xpm2nix/python-modules/python-with-pkgs.nix {
    pythonOlder = pkgs.python3.pythonOlder;
  };
  pythonEnv = jupyterExtraPythonResult.poetryEnv;
  topLevelPythonPackages = jupyterExtraPythonResult.topLevelPythonPackages;
  python3 = pythonEnv;

  jupyter = pkgs.jupyterWith;

  # TODO: take a look at xeus-python
  # https://github.com/jupyter-xeus/xeus-python#what-are-the-advantages-of-using-xeus-python-over-ipykernel-ipython-kernel
  # It supports the jupyterlab debugger. But it's not packaged for nixos yet.

  # TODO: I was getting the following error message:
  # Generating grammar tables from /nix/store/sr8r3k029wvgdbv2zr36wr976dk1lya6-python3-3.8.7-env/lib/python3.8/site-packages/blib2to3/Grammar.txt
  # Writing grammar tables to /home/ariutta/.cache/black/20.8b1/Grammar3.8.7.final.0.pickle
  # Writing failed: [Errno 2] No such file or directory: '/home/ariutta/.cache/black/20.8b1/tmppem8fqj6'

  # I made it go away by manually adding the directory, but shouldn't this be automatic?
  # mkdir -p /home/ariutta/.cache/black/20.8b1/

  iPython = jupyter.kernels.iPythonWith {
    name = kernel_descriptor;
    packages = p: with p; [
      ##############################
      # Packages to augment Jupyter
      ##############################

      # TODO: nb_black is a 'python magic', not a server extension. Since it is
      # intended only for augmenting jupyter, where should I specify it?
      nb_black

      # TODO: for code formatting, compare nb_black with jupyterlab-code-formatter.
      # One difference:
      # nb_black is an IPython Magic (%), whereas
      # jupyterlab-code-formatter is a combo lab & server extension.

      # similar question for nbconvert: where should we specify it?
      nbconvert
      jupytext

      ################################
      # Non-Jupyter-specific packages
      ################################

      lxml
      seaborn
      skosmos_client
      wikidata2df

      ############
      # requests+
      ############
      requests
      requests-cache

      ############
      # Pandas+
      ############
      numpy
      pandas
      pyarrow # needed for pd.read_feather()

      ########
      # rpy2
      ########
      rpy2
      # tzlocal is needed to make rpy2 work
      tzlocal
      # TODO: is simplegeneric also needed?
      simplegeneric

      ##################
      # Parse messy HTML
      ##################
      beautifulsoup4
      soupsieve

      ########
      # Text
      ########

      # for characters that look like each other
      confusable-homoglyphs
      homoglyphs

      # fix encodings
      ftfy

      pyahocorasick
      spacy
      unidecode

      ########
      # Images
      ########

      # Python interface to the libmagic file type identification library
      # I don't think this has anything to do w/ Jupyter magics
      python_magic
      # python bindings for imagemagick
      Wand
      # Python Imaging Library
      pillow

      ########
      # Google
      ########

      #google_api_core
      #google_cloud_core
      #google-cloud-sdk
      #google_cloud_testutils
      #google_cloud_automl
      #google_cloud_storage
    ];
  };

  npmLabextensions = pkgs.callPackage ./xpm2nix/node-packages/labextensions.nix {
    jq=pkgs.jq;
    jupyter=pythonEnv.pkgs.jupyter;
    jupyterlab=pythonEnv.pkgs.jupyterlab;
    nodejs=pkgs.nodejs;
    setuptools=pythonEnv.pkgs.setuptools;
  };

  shareSrc = ./share-src;
  shareJupyter = pkgs.symlinkJoin {
    name = "my-share-jupyter";
    paths = (pkgs.lib.lists.map (x: "${x}/share/jupyter") (
      (pkgs.lib.lists.map (x: pkgs.lib.attrsets.getAttr(x.name) pythonEnv.pkgs) (
        pkgs.lib.lists.filter (x: x ? dependencies.jupyterlab) topLevelPythonPackages
      )) ++ (
        with pythonEnv.pkgs; [jupyterlab jupytext widgetsnbextension jupyter-resource-usage nbconvert]
      ))
    ) ++ [npmLabextensions shareSrc];
    postBuild = ''
      rm "$out/config/jupyter_server_config.json"
      substitute "${shareSrc}/config/jupyter_server_config.json" "$out/config/jupyter_server_config.json" --subst-var-by notebookDir "${notebookDir}"

      rm "$out/config/jupyter_notebook_config.json"
      substitute "${shareSrc}/config/jupyter_notebook_config.json" "$out/config/jupyter_notebook_config.json" --subst-var-by notebookDir "${notebookDir}"
    '';
  };

  jupyterEnvironment =
    jupyter.jupyterlabWith {
      # Corresponds to JupyterLab Application Directory
      # https://jupyterlab.readthedocs.io/en/stable/user/directories.html#jupyterlab-application-directory
      # Directory from which we serve notebooks
      #
      # this is what we used to use:
      #directory = "${mutableJupyterDir}/lab";
      #
      # I want to use this:
      directory = "${shareJupyter}/lab";

      kernels = [ iPython irkernel ];

      # Add extra packages to the JupyterWith environment
      extraPackages = p: [
        ####################
        # For Jupyter
        ####################

        # needed by nbconvert
        p.pandoc
        # see https://github.com/jupyter/nbconvert/issues/808
        #tectonic
        # more info: https://nixos.wiki/wiki/TexLive
        p.texlive.combined.scheme-full
        # not sure the following needs to be specified here:
        pythonEnv.pkgs.nbconvert

        # still getting some errors:
        # nbconvert failed: Pyppeteer is not installed to support Web PDF conversion. Please install `nbconvert[webpdf]` to enable.
        # - and -
        # nbconvert failed: PDF creating failed, captured latex output:
        # Failed to run "['xelatex', 'notebook.tex', '-quiet']" command:
        # ...
        # (/nix/store/llmvlb5wpjrmp4ckxw4g21qn4syyhjpv-texlive-combined-full-2020.2021010
        # 9/share/texmf/tex/latex/base/size11.cloFontconfig warning: "/etc/fonts/fonts.conf", line 86: unknown element "blank"
        # ))

        # TODO: these dependencies are only required when we want to build a
        # lab extension from source.
        # Does jupyterWith allow me to specify them as buildInputs?
        p.nodejs
        p.yarn

        # Note: pythonEnv has packages for augmenting Jupyter as well
        # as for other purposes.
        # TODO: should it be specified here?
        pythonEnv

        # jupyterlab-lsp must be specified here in order for the LSP for R to work.
        # TODO: why isn't it enough that this is specified for pythonEnv?
        pythonEnv.pkgs.jupyter-lsp
        pythonEnv.pkgs.jupyterlab-lsp

        # TODO: @krassowski/jupyterlab-lsp:signature settings schema could not be found and was not loaded

        #pythonEnv.pkgs.jupyterlab-code-formatter

        pythonEnv.pkgs.jupytext

        p.R
        
        p.rsync
      ] ++ (with pkgs.rPackages; [
        ################################################
        # For server extensions that rely on R or R pkgs
        ################################################
        # TODO: is it possible to specify these via extraJupyterPath instead?
        #       I haven't managed to do it, but it should be possible.
        #       I tried adding the following to extraJupyterPath, but that
        #       didn't seem to do it.
        #"${pkgs.R}/lib/R" 
        #"${pkgs.R}/lib/R/library"
        #"${pkgs.rPackages.formatR}/library"
        #"${pkgs.rPackages.languageserver}/library"

        languageserver

        #----------------
        # code formatting
        #----------------
        formatR
        ## an alternative formatter:
        #styler
        #prettycode # seems to be needed by styler
      ]);

      # Bring all inputs from a package in scope:
      #extraInputsFrom = p: [ ];

      # Make paths available to Jupyter itself, generally for server extensions
      extraJupyterPath = pkgs:
        concatStringsSep ":" [
          "${pythonEnv}/${python3.sitePackages}"
        ];
    };
in
  jupyterEnvironment.env.overrideAttrs (oldAttrs: {
    shellHook = oldAttrs.shellHook + ''
      # this is needed in order that tools like curl and git can work with SSL
      # or maybe even just  for direnv?
      if [ ! -f "$SSL_CERT_FILE" ] || [ ! -f "$NIX_SSL_CERT_FILE" ]; then
        candidate_ssl_cert_file=""
        if [ -f "$SSL_CERT_FILE" ]; then
          candidate_ssl_cert_file="$SSL_CERT_FILE"
        elif [ -f "$NIX_SSL_CERT_FILE" ]; then
          candidate_ssl_cert_file="$NIX_SSL_CERT_FILE"
        else
          candidate_ssl_cert_file="/etc/ssl/certs/ca-bundle.crt"
        fi
        if [ -f "$candidate_ssl_cert_file" ]; then
            export SSL_CERT_FILE="$candidate_ssl_cert_file"
            export NIX_SSL_CERT_FILE="$candidate_ssl_cert_file"
        else
          echo "Cannot find a valid SSL certificate file. curl will not work." >&2
        fi
      fi
      # TODO: is the following line ever useful?
      # maybe when using nix-shell?
      #export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

      # set SOURCE_DATE_EPOCH so that we can use python wheels
      SOURCE_DATE_EPOCH=$(date +%s)

      ######################
      # Jupyter + JupyterLab
      ######################

      #---------
      # set dirs
      #---------

      mkdir -p "${mutableJupyterDir}"

      # The following directories are OK with being immutable:

      export JUPYTER_CONFIG_DIR="${shareJupyter}/config"
      export JUPYTERLAB_DIR="${shareJupyter}/lab"

      # The following directories are themselves OK with being immutable, but I
      # only know how to point Jupyter to them via JUPYTER_DATA_DIR, which must
      # be immutable. So I add symlinks pointing to the latest immutable
      # directories from within the mutable JUPYTER_DATA_DIR.

      if [ -e "${mutableJupyterDir}/labextensions" ]; then
        rm "${mutableJupyterDir}/labextensions"
      fi
      ln -s "${shareJupyter}/labextensions" "${mutableJupyterDir}/labextensions"

      if [ -e "${mutableJupyterDir}/nbextensions" ]; then
        rm "${mutableJupyterDir}/nbextensions"
      fi
      ln -s "${shareJupyter}/nbextensions" "${mutableJupyterDir}/nbextensions"

      if [ -e "${mutableJupyterDir}/nbconvert" ]; then
        rm "${mutableJupyterDir}/nbconvert"
      fi
      ln -s "${shareJupyter}/nbconvert" "${mutableJupyterDir}/nbconvert"

      # The following directories must be mutable:

      export JUPYTER_DATA_DIR="${mutableJupyterDir}"
      mkdir -p "$JUPYTER_DATA_DIR"

      # if we don't want to allow the user to specify settings, this could be made immutable
      export JUPYTERLAB_SETTINGS_DIR="${mutableJupyterDir}/config/lab/user-settings/"
      mkdir -p "$JUPYTERLAB_SETTINGS_DIR"

      export JUPYTERLAB_WORKSPACES_DIR="${mutableJupyterDir}/config/lab/workspaces/"
      mkdir -p "$JUPYTERLAB_WORKSPACES_DIR"

      export JUPYTER_RUNTIME_DIR="${mutableJupyterDir}/runtime"
      mkdir -p "$JUPYTER_RUNTIME_DIR"

      # If JUPYTER_DATA_DIR is made immutable, I get the following error:
      # Unexpected error while saving file: Untitled.ipynb HTTP 500: Internal Server Error
      # (Unexpected error while saving file: Untitled.ipynb [Errno 30] Read-only file system: '/nix/store/rjcbrkd1br3d4kckw1m1ppn9ksv6sm0c-my-share-jupyter-0.0.0/notebook_secret')

      # I also got an error when I created an R ipynb file and tried saving it:
      #
      # File Save Error for Untitled1.ipynb
      # Unexpected error while saving file: Untitled1.ipynb HTTP 500: Internal Server Error (Unexpected error while saving file: Untitled1.ipynb attempt to write a readonly database)
      #
      # Possibly because this file changes when we create a new notebook:
      # .share/jupyter/nbsignatures.db

      # To identify which files must be mutable, make all dirs mutable and then:
      #
      # newer .share
      # find .share/ -newermt '2021-04-12 19:00'
      #
      # or
      #
      # find .share/ -newer .share/jupyter/nbextensions/jupytext/jupytext_menu.png

      # .share/jupyter/nbconvert/templates
      # .share/jupyter/notebook_secret
      # .share/jupyter/nbsignatures.db
      # .share/jupyter/runtime/jupyter_cookie_secret
      # .share/jupyter/runtime/jpserver-26238.json
      #
      # R or Python kernel launched:
      # .share/jupyter/runtime/kernel-87d047eb-f646-473a-9f17-fac7fcfe7d75.json
      #
      # .share/jupyter/runtime/jpserver-26238-open.html
      # .share/jupyter/config/lab/user-settings/@jupyterlab/application-extension/sidebar.jupyterlab-settings
      # .share/jupyter/config/lab/workspaces/default-37a8.jupyterlab-workspace

      #------------
      # other stuff
      #------------

      #export R_HOME="${pkgs.R}/lib/R"
      #export R_LIBS_SITE="$R_LIBS_SITE''${R_LIBS_SITE:+:}${pkgs.R}/lib/R/library:${pkgs.rPackages.languageserver}/library:${pkgs.rPackages.xml2}/library:${pkgs.rPackages.R6}/library"
      
      # TODO: this general format came from the nixpkgs generic R package builder.
      # What does it do?
      #export LD_LIBRARY_PATH="$LD_LIBRARY_PATH''${LD_LIBRARY_PATH:+:}${pkgs.R}/lib/R/lib"

      # this doesn't work. it gives this message:
      #   R cannot be found in the PATH and RHOME cannot be found.
      export LD_LIBRARY_PATH="$LD_LIBRARY_PATH''${LD_LIBRARY_PATH:+:}$(python -m rpy2.situation LD_LIBRARY_PATH)"
      #export LD_LIBRARY_PATH="$LD_LIBRARY_PATH''${LD_LIBRARY_PATH:+:}$(python -m rpy2.situation LD_LIBRARY_PATH)"
      # but strangely, this gives a result
      #direnv exec Documents/sandbox/pathway-figure-ocr/ sh -c 'python -m rpy2.situation LD_LIBRARY_PATH'
      # and so does this:
      #direnv exec Documents/sandbox/pathway-figure-ocr/ sh -c 'which R'
      # and this:
      #direnv exec Documents/sandbox/pathway-figure-ocr/ R --version

      # mybinder gave this message when launching:
      # Installation finished!  To ensure that the necessary environment
      # variables are set, either log in again, or type
      # 
      #   . /home/jovyan/.nix-profile/etc/profile.d/nix.sh
      # 
      # in your shell.

      if [ -f /home/jovyan/.nix-profile/etc/profile.d/nix.sh ]; then
         . /home/jovyan/.nix-profile/etc/profile.d/nix.sh
      fi
    '';
  })
