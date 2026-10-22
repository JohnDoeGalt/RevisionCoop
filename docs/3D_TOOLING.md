# 3D tooling for RevNet custom bodies

Research date: 2026-10-21. Read-only research: nothing was installed or run. Facts come from
the GitHub API, READMEs, PyPI and vendor pages, fetched on 2026-10-21 (star counts and dates
are as of that fetch). Where I read the source code myself, the entry says "(src)". Where a
fact comes only from a README, a vendor page or a third party, it says so. This file extends
`COOP_IDEAS.md` section 8 and lists corrections to it at the end (section 7).

Goal: custom player models and classes (for example a mechanically augmented class with a new
body) for Deus Ex: Revision (UE1). The art path is: AI generator, then Blender clean-up, then
wrap onto JC's animated mesh (or rig), then bake to vertex frames, then export `_d.3d` /
`_a.3d`, then package as a `.u`.

---

## 0. Recommendation: the minimal free toolset, in install order

Do these in order. Stop after step 3 and prove the round trip before you spend time on AI art.

1. **Blender 4.2 LTS, portable zip, in its own folder** (not your main Blender).
   Reason: Skywolf's UE1 add-on v1.3.8 declares Blender 4.1.1 as its base and reads
   `action.fcurves`, which Blender 4.4+ replaced (slotted actions). An open pull request fixes
   it (17 added lines, section 4.1). Use 4.2 and the released add-on, or patch for 4.4+/5.x.
2. **Skywolf285 UE1-VertexMesh-Blender-IO v1.3.8** (free; no licence declared; reads and writes
   `_a.3d` / `_d.3d`, including the Deus Ex "ION Storm" variant). I read all three of its
   Python files: about 42 KB, imports only `bpy`, `bmesh`, `os`; no network, no subprocess.
3. **UModel (UE Viewer)** (MIT) to pull JC's meshes and textures out of the game packages.
   **Gate test (about 30 minutes):** import `GM_Trench` with format ION, compare it with UModel's
   preview (a 2022 report says Deus Ex meshes came in squashed on Y, section 4.2), export it
   unchanged, `ucc make`, and see it in game. Nothing else matters until this works.
4. **GIMP or Krita, plus ImageMagick** (all free) for the 256-colour palette and `.pcx` step.
5. **A local part generator, only after step 3 passes:** TRELLIS.2 (MIT) through the
   ComfyUI wrapper `visualbruno/ComfyUI-Trellis2` (MIT; I did not confirm Windows support, so
   check its README first, and use WSL2 if it fails), or the Meshy free web plan (100 credits a month, CC BY 4.0, credit Meshy in
   the mod readme). TripoSR (MIT) is the light fallback.
6. **Blender's own tools for clean-up:** Decimate, QuadriFlow, Smart UV Project, Bake,
   Surface Deform. Nothing to install. Instant Meshes (free) is optional.
7. **Let Claude drive Blender with headless scripts, not an MCP.** Commit small
   `blender -b --python` scripts in `tools/` and run them from the Bash tool. This needs no
   add-on, no socket and no extra attack surface. Add an MCP only if you want live viewport
   feedback; first choice is the official Blender Lab MCP (section 2.2), second is
   `mcp-for-blender` pinned with telemetry off (section 2.1).
8. **No skill is required.** If you want one, `majidmanzarpour/blender-game-skills` (section
   3.2) fits best. Scan it with SkillSpector first.

Skip rigging (Mixamo, UniRig, AccuRIG, Meshy rig) for any human-shaped class: wrapping parts
onto JC's mesh gives you JC's 366 baked frames for free. Rigging earns its keep only for a
body that must move differently (tier T3 in `COOP_IDEAS`).

No MCP server, skill or plugin exists for UnrealScript, UE1 or Deus Ex modding (searched
GitHub, glama, mcp.so, general web). Claude can already run `ucc make` through Bash
(`tools/build_net.sh`).

---

## 1. Tables per pipeline step

Legend. Cost: F = free, P = paid. Verdict: USE, OPTIONAL, SKIP, AVOID.

### Step A. Read Deus Ex's stock meshes and textures

| Tool | Cost | Licence | Last activity | Windows / GPU | Verdict |
|---|---|---|---|---|---|
| UModel / UE Viewer | F | MIT | 2,954 stars, last push 2024-03-16 | Win32/Win64 builds, no GPU | USE |
| UE-Explorer (decompile `.u`) | F | GPL-3.0 | 372 stars, 2026-08-15 | Windows | OPTIONAL |
| Tack's DX Mesh Tool v0.02 | F | none stated | archive page, 2000s | old Windows exe | SKIP (legacy) |

### Step B. Generate a part or concept mesh (AI)

| Tool | Cost | Licence / commercial use | Last activity | Windows / GPU | Verdict |
|---|---|---|---|---|---|
| TRELLIS.2 (Microsoft) | F | MIT code and model | 12,372 stars, 2026-07-10 | tested on Linux only; needs 24 GB | USE (via WSL2 or ComfyUI wrapper) |
| ComfyUI-Trellis2 (visualbruno) | F | MIT | 870 stars, 2026-09-25 | Windows not confirmed; 24 GB is the floor | USE (test first) |
| TripoSR | F | MIT | 7,180 stars, 2026-06-04 | ~6 GB per COOP_IDEAS | OPTIONAL fallback |
| Step1X-3D | F | Apache-2.0 | 897 stars, 2025-09-08 | not checked | SKIP |
| Meshy web, Free | F | CC BY 4.0 (commercial with credit) | n/a | web | OPTIONAL |
| Meshy API | P ($20/mo and up) | owned by you on paid plans | n/a | web API | only if needed |
| Tripo web, Free | F | conflicting sources (section 6, item 8) | n/a | web | AVOID until checked |
| Hunyuan3D 2.1 | F | Tencent licence: not valid in EU, UK, South Korea (section 6, item 7) | 4,252 stars, 2025-10-17 | not checked | AVOID |

### Step C. Clean-up: decimate, retopo, UV, bake

| Tool | Cost | Licence | Last activity | Windows / GPU | Verdict |
|---|---|---|---|---|---|
| Blender Decimate, QuadriFlow, Smart UV, Bake | F | GPL | ships with Blender | yes | USE |
| Instant Meshes | F | licence unclear: README has none, GitHub shows "NOASSERTION" | 6,265 stars, last push 2022-01-03 | Windows exe | OPTIONAL |
| Quad Remesher | P | commercial | n/a | n/a | SKIP |

### Step D. Fit to JC's animation (or rig and animate)

| Tool | Cost | Licence | Last activity | Windows / GPU | Verdict |
|---|---|---|---|---|---|
| Blender Surface Deform / Shrinkwrap / Data Transfer | F | GPL | ships with Blender | yes | USE (this is the plan) |
| Rigify | F | GPL | ships with Blender | yes | only for T3 |
| UniRig | F | MIT (GitHub); README states none | 1,865 stars, 2026-06-04 | 8 GB VRAM; Windows not documented | only for T3 |
| Mixamo | F | free with Adobe ID; no raw redistribution; no ML training | web | web | only for T3 |
| AccuRIG 2 | F | free; Reallusion staff say commercial use OK (forum, not EULA) | n/a | Windows only | only for T3 |
| Meshy / Tripo auto-rig | P | see paid list | n/a | web | only for T3 |

### Step E. Textures and the 256-colour palette

| Tool | Cost | Licence | Last activity | Windows / GPU | Verdict |
|---|---|---|---|---|---|
| GIMP, Krita | F | GPL | n/a | yes | USE |
| ImageMagick (`-colors 256`, writes PCX/BMP) | F | open source | n/a | yes | USE |
| Material Maker | F | MIT | 6,013 stars, 2026-10-21 | Windows, GPU | OPTIONAL |
| StableGen (Blender + ComfyUI texturing) | F | GPL-3.0; one non-commercial component (section 4.7) | 957 stars, 2026-10-17 | Windows; 8 to 16 GB VRAM | OPTIONAL |
| ArmorPaint | F source / P binary | zlib; compiled binary $19 on itch.io | 5,395 stars, 2026-10-21 | Windows | SKIP |

### Step F. Bake to vertex frames and export `_d.3d` / `_a.3d`

| Tool | Cost | Licence | Last activity | Windows / GPU | Verdict |
|---|---|---|---|---|---|
| Skywolf285 UE1-VertexMesh-Blender-IO | F | none declared | 24 stars, v1.3.8 2024-12-14; PR for 4.4+ open since 2026-09-28 | any Blender 4.1/4.2 | USE |
| Tack's tools, 3ds2de, unr2de | F | none stated | 2000s | old exes | SKIP (fallback only) |
| DarklightGames io_scene_psk_psa | F | GPL-3.0 | 634 stars, 2026-09-12 | Blender | SKIP (PSK/PSA is skeletal; Deus Ex cannot load it) |
| ASE exporter (extensions.blender.org) | F | GPL-3.0+ | v2.3.2 | Blender 4.2+ | SKIP (static UE1/2 geometry, no vertex animation) |

### Step G. Package, script, build

| Tool | Cost | Licence | Last activity | Windows | Verdict |
|---|---|---|---|---|---|
| `ucc make` via `tools/build_net.sh` | F | game tool | n/a | yes | USE (already in place) |
| UnrealScript-Language-Service (VS Code) | F | MIT | 67 stars, 2026-06-14 | yes | OPTIONAL |
| Die4Ever/deus-ex-randomizer (code reference) | F | GPL-3.0 | 131 stars, 2026-10-13 | n/a | reference only |

### Step H. Agent control (MCP and skills)

| Tool | Cost | Licence | Last activity | Trust | Verdict |
|---|---|---|---|---|---|
| Headless `blender -b --python` via Bash | F | n/a | n/a | highest (nothing to install) | USE |
| Blender Lab MCP (official) | F | GPL-3.0 (Gitea API) | 32 stars, updated 2026-09-29 | high (Blender developers) | OPTIONAL, needs Blender 5.1+ |
| ahujasid mcp-for-blender | F (some features P) | MIT | 31,893 stars, 2026-10-20 | medium (single maintainer, telemetry) | OPTIONAL, pin and configure |
| HoldMyBeer-gg/blenderwright | F | MIT | 175 stars, 2026-10-21 | medium-low (new, one author) | SKIP (duplicate) |
| Meshy MCP | P (API needs Pro) | MIT | 84 stars | medium | only if you pay for Meshy |
| ComfyUI MCPs | F | MIT / Apache-2.0 | see 2.6 | medium | OPTIONAL |
| blender-game-skills | F | MIT | 153 stars, created 2026-09-24 | low-medium (new) | OPTIONAL after scan |

---

## 2. MCP servers: detail

### 2.1 ahujasid/mcp-for-blender (formerly blender-mcp)

- URL: https://github.com/ahujasid/blender-mcp (the repo now reports its name as `mcp-for-blender`).
- Publisher: Siddharth Ahuja (single maintainer). Stated as "not affiliated with the Blender Foundation".
- Does: a Blender add-on (`addon.py`, 287 KB) opens a localhost socket; an MCP server
  (`uvx mcp-for-blender`) exposes 9 tools: `execute_blender_code`, `look` (viewport and
  multi-angle screenshots), `get_scene_info`, `generate_3d` (Tripo, Hunyuan3D, Hyper3D Rodin,
  Meshy), `search_assets` / `import_asset` (Poly Haven CC0, Sketchfab, Poly Pizza),
  `get_addon_status`, `disable_telemetry`, `record_trajectory_feedback`.
- Licence and cost: MIT. The tool is free. Generator back ends need your own paid API keys, or
  the maintainer's paid "Premium" plan (price not found).
- Maintenance: 31,893 stars, 2,893 forks, created 2025-03-07, last push 2026-10-20. PyPI
  `mcp-for-blender` 2.2.2 was uploaded 2026-10-20; dozens of releases in the past six months.
  The old PyPI name `blender-mcp` 2.0.0 is now a shim that installs `mcp-for-blender` at
  startup. COOP_IDEAS links the old name.
- Windows and GPU: Blender 3.0+, Python 3.10+, uv. No GPU use of its own.
- Telemetry and data (checked in `telemetry.py` (src) and the terms file):
  - By default an anonymous record goes to a Supabase backend (anon key embedded in the client):
    install UUID, session ID, tool name, success flag, duration, MCP and Blender version,
    platform. Any one of `DISABLE_TELEMETRY`, `BLENDER_MCP_DISABLE_TELEMETRY` or
    `MCP_DISABLE_TELEMETRY` set to true/1/yes/on turns this off.
  - Prompts, generated code, screenshots and scene data are sent **only if you opt in** (the
    flag lives in the Blender add-on preferences; the server asks Blender for it). Opt-in grants
    the maintainer a "worldwide, royalty-free, perpetual license" for AI training, research and
    open datasets (TERMS_AND_CONDITIONS.md, section 10). Keep it unchecked.
  - This corrects COOP_IDEAS, which says prompts and screenshots are licensed by default.
- Fit: step H, and `generate_3d` for step B. Its `guides/` folder (retopology, rigging) is
  generic. It adds nothing the headless-script route lacks, except live visual feedback.
- Security notes:
  - `execute_blender_code` runs arbitrary Python as you. The README says so. The socket has no
    authentication or encryption. Set `BLENDER_MCP_SAFE_MODE=1` (a 45 KB checker; self-described
    as a guard, not a sandbox). Save the `.blend` first. Do not keep secrets in a Blender
    session that has the add-on running.
  - `premium_hint.py` (src) appends a sentence to the first generation reply of each chat,
    telling the model to mention the paid Premium plan. It is advertising written into tool
    output. Minor, but know it is there.
  - The README's one-line installers (`curl ... | sh`, `irm ... | iex`) are the wrong way to
    install. Use the manual path: `uvx mcp-for-blender==<pinned version> install-addon`, after
    reading the diff for that tag.
  - Releases arrive several times a day at times. Pin an exact version; do not auto-update.
- Scan before install: yes. `skillspector scan https://github.com/ahujasid/blender-mcp --no-llm`
  (it has MCP tool-poisoning and least-privilege checks), then read the flagged lines.

### 2.2 Blender Lab MCP server (official)

- URLs: https://www.blender.org/lab/mcp-server/ and https://projects.blender.org/lab/blender_mcp
  (the repo page returned HTTP 403 to my fetch; the Gitea API worked).
- Publisher: the Blender developers (Blender Lab). Anthropic announced it as an official Claude
  connector on 2026-04-28 and became a Blender Development Fund corporate patron (EUR 240,000 a
  year, per CG Channel). It is open to any MCP client.
- Does: natural-language access to Blender's Python API: explain a scene, check polygon counts,
  rename data blocks, find objects by material, batch edits. Add-on v1.0.3 plus an MCP server,
  installed as an `.mcpb` bundle or from source. Tool list not published on the page.
- Licence and cost: GPL-3.0 (Gitea API); free. 32 stars, updated 2026-09-29.
- Requires Blender 5.1 or newer. It will not run on the 4.2 you need for the UE1 add-on. Run
  both Blender versions side by side, or patch the UE1 add-on for 5.x (section 4.1).
- Telemetry: none mentioned on the page; I did not read the source.
- Security notes: the page itself warns that it runs LLM-written code "without any guards in
  place" and suggests a virtual machine or a machine without sensitive data. Source is
  visible. Highest trust of the Blender MCPs, but the same code-execution power.
- Scan before install: read the bundle's manifest; scan the git repo with SkillSpector.

### 2.3 HoldMyBeer-gg/blenderwright (alternative Blender MCP)

- URL: https://github.com/HoldMyBeer-gg/blenderwright. MIT. 175 stars, created 2026-03-22, last
  push 2026-10-21, 0 open issues. Author named in the licence: "jabberwock".
- README claims (not verified in source): 191 tools in 28 modules; no network requests beyond
  the local socket; zero telemetry; raw Python is off by default and needs a per-session
  checkbox; needs Blender 4.2+; PyPI `uvx blenderwright`; an `install_addon.py` that modifies
  Blender installs.
- Fit: same as 2.1 with a smaller trust base (new, one author) and a 191-tool surface that
  costs context. Only worth it if you dislike 2.1's telemetry.
- Scan before install: yes; read `install_addon.py` before running it.

### 2.4 Meshy MCP

- URL: https://github.com/meshy-dev/meshy-mcp-server (npm `@meshy-ai/meshy-mcp-server`).
  Publisher: Meshy (listed in Meshy's own docs). MIT, 84 stars, created 2026-04-03, last push
  2026-10-22 UTC.
- Does: 28 tools: text, image and multi-image to 3D, retexture, remesh, UV unwrap, rig,
  animate, text-to-motion, format convert, balance check.
- Cost: needs `MESHY_API_KEY`; the README says "Pro plan or above" and Meshy's pricing page
  shows Free has no API. API credit costs: rig 5, animation 3 per action, remesh 5, image to
  3D 20 to 35 depending on model and texture.
- Network: `https://api.meshy.ai` only (configurable). Your images go to Meshy. No telemetry in
  the README; `MESHY_CLIENT` just labels the integrating app.
- Install: `npx add-mcp @meshy-ai/meshy-mcp-server ...` or `npx -y @meshy-ai/meshy-mcp-server`.
  Both run an npm package on your PC. Pin the version.
- Fit: step B and T3 rigging. Not needed for a wrap-onto-JC pipeline.
- Scan before install: yes (the npm tarball or the repo).

### 2.5 Tripo, TRELLIS and Hunyuan3D MCPs

- **VAST-AI-Research/tripo-mcp**: https://github.com/VAST-AI-Research/tripo-mcp. MIT, 219
  stars, last push 2025-04-14 (stale), self-described alpha. Works only through Tripo's Blender
  add-on and `uvx tripo-mcp`. Tripo's API key and terms apply. Skip: stale and thin.
- **FishWoWater/trellis_mcp** (11 stars, no licence, last push 2025-04-06) and
  **FishWoWater/trellis_blender** (75 stars, no licence, last push 2025-12-29, supports
  TRELLIS.2): both need you to run a separate TRELLIS API server from the author's forks. No
  licence means no right to reuse the code. Skip; use the ComfyUI wrapper instead.
- **Hunyuan3D MCPs**: only tiny, unlicensed or `NOASSERTION` repos exist (for example
  `acproject/Hunyuan3D-2.1-mcp`, 3 stars). Skip; the model licence rules it out anyway
  (section 6, item 7).
- **zorrobyte/asset-studio** (0BSD, 63 stars, created 2026-09-13): a local pipeline from text to
  a Qwen-Image reference, then Pixal3D (TRELLIS.2 backbone), then Blender decimation, baked
  textures, LODs and a collision hull, with an MCP front end. Tuned for a 32 GB RTX 5090, Docker
  Desktop on WSL2, about 105 GB of weights, output is static props with no rig. Useful as a
  reference for the "generate, decimate, bake" chain; too heavy and too fresh to adopt. Check
  Pixal3D's and RMBG-2.0's own licences (the README says to).

### 2.6 ComfyUI MCPs (for running TRELLIS.2 and texture workflows from Claude)

- **Comfy-Org `comfy-mcp` (official, local)**: `pip install comfy-mcp`; drives your own ComfyUI.
  Free. No dedicated 3D tool; you supply the workflow. `report_session_summary` shares an
  anonymised summary only with explicit consent (per docs).
  https://docs.comfy.org/agent-tools/mcp
- **Comfy Cloud MCP (official, hosted)**: `https://cloud.comfy.org/mcp`. Needs a subscription to
  run anything (5 free runs for new users). Has a `generate-3d` command. Skip: paid, and your
  images leave the PC.
- **artokun/comfyui-mcp**: MIT, 853 stars, last push 2026-10-19. 80+ tools, npm install.
  **joenorton/comfyui-mcp-server**: Apache-2.0, 411 stars, last push 2026-02-17. Community
  projects; read before use.
- No MCP exists specifically for seamless or PBR texture generation (searched).

### 2.7 Mixamo and rigging MCPs

- **V1xel/mixamo-mcp**: 4 stars, no licence, created 2026-04-05. Playwright drives a logged-in
  Mixamo (Adobe) browser profile saved inside the repo folder; the committed `.mcp.json` holds a
  personal `C:\Users\vital\...` path. AVOID: it hands an agent your Adobe session, there is no
  licence, and the README ignores Mixamo's terms.
- **squall01337/mixamo-llm-mocap**: 393 stars, created 2026-08-17. Video to Mixamo-rig motion
  with GVHMR plus Blender; needs Blender 5.1+, about 8 GB VRAM, about 5 GB of checkpoints. The
  README says MIT with notes for GVHMR and SMPL-X, GitHub shows "NOASSERTION", and SMPL-X needs a
  research registration (check its terms before commercial use). Only relevant to T3.

### 2.8 Other MCPs seen and not recommended

- **LiCinCan/blender-ai-mcp-addon**: AVOID (section 6, item 1).
- **nirholas/3d-agent-mcp** (Apache-2.0, 9 stars): paid calls "settled in USDC via x402".
  Crypto micro-payments inside an agent tool. AVOID.
- **scenario-labs/blender-plugin** (GPL-3.0, 568 stars): front end for Scenario's paid cloud.
  SKIP.
- **Meanerleanerstronger/blender-mcp-plus**, **ssoj13/blender-mcp-rs**, **Oli97430**,
  **djeada**, **cwahlfeldt**: small Blender MCPs seen in listings. Not evaluated; no advantage
  over 2.1 to 2.3.

---

## 3. Claude Code skills and plugins: detail

How I searched: GitHub repository search (names, topics), the Snyk 3D-skills article, glama and
typingmind listings, Anthropic's own repo. `skills.sh` returned only a JavaScript shell (no
list), and I did not reach `skillsdirectory.com`, so those two are not enumerated.

### 3.1 Anthropic's `anthropics/skills`

https://github.com/anthropics/skills. 182,773 stars, no licence field, last push 2026-10-09.
19 skills: documents, design, `mcp-builder`, `skill-creator`, `webapp-testing` and others.
**No Blender, 3D, rigging, UE1 or game-asset skill.** `skill-creator` is the one worth using, if
you decide to write a small RevNet-specific skill (see 3.7).

### 3.2 majidmanzarpour/blender-game-skills (best fit, optional)

- https://github.com/majidmanzarpour/blender-game-skills. MIT. 153 stars, created and last
  pushed 2026-09-24. Author named: Majid Manzarpour.
- One skill, `blender-image-to-3d`, with 8 scripts (`init_master.py`, `review_render.py`,
  `compose_review.py`, `world_gate.py`, `validate.py`, `bake_maps.py`, `export_delivery.py`,
  `roundtrip.py`). Phases: brief, high-detail forms, low-poly retopo with LODs, UVs, bake
  (normal, AO, colour), deformation skeleton and weights, validation (triangle budget, UVs,
  weights, naming), export, round-trip check.
- Needs: Blender 4.2+ (tested on 5.2); Pillow for one script; no API keys, no paid generator, no
  GPU needed. A Blender MCP is optional.
- Install: `npx skills add ...` (the Vercel Labs `skills` CLI, which sends anonymous usage
  telemetry; `DISABLE_TELEMETRY=1` turns it off) or a manual folder copy. Prefer the manual copy
  after a scan.
- Fit: steps C, D (weights), F (validation, budgets). It exports GLB/FBX, so you must tell it the
  Deus Ex limits (8,191 vertices, 8 materials, 256-grid UVs) and use Skywolf's exporter for the
  last step.
- Security: skill scripts run inside Blender's Python with your rights, and the agent writes and
  runs `bpy` code. A README only; I did not read the scripts. Scan with SkillSpector and read
  every `scripts/*.py` before enabling.

### 3.3 Large Blender skill packs (skip)

| Pack | Facts | Why skip |
|---|---|---|
| arjun988/blender-skills | 94 skills, MIT, 374 stars, created 2026-07-05, last push 2026-07-10, author unnamed, needs a Blender MCP, marketplace listing "under review" | Heavy context cost, no baking skill, no vetting trail |
| EL4CTEO/blender-skills | 22 skills, MIT, 340 stars in 7 days (created 2026-10-14), targets Blender 5.2 LTS+, installers write into `~/.claude/skills`, author unnamed | Brand new, version mismatch with the 4.2 plan |
| RobLe3/cc-blender-skill | 29 to 30 skills, MIT, 113 stars, needs an MCP backend, validated on Blender 5.1.1 only | Aimed at reference-image scene building |
| scenario-labs/skills | ~90 skills, MIT repo, 1,083 stars | Needs Scenario's paid cloud MCP; installs unpinned `main` |
| HKUDS/CLI-Anything (Blender harness) | Apache-2.0, 55,934 stars; `pip install cli-anything-blender` | Scene-JSON and render oriented; does not help vertex export |
| Snyk list (DavinciDreams, Jeffallan, etc.) | low stars, general | Not specific to this pipeline |

Snyk's article cites ecosystem studies: prompt injection in 36% of tested skills and 1,467
malicious payloads (Snyk), and SkillSpector's README reports 26.1% of 31,132 skills with
vulnerabilities and 5.2% with likely malicious intent. Treat every third-party skill as code.

### 3.4 UnrealScript, UE1, Deus Ex: skills and tools

No skill or MCP found. Plain tools:

- **EliotVU/UnrealScript-Language-Service**: VS Code language server (highlighting,
  go-to-definition, completion, diagnostics). MIT, 67 stars, last push 2026-06-14, Marketplace
  id `EliotVU.uc`. The README does not say which engine versions it covers; test it on
  Revision's `.uc` files before relying on it.
- **UE-Explorer** (GPL-3.0, 372 stars) and **EliotVU/Unreal-Library** (MIT, 492 stars): decompile
  `.u` packages, UE1 to UE3.
- **Slipyx/UT99** (exported UT99 469b scripts, no licence) and **Die4Ever/deus-ex-randomizer**
  (GPL-3.0): code references.

### 3.5 What I would not build yet

A custom skill for this pipeline is worth writing only after the gate test passes. When it does,
a one-page skill ("how to import, wrap, export, compile") written with `skill-creator` beats any
of the packs above, because the Deus Ex limits are specific.

---

## 4. Non-MCP tools: detail

### 4.1 Skywolf285/UE1-VertexMesh-Blender-IO (core tool)

- https://github.com/Skywolf285/UE1-VertexMesh-Blender-IO. Created 2021-03-29, 24 stars, 5
  forks, 6 open issues. Latest release v1.3.8 (2024-12-14; fixes wrong materials on import);
  previous v1.3.7 (2022-01-26). **No licence declared** (GitHub `license: null`): you may use it;
  do not copy it into the RevNet repo or a release.
- Install: download `io_u_vertex_m.zip` from the release, Blender > Edit > Preferences >
  Add-ons > Install, enable "Unreal Engine 1 Vertex Mesh Format". `bl_info`: Blender (4, 1, 1).
- Blender compatibility: it reads `action.fcurves` (export lines 203 and 208, import line 289),
  which Blender 4.4+ replaced (slotted actions). Open PR #6 (by mikedizhur, 2026-09-28; 3 files,
  +17/-6) switches to `anim_utils.action_get_channelbag_for_slot` and raises the declared
  version to 5.2.2. That PR is not backward compatible with 4.2. Issue #4 asks for newer-Blender
  support. Choice: Blender 4.2 LTS with v1.3.8, or Blender 4.4+ with PR #6 applied locally.
- What the code does (src):
  - **Import:** option `a_format` Automatic / Standard / "ION Storm (Deus Ex)". It loads the
    chosen frame range as absolute shape keys named `Frame0..N` and animates them with one
    `eval_time` curve (so one timeline holds every frame). Options: Import Animation, Create
    Materials, Scale, frame range. It does **not** read sequence names; those live in the game's
    `.uc`. It builds geometry in a per-vertex Python loop, so a 366-frame body is slow (issue #3).
    It opens the `.3d` files in `r+b` mode: import from a copy.
  - **Export:** per frame it calls `evaluated_get(depsgraph).to_mesh()`, so modifiers such as
    Surface Deform are baked into the frames. It raises an error if the vertex count changes
    between frames. Animation source "Actions" produces one named sequence per action and fills
    the `.uc`; "Scene timeline" produces only `ALL` and `Still`, so `MESH SEQUENCE` lines must be
    copied by hand (for example from `AllTNMMeshes.uc`, as COOP_IDEAS says). Material names carry
    texture number, polytype and polyflags (`_TRANSLUCENT`, `_UNLIT`). UVs snap to a 256x256
    grid. Limits: 8,191 vertices for ION (16,383 for standard); positions clamped to
    -128..127 Blender units before scale. The generated `.uc` writes `MESHMAP SCALE
    0.003125` for ION; Revision's Trestkon import uses `0.00390625`. Check which scale your
    base mesh needs.
  - Keep the frame rate low (README suggests 10 to 15 FPS for size).
- Security: three files (about 42 KB), imports only `bpy`, `bmesh`, `os`, `ntpath`; no network or
  subprocess. Low risk. Telemetry: none.
- Fit: step F. Scan: not needed (not a skill); reading the 3 files is enough, and I did.

### 4.2 UModel (UE Viewer)

- https://www.gildor.org/en/projects/umodel, repo https://github.com/gildor2/UEViewer. MIT. 2,954
  stars, last push 2024-03-16 (a third party says the maintainer has gone quiet). Win32/Win64
  builds. Offline tool; no telemetry known.
- Supports Deus Ex vertex meshes ("DeusEx VertMesh support", 2008), exports `.3d`, PSK/PSA, glTF,
  MD5 and textures as PNG/HDR; paletted UE1 textures work.
- Known quirk: a 2022 Gildor forum thread (https://www.gildor.org/smf/index.php/topic,8445.0.html)
  reports that Deus Ex meshes exported to `.3d` and imported with Skywolf's add-on looked too
  thin; the reporter fixed it by scaling Y by 0.5 in Blender. It was never resolved. Use UModel's
  `-uc` option to print the mesh scale, and verify visually in the gate test. The add-on's v1.3.8
  has changed since then, so the problem may be gone.
- Fit: step A. Scan: not a skill; download from the official site and check the hash if offered.

### 4.3 Legacy Deus Ex tools (fallback only)

Tack's Deus Ex Mesh Tool v0.02 (extractor to MilkShape `.ms3d` and LightWave `.lwo`; converter
back to `.3d` unfinished; "pre-Alpha"; one file per frame), `3ds2de` and `unr2de` (DOS/Windows
converters). No licence stated, old unsigned executables from a GameSpy archive mirror. The
PlanetDeusEx pages are still good documentation of the format. Do not run the binaries unless
Skywolf's add-on fails, and then only in a throwaway VM.

"UnrealFX": I found no UE1 mesh tool with this name. If you have a link, send it.

### 4.4 Rigging tools (only for a body that must move differently)

- **Rigify**: ships with Blender. GPL. The T3 route in COOP_IDEAS.
- **UniRig**: https://github.com/VAST-AI-Research/UniRig. MIT per GitHub, 1,865 stars, last push
  2026-06-04. Skeleton and skinning from OBJ/FBX/GLB/VRM; needs 8 GB or more VRAM; installs
  spconv, torch_scatter and flash-attn (hard on Windows; plan on WSL2). The README says the full
  checkpoints are still pending. Output is an armature, which you would still have to animate and
  bake to vertex frames.
- **Mixamo**: free with an Adobe ID. Forum posts (2018 to 2023, not a current EULA) say it is
  royalty-free for commercial projects including games; you may not redistribute the raw
  character or animation files, and may not use it to train ML models. Web only; no API. The
  vertex-frame bake of a Mixamo clip inside a `.u` is a grey area; the wrap-onto-JC route avoids
  the question.
- **AccuRIG 2**: free, Windows only, account needed; a Reallusion forum admin says commercial use
  is allowed for models that contain no Reallusion content. Not the EULA text; check before
  shipping.
- **Meshy and Tripo auto-rig**: paid API (section 5).

### 4.5 AI generators run locally

- **TRELLIS.2**: https://github.com/microsoft/TRELLIS.2. MIT (code and weights; nvdiffrast and
  nvdiffrec carry their own licences). 12,372 stars, created 2025-11-26, last push 2026-07-10,
  160 open issues. README: "tested only on Linux", "at least 24GB" of GPU memory, CUDA 12.4,
  conda. Output: GLB with PBR (opaque by default). Timings on an H100: 3 s at 512, 17 s at
  1024, 60 s at 1536. The 5090 laptop has exactly 24 GB: work at 512 or 1024 and use WSL2 or the
  ComfyUI wrapper's offloading. I did not test a Windows install. Blackwell cards need a PyTorch
  build for CUDA 12.8 or newer; older pinned stacks fail.
- **ComfyUI-Trellis2** (visualbruno, MIT) and **ComfyUI-TRELLIS2** (PozzettiAndrea, MIT, 577
  stars): ComfyUI nodes. StableGen's README names the second as a supported TRELLIS.2 back end
  and lists Windows as supported for StableGen itself; I did not confirm Windows for the nodes.
- **TripoSR** MIT, **TripoSG** MIT (shape only, 1,856 stars, last push 2025-04-18), **Step1X-3D**
  Apache-2.0: alternatives. Quality is below TRELLIS.2, but they are lighter.
- Output of any generator is a dense mesh with AI textures. It still needs decimation to a few
  thousand triangles, new UVs and a bake into a palette (steps C and E). Realistic gain, as in
  COOP_IDEAS: roughly a day saved per part.

### 4.6 Retopo and decimation

Blender's Decimate modifier and QuadriFlow remesher (Object > Quad Remesh in current Blender;
verify the menu name in your version) are enough for parts under 8,191 vertices. Instant Meshes
(https://github.com/wjakob/instant-meshes, 6,265 stars, last push 2022-01-03, Windows exe) gives
cleaner quads on organic shapes; its licence is not stated in the README and GitHub shows
`NOASSERTION`. Use it as a tool only (do not ship it).

### 4.7 Textures

- Deus Ex needs 8-bit paletted textures. Flow: bake in Blender to a small PNG, quantise to 256
  colours with ImageMagick (`magick in.png -colors 256 PNG8:out.png`, or `-remap` to share one
  palette across a skin set), save as `.pcx` or 8-bit `.bmp`, then `#exec TEXTURE IMPORT`.
- AI texturing is of limited use at this size: a 256-colour 256x256 skin loses most generator
  detail. Hand-paint or clean up in GIMP/Krita.
- **StableGen** (https://github.com/sakalond/StableGen): GPL-3.0 Blender add-on; needs a ComfyUI
  back end; SDXL, FLUX.1-dev or Qwen Image Edit; 8 GB (SDXL) to 16 GB+ VRAM; Windows OK; Blender
  4.2 to 4.5 and 5.1+, **not 5.0**. Note: nvdiffrast and nvdiffrec are non-commercial and are used
  only in its "Native" TRELLIS.2 texture mode. FLUX.1-dev has its own non-commercial-leaning
  licence. Models download from Hugging Face on first use.
- **Material Maker** (https://github.com/RodZill4/material-maker): MIT, 6,013 stars, last push
  2026-10-21; Godot-based procedural textures and 3D painting; useful for armour materials.
- **ArmorPaint** (https://github.com/armory3d/armorpaint): zlib licence on the source (free to
  build yourself); the compiled 1.0 release costs $19 on itch.io. Building it needs a toolchain;
  not worth it for 256-colour skins.
- Free CC0 texture sources (Poly Haven, ambientCG) exist; not re-verified in this pass.

---

## 5. Paid options (one line each)

- **Meshy Pro**: $20/month, 1,000 credits, API access, private and customer-owned assets
  (Premium $40 for 3,000; Ultra $100 for 8,000; Studio team $70). Free plan: 100 credits, no API.
  Verified on meshy.ai/pricing.
- **Tripo Pro**: about $19.90/month; Max about $89.90; API about $1 per 100 credits. Figures from
  third-party pages; Tripo's own pricing page returned HTTP 403. Unverified.
- **MCP for Blender Premium**: bundles Meshy, Hunyuan3D, Tripo and Rodin generations without your
  own keys. Price not found (https://mcp-for-blender.com/premium).
- **Hyper3D Rodin** and **Tencent Cloud Hunyuan3D API**: pay-per-use credits through
  `generate_3d`. Price not checked; Hunyuan carries the licence problem in section 6, item 7.
- **Scenario** (scenario.com): subscription cloud used by `scenario-labs/skills`. Price not checked.
- **Comfy Cloud MCP**: subscription needed to run workflows; 5 free runs.
- **ArmorPaint binary**: $19 on itch.io (source is free).
- From memory, not checked: Auto-Rig Pro (about $40), Quad Remesher (about $100), MilkShape 3D
  (shareware, about $35), Substance 3D (subscription). None is needed.

---

## 6. Don't use / red flags

1. **LiCinCan/blender-ai-mcp-addon** ("mcp-for-blender-pro"). The GitHub account was created
   2026-10-15 with one repo and 4 followers; the repo was created 2026-10-15 and shows 975 stars
   and 389 forks six days later; the single release (114 MB zip) has 1 download; the repo is 110
   MB for about 60 KB of visible Python (the rest is a bundled "OpenCode Portable" binary); no
   named author; Windows x64 only; the name copies ahujasid's "MCP for Blender". The README
   admits its code check "is not a security sandbox". Treat as an impersonation or star-inflation
   pattern. Do not install.
2. **nirholas/3d-agent-mcp**: crypto (USDC, x402) payments inside agent tools.
3. **V1xel/mixamo-mcp**: stores a logged-in Adobe browser session in the repo folder, no licence,
   personal path committed.
4. **`curl ... | sh` and `irm ... | iex` installers** (including the README one-liners of the
   Blender MCPs). Install from a pinned tag after reading it.
5. **Unpinned PyPI `blender-mcp`**: a shim that installs another package at startup. Pin
   `mcp-for-blender` to an exact version.
6. **Repos with no licence** (`trellis_mcp`, `trellis_blender`, `mixamo-mcp`, Skywolf's add-on for
   redistribution): no right to copy or ship. Using Skywolf's add-on as a local tool is fine.
7. **Hunyuan3D for anything shipped**: the Tencent Hunyuan 3D 2.1 Community Licence "does not
   apply in the European Union, United Kingdom and South Korea", forbids using outputs outside
   the Territory, forbids using outputs to improve other AI models, and requires labelling
   publicly published machine-generated content. A worldwide mod release breaks it. (This
   confirms COOP_IDEAS' warning.)
8. **Tripo free tier**: sources conflict. Tripo's blog (via a search snippet) says CC BY 4.0 with
   attribution; a price-tracker site says non-commercial. COOP_IDEAS says non-commercial. Check
   Tripo's current terms in a browser before using it. Meshy Free is clear: CC BY 4.0.
9. **Giant skill packs and brand-new high-star repos**: stars can be bought or spiked (340 in 7
   days; 975 in 6 days). Judge by author history, readable source, and a scan.
10. **Any MCP with raw code execution** (`execute_blender_code`): it runs Python as you. All
    Blender MCPs have it. Keep Blender off sensitive folders, save before use, prefer safe
    mode, and close the add-on socket when done. None of the Blender sockets authenticate.
11. **Legacy executables** (Tack's tools, `3ds2de`, `unr2de`): old, unsigned, no licence.
12. **PSK/PSA and ASE tooling**: wrong formats for Deus Ex vertex meshes; do not spend time here.
13. **Ad text inside tool output** (`premium_hint.py` in ahujasid's server): not malicious, but a
    tool that writes instructions into its replies is a prompt-injection surface; read replies.

### Scan before install (SkillSpector)

SkillSpector (NVIDIA) targets skills, but it has MCP tool-poisoning and
least-privilege rules, so use it on MCP repos too. Clone each target into its own new, empty
directory (never inside the worktree), then, from its folder:

```
.venv/Scripts/skillspector.exe scan <dir|SKILL.md|git url|zip> --no-llm --format json --output x.json
```

Read each HIGH finding's lines; the 2026-10-18 scan showed most are keyword false positives.

| Item | Why scan | Priority |
|---|---|---|
| majidmanzarpour/blender-game-skills | skill with 8 scripts that run in Blender | before enabling |
| ahujasid/blender-mcp at the pinned tag | code execution, telemetry, auto-installer | before enabling |
| Blender Lab MCP bundle | code execution (lower trust risk, same power) | before enabling |
| meshy-mcp-server (npm tarball) | runs via `npx` | only if you buy Meshy API |
| comfy-mcp or comfyui-mcp | drives local ComfyUI | if adopted |
| StableGen and ComfyUI node packs | downloads models, runs custom nodes | if adopted |
| Skywolf's add-on | already read (3 files); no scan needed | done |
| Any skill from `npx skills add` | the CLI sends telemetry; copy files manually instead | always |

---

## 7. Corrections and notes for COOP_IDEAS section 8

(Suggestions only. I changed no other file.)

1. The `blender-mcp` repo is now `mcp-for-blender`; the PyPI name `blender-mcp` is a shim. Content
   telemetry is opt-in (default off); an anonymous usage record is on by default unless an env
   var disables it. The current text implies prompts and screenshots are licensed by default.
2. Add the Blender version rule: Skywolf's add-on needs Blender 4.1 or 4.2 as released, or PR #6
   applied for 4.4+/5.x.
3. "Verify first that the add-on's importer brings in all frames": verified in source. It does,
   as shape keys (slow, one timeline); sequence names are not imported.
4. The exporter bakes modifiers per frame, so Surface Deform works. "Scene timeline" mode needs
   hand-written `MESH SEQUENCE` lines; "Actions" mode writes them.
5. Watch the mesh scale: the exporter writes `0.003125` for ION; Revision's Trestkon uses
   `0.00390625`.
6. TRELLIS.2 is Linux-tested and needs 24 GB: a 24 GB laptop is exactly at the limit.
7. Meshy's API needs the Pro plan; the free web plan has no API.

## 8. Not verified

- Tripo's current free-tier terms and pricing (page blocked).
- Real-world TRELLIS.2 on Windows with a 24 GB Blackwell laptop GPU.
- Pixal3D's licence; Instant Meshes' licence text; Blender Lab MCP source and telemetry.
- Whether Skywolf's import still looks Y-squashed on Deus Ex meshes with v1.3.8.
- skills.sh and skillsdirectory.com listings.
- Prices marked "from memory".
