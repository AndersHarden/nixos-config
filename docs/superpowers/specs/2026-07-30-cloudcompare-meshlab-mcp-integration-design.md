# CloudCompare and MeshLab MCP Integration Design

## Goal

Provide global, non-destructive CloudCompare and MeshLab tools to OpenCode for the scan-to-FreeCAD workflow. CloudCompare handles point clouds and scan comparison. A local PyMeshLab MCP server handles a constrained set of mesh repair operations. The related OpenCode skills explicitly route work to the correct server.

The same change removes Bitwarden Desktop from the declarative NixOS desktop package set. The current machine is `laptop-intel`, and the finished NixOS configuration is built and activated there.

## Scope

- Keep the existing `cloudcompare` and `meshlab` declarations in `modules/desktop/media-creation.nix`.
- Remove only `bitwarden-desktop` from `modules/desktop/browsers.nix`.
- Add global CloudCompare and MeshLab MCP entries to `~/.config/opencode/opencode.json`.
- Run CloudCompare MCP from a pinned Git commit.
- Create a local standards-compliant PyMeshLab MCP project under `~/MCP/MeshLab-MCP`.
- Update `pointcloud-analysis/SKILL.md` and `mesh-repair/SKILL.md` with explicit application and MCP responsibilities.
- Build and activate `.#laptop-intel`.
- Commit and push the intended NixOS repository changes to `origin/main`.

The existing uncommitted `flake.lock` change is not part of this work and must remain unstaged.

## Architecture

### NixOS

`modules/profiles/desktop.nix` already imports both `media-creation.nix` and `browsers.nix` for all desktop hosts. CloudCompare and MeshLab therefore remain declarative system packages. Removing Bitwarden Desktop at the shared desktop module removes it from those hosts without affecting browser packages.

### CloudCompare MCP

OpenCode starts the community CloudCompare MCP server as a local `stdio` server through `uvx`. The source is pinned to a reviewed Git commit rather than an unversioned branch or unavailable PyPI package. `CLOUDCOMPARE_PATH` points to the NixOS-managed executable.

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

`~/MCP/MeshLab-MCP` is a small Python project using the official MCP Python SDK, PyMeshLab, and `stdio` transport. OpenCode starts it through `uv run --project` so dependencies stay isolated from the system Python environment.

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
- Source files are never overwritten by default.
- Failed processing or validation removes temporary output and preserves prior valid artifacts.
- PyMeshLab and CloudCompare failures return the tool name, affected file, relevant parameters, and a concise cause.
- No operation silently falls back to a broader or destructive filter.
- The CloudCompare raw-command tool is not part of normal skill workflows.

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

- Confirm the NixOS-managed CloudCompare executable and version.
- Start the pinned MCP server and verify initialization and `tools/list`.
- Exercise at least one native metadata tool and one CloudCompare-backed operation on a small fixture.
- Validate the merged OpenCode configuration before restart.

### NixOS

- Evaluate the flake without writing the lock file.
- Build `.#nixosConfigurations.laptop-intel.config.system.build.toplevel`.
- Activate with `nixos-rebuild switch --flake .#laptop-intel`.
- Confirm `cloudcompare` is available and `bitwarden` is absent from the active profile.

## Version Control and Deployment

- Stage only files intentionally changed by this work.
- Never stage or alter the pre-existing `flake.lock` modification.
- Commit the design separately from implementation.
- Commit the NixOS package removal after successful build and activation, then push intended commits to `origin/main`.
- OpenCode configuration and files under `~/MCP` and `/home/anders/Projekt/FreeCAD/skills` are outside the NixOS Git repository and are not included in its commits.
- Restart OpenCode after changing its global configuration because MCP configuration is loaded only at startup.
