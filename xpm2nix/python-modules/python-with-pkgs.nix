{poetry2nix, lib, pythonOlder}:
# For more info, see
# http://datakurre.pandala.org/2015/10/nix-for-python-developers.html
# https://nixos.org/nixos/nix-pills/developing-with-nix-shell.html
# https://nixos.org/nix/manual/#sec-nix-shell

with builtins;
poetry2nix.mkPoetryEnv {
  projectDir = ./.;
  overrides = poetry2nix.overrides.withDefaults (self: super: {

    ndex2 = super.ndex2.overridePythonAttrs(oldAttrs: {
      # The source requiremets.txt appears to want:
      #   if python < 3, use enum
      #   if python 3 but < 3.4, use enum34
      # But the way it's specified doesn't work for python >= 3.4.
      # I'm just telling it to use enum34 whenever python < 3.4
      prePatch = (oldAttrs.prePatch or "") + ''
        substituteInPlace setup.py \
            --replace 'enum34' 'enum34; python_version < "3.4"'
      '';

#      propagatedBuildInputs = [
#        six ijson requests requests-toolbelt networkx urllib3 pandas pysolr numpy
#      ] ++ lib.optionals (pythonOlder "3.4") [ enum34 ];

      propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ lib.optionals (pythonOlder "3.4") [ enum34 ];

#      checkInputs = [
#        nose six ijson requests requests-toolbelt networkx urllib3 pandas pysolr numpy
#      ];
#
#      checkPhase = ''
#        nosetests -v
#      '';

      # Tests try to make network requests, so we can't run them
      doCheck = false;
    });

    aquirdturtle-collapsible-headings = super.aquirdturtle-collapsible-headings.overridePythonAttrs(oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
        super.jupyter-packaging
      ];
    });
    jupyterlab = super.jupyterlab.overridePythonAttrs(oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
        super.jupyter-packaging
      ];
    });

#    seaborn = super.seaborn.overridePythonAttrs(oldAttrs: {
#      nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [
#        super.jupyter-packaging
#      ];
#      buildInputs = (oldAttrs.buildInputs or []) ++ [
#        super.certifi
#      ];
#    });

    jupyterlab-code-formatter = super.jupyterlab-code-formatter.overridePythonAttrs(oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
        super.jupyter-packaging
      ];
    });
    jupyterlab-drawio = super.jupyterlab-drawio.overridePythonAttrs(oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
        super.jupyter-packaging
      ];
    });
    jupyterlab-hide-code = super.jupyterlab-hide-code.overridePythonAttrs(oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
        super.jupyter-packaging
      ];
    });

    jupyterlab-system-monitor = super.jupyterlab-system-monitor.overridePythonAttrs(oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
        super.jupyter-packaging
      ];
    });
    jupyterlab-topbar = super.jupyterlab-topbar.overridePythonAttrs(oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
        super.jupyter-packaging
      ];
    });
    jupyter-resource-usage = super.jupyter-resource-usage.overridePythonAttrs(oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
        super.jupyter-packaging
      ];
    });

    jupyterlab-vim = self.callPackage ./jupyterlab-vim.nix {jupyter-packaging=self.jupyter-packaging;};
    jupyterlab-vimrc = self.callPackage ./jupyterlab-vimrc.nix {};

    jupyterlab-widgets = super.jupyterlab-widgets.overridePythonAttrs(oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
        super.jupyter-packaging
      ];
    });
  });
}
