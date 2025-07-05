# MX Bikes -> FiveM Style Rework Gameplan

This document outlines a proposed path for transforming the existing MX Bikes dedicated server setup into a C/C++ game platform similar in spirit to FiveM. The goal is to reuse as much of the current infrastructure as possible and integrate the components from the SEP Engine documented in `other-project-docs`.

## 1. Assess Current Assets

- **`mxbikes/` directory** – Contains the dedicated server binaries and configuration (`dedicated.ini`, `server_config.ini`, etc.). Use this as reference for networking configuration and gameplay parameters.
- **Container startup scripts** – `scripts/container/startup.sh` automates Wine/Xvfb setup to run the Windows server headless. It also provides environment variables and process management.
- **Web interface** – Minimal Node.js package under `web/`. Could serve as the basis for a management UI or remote admin panel.
- **SEP Engine docs** – `other-project-docs/` describes a modular C++ engine with networking (HTTP API), memory tier system, CUDA acceleration, Blender/Cycles rendering, and audio processing pipelines.

## 2. Determine Reusable Pieces

1. **Server configuration**: Reuse `dedicated.ini` and related config files for initial values (max players, ports). These inform the default configuration of the new dedicated server binary.
2. **Startup container**: Adopt the workflow in `scripts/container/startup.sh` for packaging the server in a Docker container. Replace the call to `mxbikes.exe` with our own dedicated server application once built.
3. **SEP Engine Modules**:
   - `api` for HTTP endpoints and bridging to other languages.
   - `memory` and `quantum` for game state persistence and logic simulation.
   - `audio` and `blender` modules for optional features (voice analysis, in‑game visualization) if desired.
   - Follow the architectural guidelines and dependency flow from `ARCHITECTURE.md`.
4. **SEP client example**: Use `other-project-docs/sep_client.md` as a template for a Node.js admin/monitoring client.

## 3. New Game Architecture Overview

### 3.1 Core Server

- Implement a **C++ dedicated server** built on the SEP Engine foundation.
- Provide networking using a minimal HTTP or WebSocket layer from the `api` module. This becomes the authoritative server for the game world (similar to FiveM's server).
- Integrate configuration parsing logic inspired by `server_config.ini` and existing SEP Engine config patterns.

### 3.2 Game Client

- Create a thin native client in C or C++ that communicates with the server using the SEP API layer (likely via HTTP/WebSocket). Start with simple command-line or minimal graphical capabilities.
- Leverage SEP's `quantum` and `memory` modules for in‑client simulation/visual effects if required.
- Gradually transition to a more sophisticated graphics layer. `blender` integration (Cycles) could render the world for prototyping, but eventually we may want to replace it with a custom rendering pipeline.

### 3.3 Development Workflow

1. **Build SEP Engine**: Follow `other-project-docs/README.md` build steps. Ensure that CUDA support is optional for developer machines without GPUs.
2. **Create a new `server` binary** within a `/src` directory (not yet present) that links against SEP static libraries. Start with simple player connection management and command handling.
3. **Port existing MX Bikes features**: replicate core logic like track loading, vehicle physics (if we have source or open-source alternatives). Otherwise, design a new gameplay loop using SEP's algorithms.
4. **Define data models** using SEP `memory` tiers: Short‑term for current frame state, medium‑term for session data, long‑term for persistent saves.
5. **Implement minimal client**: Mirror the network protocol; implement input capture, update loops, and rendering via a placeholder library (SDL/OpenGL). Use SEP `compat` for GPU acceleration where appropriate.

### 3.4 Asset Pipeline

- Use **Blender** to author and preview assets; adapt the `blender` module's pattern visualization pipeline for quick iteration.
- Manage game resources (tracks, vehicles, etc.) under a new directory structure (`assets/` or `mods/` if reusing existing mods folder).
- For mod support, replicate FiveM's resource system: each mod/resource is a folder with metadata and scripts. SEP's modular layout can host these as dynamic libraries or configuration packages.

### 3.5 Tooling and Scripts

- Maintain container scripts for automated server deployment (extend `scripts/container/startup.sh`).
- Provide Node.js scripts (like `sep_client.js`) for remote administration, log retrieval, or build orchestration.
- Optionally integrate the `web/` interface to present server status and manage mods/plugins.

## 4. Roadmap Phases

1. **Bootstrap**
   - Set up build environment using CMake as outlined in `other-project-docs/README.md`.
   - Compile SEP Engine and produce base libraries.
   - Create a placeholder `server` target that simply accepts connections and echoes data.

2. **Networking & Game Loop**
   - Implement player session management and synchronization over WebSocket or TCP.
   - Adapt SEP's `rate_limit_middleware` and API components for security and stability.
   - Start porting essential game rules from the MX Bikes configs.

3. **Client Prototype**
   - Develop a basic graphical client using SDL/OpenGL.
   - Connect to the server and render simple geometry (placeholders for players and world objects).
   - Gradually add input handling, physics, and asset streaming.

4. **Gameplay & Modding Framework**
   - Design a scripting system or plugin API (Lua/C++). Mirror FiveM's approach of loading resources dynamically.
   - Use SEP's memory tiers for script state and persistence.
   - Provide hooks for mods to request data from the server via the HTTP API.

5. **Advanced Features**
   - Integrate audio capture via SEP `audio` if in-game voice or sound-driven mechanics are desired.
   - Utilize the `blender` module or custom renderer for dynamic visualizations (e.g., track replays or debug views).
   - Explore GPU acceleration for heavy simulation using the SEP `compat` CUDA backend.

6. **Packaging & Deployment**
   - Reuse containerization scripts to ship a ready-to-run dedicated server image.
   - Provide example configuration files derived from the existing `mxbikes` directory.
   - Document the process in this `docs/` folder as we iterate.

## 5. Next Steps

1. Confirm build of SEP Engine on your development machine.
2. Create a new repository module `/src/server` with a minimal main file linking against SEP Core.
3. Experiment with simple client‑server communication using the Node.js sample as a starting point.
4. Begin migrating or rewriting game logic from the MX Bikes server, ensuring we respect any licensing constraints.

This outline leverages the extensive work already documented in `other-project-docs` and reuses the current server tooling where possible. It should serve as a foundation for evolving the project into a full C/C++ game platform.
