# CloudCompare and MeshLab MCP Integration Design

## Goal

Provide global, non-destructive CloudCompare and MeshLab tools to OpenCode for the scan-to-FreeCAD workflow. CloudCompare handles point clouds and scan comparison. A local PyMeshLab MCP server handles a constrained set of mesh repair operations. The related OpenCode skills explicitly route work to the correct server.

The same change removes Bitwarden Desktop from the declarative NixOS desktop package set. The current machine is `laptop-intel`, and the finished NixOS configuration is built and activated there.

## Scope

- Keep the existing `cloudcompare` and `meshlab` declarations in `modules/desktop/media-creation.nix`.
- Remove only `bitwarden-desktop` from `modules/desktop/browsers.nix`.
- Add global CloudCompare and MeshLab MCP entries to `~/.config/opencode/opencode.json`.
- Package CloudCompare MCP declaratively from a pinned Git commit with flake-locked Python dependencies.
- Create a standards-compliant PyMeshLab MCP package under `packages/meshlab-mcp` in the NixOS repository.
- Update `pointcloud-analysis/SKILL.md` and `mesh-repair/SKILL.md` with explicit application and MCP responsibilities.
- Build and activate `.#laptop-intel`.
- Commit and push the intended NixOS repository changes to `origin/main`.

The existing uncommitted `flake.lock` change is not part of this work and must remain unstaged.

## Architecture

### NixOS

`modules/profiles/desktop.nix` already imports both `media-creation.nix` and `browsers.nix` for all desktop hosts. CloudCompare and MeshLab therefore remain declarative system packages. Removing Bitwarden Desktop at the shared desktop module removes it from those hosts without affecting browser packages.

### CloudCompare MCP

`packages/cloudcompare-mcp/default.nix` fetches the community CloudCompare MCP server at commit `22b5232fd14e8ca02105aa47dcac40ad248a705c` with verified source hash `sha256-xeAy0OEc18kOCEobmOImEL7hg+VDMxGgbIGufUrCSOs=`. A `python313.withPackages` environment supplies the flake-locked `mcp`, `numpy`, `matplotlib`, `laspy`, `lazrs`, and `plyfile` packages. The installed wrapper sets the fetched source directory and `cloudcompare.version` as environment variables, then runs a small local Python module.

The local module imports the fetched upstream server without vendoring it and replaces `handle_get_cloudcompare_info` plus the broken `compute_normals` handler and tool definition. Upstream attempts the unsupported `CloudCompare --version` command and can report plugin output as a version while claiming readiness. The info replacement uses upstream binary discovery and response helpers, reports the Nix package version, and returns a structured error unless both the binary and package version are available. The normals replacement uses CloudCompare 2.13's `OCTREE_NORMALS` and `MODEL` commands, maps `TRIANGULATION` to `TRI`, disables auto-save, and writes through a reserved regular file in a random private staging directory bound to a securely opened destination dirfd. It rejects replaced temp inodes, symlinks, empty outputs and sidecars; reopens the result with the native loader; and requires metadata to confirm normals. Normal estimation outputs are restricted to PLY because live CloudCompare verification shows that LAS/LAZ lose normals and PCD is emitted in a form the native loader cannot safely verify. Source identity and a streaming SHA-256 digest are checked before and after processing. Parent identity is checked before and after atomic no-clobber hardlink publication, and every exception after the link but before committed success rolls the destination back through the bound dirfd or reports that rollback failed. Pre-commit failures clean staging and publish nothing, while post-commit cleanup failures preserve success and return warnings. Same-UID staging manipulation remains outside the threat model. Its closed schema does not expose KNN; radius is optional, positive, and expressed in source coordinate units, with automatic radius preferred when scale is unknown. Patching fails before startup unless exactly one upstream `compute_normals` tool definition exists.

OpenCode starts `/run/current-system/sw/bin/cloudcompare-mcp` as a local `stdio` server. `CLOUDCOMPARE_PATH` points to `/run/current-system/sw/bin/CloudCompare`. The unrestricted `cloudcompare_run_cloudcompare_command` tool is denied through the top-level OpenCode permission configuration; named CloudCompare tools remain available.

The server owns point-cloud operations:

- metadata and visualization
- subsampling and statistical outlier removal
- normal estimation
- ICP registration
- cloud-to-cloud and cloud-to-mesh distances
- scalar-field filtering
- point-cloud merging and format conversion

Skills use named tools instead of the server's unrestricted raw-command escape hatch whenever a named tool exists.

### MeshLab MCP

`packages/meshlab-mcp` contains a small Python server using the official MCP Python SDK, PyMeshLab, and `stdio` transport. A Nix wrapper supplies a `python313.withPackages` environment containing `mcp` and `pymeshlab`, which is required because the upstream PyPI PyMeshLab wheel does not resolve its native libraries directly on NixOS. OpenCode starts the installed `meshlab-mcp` command.

The server is stateless. Every mutating request supplies an absolute input path and a distinct output path. Each call opens its own `pymeshlab.MeshSet`, applies one constrained operation, saves to a temporary path, reads the result back, and atomically publishes it only after validation.

The initial tool surface is:

| Tool | Responsibility |
| --- | --- |
| `inspect_mesh` | Return vertex and face counts, bounds, components, and available quality indicators. |
| `clean_mesh` | Remove duplicate or unreferenced vertices and degenerate or zero-area elements. |
| `repair_holes` | Fill holes up to an explicit maximum size. |
| `compute_normals` | Compute and orient mesh normals. |
| `simplify_mesh` | Apply quadric decimation with explicit targets and boundary preservation. |
| `remesh_mesh` | Apply isotropic remeshing with an explicit target edge length. |
| `smooth_mesh` | Apply a selected conservative smoothing method with bounded iterations. |
| `export_mesh` | Convert to a supported mesh format and verify the written result. |

The server does not expose shell execution, Python execution, arbitrary PyMeshLab filters, or persistent mutable mesh state.

## Skill Responsibilities

`pointcloud-analysis` uses CloudCompare MCP for point-cloud metadata, visualization, cleanup, registration, distance analysis, normals, scalar filtering, merging, and conversion. It does not create or modify FreeCAD documents.

`mesh-repair` uses MeshLab MCP for mesh inspection, cleaning, hole repair, normal handling, simplification, remeshing, smoothing, and mesh export. It delegates point-cloud-only work to `pointcloud-analysis` and CloudCompare MCP. It does not create FreeCAD documents.

This division removes the current overlap in point-cloud cleanup while preserving the orchestration flow through `reverse-engineering`.

## Data Flow

1. OpenCode selects `pointcloud-analysis` for point-cloud input or `mesh-repair` for triangulated mesh input.
2. The selected skill calls the named MCP tool with absolute source and output paths.
3. The MCP server validates paths, format, numeric limits, and overwrite policy before loading data.
4. The operation records source metadata, performs one transformation, and writes a temporary output.
5. The server reopens the temporary output and checks that it is readable and structurally plausible.
6. The server atomically moves the validated output to the requested destination.
7. The response contains source metadata, result metadata, parameters, warnings, and the final path.
8. Downstream feature recognition and FreeCAD modeling consume the verified derivative while retaining the original scan as an immutable reference.

## Error Handling and Safety

- Inputs and outputs must be absolute paths.
- Missing input files, unsupported formats, invalid numeric limits, and existing output paths fail before geometry processing.
- CloudCompare normals use an existing non-symlink parent, private staging, source identity plus SHA-256 checks, verified normals metadata, and atomic rollback-safe no-clobber publication; they never write directly to the requested destination.
- Source files are never overwritten by default.
- Failed processing or validation removes temporary output and preserves prior valid artifacts.
- PyMeshLab and CloudCompare failures return the tool name, affected file, relevant parameters, and a concise cause.
- No operation silently falls back to a broader or destructive filter.
- The CloudCompare raw-command tool is denied globally by its exact OpenCode tool name, `cloudcompare_run_cloudcompare_command`.

## Testing

### MeshLab MCP

Implementation follows test-driven development:

1. Add failing tests for path validation, overwrite prevention, parameter bounds, and tool schemas.
2. Add failing integration tests using small mesh fixtures for each geometry operation.
3. Implement the minimum code needed for those tests.
4. Run an MCP protocol smoke test covering initialization, `tools/list`, and a real `tools/call`.
5. Verify output files by reopening them with PyMeshLab and comparing reported metadata.

### Skills

Before editing either skill, run baseline subagent scenarios without the proposed instructions and record misrouting or ambiguity. Run the same scenarios after each skill change and verify that point-cloud work selects CloudCompare MCP and mesh work selects MeshLab MCP.

### CloudCompare and OpenCode

- Confirm CloudCompare package version `2.13.2` from flake package metadata or its Nix store path. `CloudCompare --version` is unsupported in this package and exits nonzero. The locally corrected `get_cloudcompare_info` reports that Nix-supplied package version and is tested against the same metadata.
- Build and start the declaratively packaged MCP server and verify initialization and `tools/list`.
- Exercise the corrected normals tool with LS, QUADRIC, and TRIANGULATION models, including automatic and explicit source-coordinate-unit radii, then verify each output contains normals, source and output hashes survive no-clobber checks, and no staging remains.
- Validate that the merged OpenCode configuration starts the installed wrapper and resolves `cloudcompare_run_cloudcompare_command` to `deny` before restart.

### NixOS

- Evaluate the flake without writing the lock file.
- Build `.#nixosConfigurations.laptop-intel.config.system.build.toplevel`.
- Activate with `nixos-rebuild switch --flake .#laptop-intel`.
- Confirm `CloudCompare` and `cloudcompare-mcp` are available and `bitwarden` is absent from the active profile.

## Version Control and Deployment

- Stage only files intentionally changed by this work.
- Never stage or alter the pre-existing `flake.lock` modification.
- Commit the design separately from implementation.
- Commit the NixOS package removal after successful build and activation, then push intended commits to `origin/main`.
- The global OpenCode configuration and files under `/home/anders/Projekt/FreeCAD/skills` are outside the NixOS Git repository and are not included in its commits. The CloudCompare and MeshLab MCP wrappers are versioned in the NixOS repository.
- Restart OpenCode after changing its global configuration because MCP configuration is loaded only at startup.
