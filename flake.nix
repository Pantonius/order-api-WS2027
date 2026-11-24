{
  description = "orders-api — development environment for the FastAPI orders service";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          name = "orders-api";

          packages = [
            # pyproject.toml declares requires-python >= 3.11 and ruff targets py311,
            # so the shell pins the oldest supported interpreter. Bump both together.
            pkgs.python311

            pkgs.gnumake

            # `make mcp-inspect` runs npx @modelcontextprotocol/inspector (needs Node >= 22).
            pkgs.nodejs_22

            # AGENTS.md: Redis holds the shared state (production runs 3 replicas).
            # Gives you redis-server and redis-cli; the test suite uses fakeredis instead.
            pkgs.redis
          ];

          # Python dependencies stay in requirements.txt and are installed with
          # `make setup` into .venv — nixpkgs cannot satisfy them anyway
          # (requirements.txt wants mcp>=2.2, nixpkgs ships 1.x).
          env = {
            # Keep pip from reaching for a user-wide ~/.local install.
            PIP_DISABLE_PIP_VERSION_CHECK = "1";
            PYTHONNOUSERSITE = "1";
          }
          // nixpkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
            # manylinux wheels (pydantic-core, uvloop, httptools) are prebuilt binaries
            # that expect a conventional libc/libstdc++ layout, which NixOS does not have.
            LD_LIBRARY_PATH = nixpkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
            ];
          };

          shellHook = ''
            # Let `pytest`, `ruff` and `uvicorn` resolve once make setup has run.
            export PATH="$PWD/.venv/bin:$PATH"

            if [ ! -x .venv/bin/python ]; then
              echo "orders-api: no .venv yet — run 'make setup'."
            fi
          '';
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
