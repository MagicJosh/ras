# How an AI coding agent should research software-project questions (state as of 2026-11-16)

Access legend, used on every citation below. **[opened]** means I read the source text itself on 2026-11-16 (mostly raw files from GitHub, live registry API responses, and the Claude Code docs). **[snippet]** means I only saw a web-search summary of the page and could not open it, because this session's network blocks the host (each such host was tested and refused). Numbers marked [snippet] need checking against the paper before they go into a published skill. The full list of hosts I could not open is in the Gaps of the third question.

## Which sources count for each kind of question, and in what order of trust

### Takeaway
No source I opened publishes a ranked trust order, so the ordering below is my inference from what each primary source says about itself. The primary sources do establish three facts that drive the order: version numbers and changelogs are human promises that are often broken, registry metadata is machine-readable and current, and Stack Overflow answers and LLM answers both have measured error rates.

### Cited Findings
**Version numbers (SemVer 2.0.0)**
- A major version must increase "if any backward incompatible changes are introduced to the public API"; a minor version must increase "if any public API functionality is marked as deprecated". — [SemVer spec, semver/semver](https://github.com/semver/semver/blob/master/semver.md) [opened]
- "Major version zero (0.y.z) is for initial development. Anything MAY change at any time. The public API SHOULD NOT be considered stable." — [SemVer spec](https://github.com/semver/semver/blob/master/semver.md) [opened]
- The spec expects a deprecation path: "there should be at least one minor release that contains the deprecation" before removal in a major release. — [SemVer spec FAQ](https://github.com/semver/semver/blob/master/semver.md) [opened]
- The spec has a FAQ entry for "What do I do if I accidentally release a backward incompatible change as a minor version?", so the spec itself admits that minor releases can break. — [SemVer spec FAQ](https://github.com/semver/semver/blob/master/semver.md) [opened]
- In Python, "A majority of Python projects use a scheme that resembles semantic versioning" but many do not strictly adhere, "since many changes are technically breaking"; some use calendar versioning, where the number says nothing about compatibility. — [PyPA versioning discussion](https://github.com/pypa/packaging.python.org/blob/main/source/discussions/versioning.rst) [opened]

**Changelogs (Keep a Changelog 1.1.0)**
- Change types are Added, Changed, Deprecated, Removed, Fixed, Security. "If you do nothing else, list deprecations, removals, and any breaking changes in your changelog." — [Keep a Changelog source](https://github.com/olivierlacan/keep-a-changelog/blob/main/source/en/1.1.0/index.html.haml) [opened]
- Changelogs are "for humans, not machines", and the author admits a maintainer "may discover that you forgot to address a breaking change in the notes for a version". Pulled releases are marked `[YANKED]`. — [Keep a Changelog source](https://github.com/olivierlacan/keep-a-changelog/blob/main/source/en/1.1.0/index.html.haml) [opened]

**Package registry metadata (retrieved live 2026-11-16)**
- npm: `GET https://registry.npmjs.org/<name>` returns `dist-tags`, `versions`, `time` (with `created`, `modified` and a timestamp per version), `maintainers`, `license`, `repository`, `bugs`. A missing name returns HTTP 404 `{"error":"Not found"}`. — [npm registry: express](https://registry.npmjs.org/express) [opened]
- npm: a deprecated package carries a `deprecated` string on the version. `request@2.88.2` returns "request has been deprecated, see https://github.com/request/request/issues/3142". — [npm registry: request/latest](https://registry.npmjs.org/request/latest) [opened]
- npm: `npm deprecate` updates "the npm registry entry for a package, providing a deprecation warning to all who attempt to install it". — [npm-deprecate docs](https://github.com/npm/cli/blob/latest/docs/lib/content/commands/npm-deprecate.md) [opened]
- PyPI: `GET https://pypi.org/pypi/<name>/json` returns `info` (with `version`, `requires_python`, `requires_dist`, `license_expression`, `project_urls`, `yanked`, `yanked_reason`), `releases`, `urls` (per file `upload_time_iso_8601`, `yanked`) and a top-level `vulnerabilities` list. A missing name returns HTTP 404. — [PyPI JSON: requests](https://pypi.org/pypi/requests/json) [opened]
- PyPI yanking: an installer "MUST ignore yanked releases, if the selection constraints can be satisfied with a non-yanked version"; a yank can be undone later. — [PEP 592](https://github.com/python/peps/blob/main/peps/pep-0592.rst) [opened]
- crates.io: `GET https://crates.io/api/v1/crates/<name>` returns per crate `created_at`, `updated_at`, `downloads`, `recent_downloads`, `max_stable_version`, `repository`, and per version `num`, `yanked`, `yank_message`, `license`, `rust_version`, `created_at`. The API returned HTTP 403 without a User-Agent header and HTTP 200 with one. — [crates.io API: serde](https://crates.io/api/v1/crates/serde) [opened]

**Security advisories**
- `npm audit` posts the name and versions of every package in the tree to the registry's `/-/npm/v1/security/advisories/bulk` endpoint and exits non-zero if any vulnerability is found. `npm audit signatures` verifies registry signatures and provenance attestations. — [npm-audit docs](https://github.com/npm/cli/blob/latest/docs/lib/content/commands/npm-audit.md) [opened]
- OpenSSF Scorecard's Vulnerabilities check uses the OSV (Open Source Vulnerabilities) service to find "open, unfixed vulnerabilities in its own codebase or its dependencies". — [Scorecard checks.md](https://github.com/ossf/scorecard/blob/main/docs/checks.md) [opened]

**Stack Overflow and LLM answers**
- Zhang et al. (IEEE TSE, preprint 2019) studied 52,177 Stack Overflow answer threads: 58.4% of the obsolete answers were probably already obsolete when posted, and only 20.5% of obsolete answers were ever updated. Tags such as node.js, ajax, android and objective-c were more prone. These are shares of the obsolete set, not a site-wide rate. — [arXiv 1903.12282](https://arxiv.org/pdf/1903.12282) [snippet]
- Kabir et al. (CHI 2024, data from March 2023) compared ChatGPT answers to 517 Stack Overflow questions: 52% contained incorrect information, and in a 12-person study participants overlooked the misinformation 39% of the time. — [arXiv 2308.02312](https://arxiv.org/abs/2308.02312v4) [snippet]

### Inferences
These orderings are mine. Each row runs from most to least trusted for that question.
- **Choosing a library or tool**: (1) registry metadata for existence, age, latest release date, deprecation and yank flags, license; (2) the project's repository for license file, release history and issue activity; (3) security advisories (OSV, GitHub Advisory Database, `npm audit`, the PyPI `vulnerabilities` field); (4) official docs for fit to the task; (5) OpenSSF Scorecard individual checks; (6) download counts and stars as weak tie-breakers only; (7) blogs and comparison articles for candidate names only, each name then confirmed at step 1.
- **Diagnosing an error**: (1) the exact error text and stack trace from the project itself; (2) the installed package's source and type signatures at the installed version; (3) the issue tracker searched with the exact error string, reading the version in each report; (4) changelog and release notes between the last working and current version; (5) official docs for the installed version; (6) Stack Overflow, with the answer date and the versions it names checked; (7) blogs.
- **What changed between versions**: (1) the migration or upgrade guide; (2) changelog and release notes for every version in the range, not only the endpoints; (3) the source diff or tag comparison between the two versions; (4) registry flags (deprecated, yanked); (5) the issue tracker for breaks the notes missed; (6) blogs. The version number alone is a hint and not evidence: SemVer permits anything to change in 0.x, and the spec and PyPA both describe projects that break in minor releases.
- A source rule that follows from the above: a claim about an API or a breaking change needs either one primary source that names the version, or a check against the installed code. A Stack Overflow answer, a blog or the model's own memory counts as a lead that names what to check.

### Gaps
- GitHub Advisory Database docs and OSV docs were not opened (osv.dev blocked; the GitHub docs path I tried returned 404). Cargo docs (SemVer compatibility guide, `Cargo.lock`, `cargo yank`): doc.rust-lang.org is blocked and the raw GitHub paths I tried in rust-lang/cargo returned 404, so the Rust rows above rest only on the crates.io API fields.
- I found no study that ranks source types by measured reliability for developer questions. The trust order is a design choice, not a cited result.
- The two Stack Overflow figures are snippet-level; the arXiv pages could not be opened.

## How to verify a finding against the version actually installed, and what goes wrong with docs for a different version

### Takeaway
The lockfile and the installed package directory are the ground truth for "which version", and package managers expose them with documented commands. Benchmarks show that models given a task tied to a specific library version often fail (about half the time on one version-conditioned benchmark, a figure seen only as a search snippet), and that giving version-specific docs helps without fully fixing it.

### Cited Findings
**Where the installed version is recorded**
- `package-lock.json` "describes the exact tree that was generated, such that subsequent installs are able to generate identical trees"; each entry records `version`, `resolved` and `integrity`. — [npm package-lock.json docs](https://github.com/npm/cli/blob/latest/docs/lib/content/configuring-npm/package-lock-json.md) [opened]
- Since npm v7 a hidden lockfile at `node_modules/.package-lock.json` describes what is on disk; it is ignored if another tool changed the tree. — [npm package-lock.json docs](https://github.com/npm/cli/blob/latest/docs/lib/content/configuring-npm/package-lock-json.md) [opened]
- "As of npm v12, `npm-shrinkwrap.json` is no longer read or written by npm." — [npm package-lock.json docs](https://github.com/npm/cli/blob/latest/docs/lib/content/configuring-npm/package-lock-json.md) [opened]
- `npm ls <name>` prints the installed versions and the paths to them, and "will print out extraneous, missing, and invalid packages"; `npm explain` gives the reason a package is in the tree. The tree shown is "the logical dependency tree ... not the physical layout of your `node_modules` folder". — [npm-ls docs](https://github.com/npm/cli/blob/latest/docs/lib/content/commands/npm-ls.md) [opened]
- `npm view <name>@<version> <field>` reads registry data for a named version; without a version it defaults to `latest`. — [npm-view docs](https://github.com/npm/cli/blob/latest/docs/lib/content/commands/npm-view.md) [opened]
- `pip show <name>` prints `Version`, `Location` and `Requires` of the installed distribution; `pip inspect` exists since pip 22.2 (the file I read holds only the version note and a usage directive, so its output format is not confirmed here). — [pip show docs](https://github.com/pypa/pip/blob/main/docs/html/cli/pip_show.rst), [pip inspect docs](https://github.com/pypa/pip/blob/main/docs/html/cli/pip_inspect.rst) [opened]
- The `latest` dist-tag is not the installed version and may not be the newest line a project supports: express currently has `latest: 5.3.0` and `latest-4: 4.22.3` side by side. — [npm registry: express](https://registry.npmjs.org/express) [opened]

**What goes wrong when the version does not match**
- GitChameleon 2.0: "328 Python-based problems" that "are conditioned on specific versions of popular libraries"; the README labels it "ACL 2026, Main". — [GitChameleonBenchmark README](https://github.com/mrcabbage972/GitChameleonBenchmark) [opened]. That each problem is checked by executable hidden tests comes from [arXiv 2507.12367](https://arxiv.org/pdf/2507.12367) [snippet]. Venue conflict: search results also list the same title under neurips.cc/virtual/2025; I could not resolve which is the archival venue.
- GitChameleon 2.0 headline: enterprise models reach baseline success rates of 48-51%; the evaluation also covers agents, code assistants and RAG. — [arXiv 2507.12367](https://arxiv.org/pdf/2507.12367) [snippet]
- "LLMs Meet Library Evolution" (ICSE 2025 research track; arXiv 2406.09834, 2024): 7 LLMs, 145 API mappings from 8 Python libraries, 28,125 completion prompts. — [arXiv 2406.09834](https://arxiv.org/abs/2406.09834) [snippet]
- Same study: all models used deprecated APIs, with the deprecated usage rate reported as 25% to 38% in one secondary review; a simple fix that replaces the deprecated call and regenerates (ReplaceAPI) reached fix rates above 85% for the open-source models. A different aggregator gives "up to 39.2% reduction". The two figures do not match and neither was checked against the paper. — [Moonlight review of 2406.09834](https://themoonlight.io/review/llms-meet-library-evolution-evaluating-deprecated-api-usage-in-llm-based-code-completion) [snippet]
- VersiCode (arXiv 2406.07411, 2024) defines two tasks, version-specific code completion and version-aware code migration; its authors report that GPT-4o and Llama 3 struggle on both. — [arXiv 2406.07411](https://arxiv.org/html/2406.07411v2) [snippet]. The [VersiCode repo](https://github.com/wutong8023/VersiCode) README [opened] confirms only the title and that data and inference code are published.
- LibEvolutionEval (NAACL 2025 long paper; arXiv 2412.04478): 8 libraries (torch, torchvision, scipy, pil, tqdm, pyyaml, matplotlib, pandas). Retrieval of version-specific documentation improves completions "but it does not fully resolve version-dependent biases in the models". — [ACL Anthology 2025.naacl-long.348](https://aclanthology.org/2025.naacl-long.348) [snippet]

### Inferences
A verification procedure the skill can state as steps. The commands are from the docs cited above; the order is mine.
1. Read the version from the lockfile or the installed package before reading any docs: `npm ls <pkg>` or `node_modules/<pkg>/package.json`; `pip show <pkg>`; the entry in `Cargo.lock`, `poetry.lock`, `uv.lock`, `pnpm-lock.yaml` or `yarn.lock`. The manifest range (`^4.1.0`) is not the installed version.
2. For a command-line tool, run `<tool> --version`.
3. Open docs for that version, not the default docs page. Default doc sites and `npm view <pkg>` without a version both describe `latest`.
4. Confirm the symbol exists in the installed code: search the installed package for the function name, or read its type declarations (`.d.ts`, `.pyi`, inline hints) for the real signature.
5. Where it is cheap, run it: import the symbol, call it in a one-line script, or run the type checker or an existing test. A passing run on the installed version outranks any document.
6. State in the answer which version the claim was checked against and how (read, searched, executed).

- Failure modes when docs for another version are used: a call to an API that was removed or renamed; a call to an API that does not exist yet in the installed version; changed defaults or argument order that produce wrong behavior with no error; deprecated calls that work today and warn or break later. The first three are what GitChameleon-style tests catch; the last is what the deprecated-API study measured.
- A model's memory behaves like docs for an unknown older version, so the same check applies to recalled APIs as to web pages.

### Gaps
- Cargo, pnpm, Yarn, Poetry and uv lockfile docs were not opened; the file names in step 1 for those tools come from general knowledge and should be confirmed against each tool's docs.
- Per-model numbers for GitChameleon 2.0 (including how much RAG or self-debugging helped), VersiCode and LibEvolutionEval were not retrieved; only headline claims at snippet level.
- I found no study that measures how often agents with shell access actually check the installed version before answering.

## What is documented about LLM coding assistants inventing APIs or packages, with numbers, and which mitigations are recommended

### Takeaway
The best-documented number is from Spracklen et al. (USENIX Security 2025): 19.7% of packages recommended across 576,000 code samples from 16 models did not exist. A 2026 preprint on newer models reports about 4.6-6.1% (search snippet only, not peer-reviewed), so the rate appears lower and not zero. A name that press reports attribute to that preprint's list was registered on npm on 2026-07-28 (registry record opened). The cheapest mitigation, checking the registry before proposing or installing a package, is a single HTTP request.

### Cited Findings
**Package hallucination**
- Spracklen, Wijewickrama, Sakib, Maiti, Viswanath, Jadliwala, "We Have a Package for You!", USENIX Security 2025: 16 LLMs (commercial and open-source), Python and JavaScript, 576,000 code samples; 19.7% of recommended packages were hallucinations; 205,474 unique hallucinated names. Mitigations evaluated: RAG, self-detection and fine-tuning, with the largest reduction from fine-tuning. — [authors' repository README, Spracks/PackageHallucination](https://github.com/Spracks/PackageHallucination) [opened]
- Same paper, split by model type: average at least 5.2% for commercial models and 21.7% for open-source models. This figure appeared in a library bibliographic record of an earlier arXiv version (2024) and again in a snippet of the Churilov preprint quoting a "5.2%–21.7% spread"; it is the same study as the 19.7% overall figure, not a conflicting one. — paper: [arXiv 2406.10279](https://arxiv.org/abs/2406.10279v3) [snippet, via two secondary records]
- Churilov, "The Range Shrinks, the Threat Remains" (arXiv 2605.17062, May 2026, not peer-reviewed, independent researcher): five frontier models released October 2025 to March 2026, 199,845 samples, hallucination rates 4.62%-6.10%; 127 package names (109 PyPI, 18 npm) were invented identically by all five models. — [alphaXiv 2605.17062](https://www.alphaxiv.org/abs/2605.17062) [snippet]; press coverage [CSO Online](https://www.csoonline.com/article/4201164) [snippet]. One practitioner guide names the models as Claude Haiku 4.5, Claude Sonnet 4.6, Gemini 2.5 Pro, DeepSeek V3.2 and GPT-5.4-mini — [Decryption Digest](https://www.decryptiondigest.com/blog/slopsquatting-ai-hallucinated-packages-supply-chain-attack) [snippet, secondary]. Mirrors disagree on the date (16 May vs 11 June 2026), possibly a revision.
- Only 13.4% of hallucinated names were within edit distance 2 of a real package, so typosquatting checks miss most of them. The search summary named neither the page that carries this number nor which of the two papers it is from, so treat it as unverified. — no citable source (appeared in a search summary whose results included the [Socket glossary](https://socket.dev/glossary/slopsquatting) and the [CSA note](https://labs.cloudsecurityalliance.org/research/csa-research-note-slopsquatting-ai-supply-chain-20260419-csa/)) [snippet]
- Real-world signal I checked directly: the npm package `css-color-stop` exists, was created 2026-07-28T19:22:40Z, and has one version `0.0.0` containing one file of 53 bytes. A Socket write-up is reported to say this name is from the Churilov paper, that it was registered six days after Socket's coverage, and that it was harmless when examined. — [npm registry record](https://registry.npmjs.org/css-color-stop) [opened]; attribution from a search summary of Socket's coverage, exact page not identified [snippet]
- A Cloud Security Alliance research note (April 2026) states that no publicly confirmed mass-exploitation campaign using slopsquatting had been reported at the time of writing, and that AI agents able to install packages should not do so without human review or an allowlist gate. — [CSA research note](https://labs.cloudsecurityalliance.org/research/csa-research-note-slopsquatting-ai-supply-chain-20260419-csa/) [snippet]

**Outdated or wrong API usage**
- Deprecated API usage in completions: reported 25%-38% across 7 models (ICSE 2025 study; snippet-level, see the previous question). — [arXiv 2406.09834](https://arxiv.org/abs/2406.09834) [snippet]
- Version-conditioned tasks: 48-51% baseline success for enterprise models on GitChameleon 2.0. — [arXiv 2507.12367](https://arxiv.org/pdf/2507.12367) [snippet]
- General answer quality: 52% of ChatGPT answers to 517 Stack Overflow questions contained incorrect information (CHI 2024, data from March 2023). — [arXiv 2308.02312](https://arxiv.org/abs/2308.02312v4) [snippet]

**Mitigations named in sources**
- From the research: retrieval of real package lists or version-specific docs (RAG), asking the model to check its own output (self-detection), fine-tuning. — [Spracks/PackageHallucination README](https://github.com/Spracks/PackageHallucination) [opened]
- From practitioner write-ups: check that the package exists before install (`npm view "$pkg" version`), install from a committed lockfile in CI (`npm ci`, `pnpm install --frozen-lockfile`, `yarn install --immutable`), an allowlist or private registry proxy, a cooldown that refuses very new packages. These are secondary sources, mostly vendor or personal blogs. — [CSA research note](https://labs.cloudsecurityalliance.org/research/csa-research-note-slopsquatting-ai-supply-chain-20260419-csa/) [snippet]; [Codex CLI defences write-up](https://codex.danielvaughan.com/2026/06/16/slopsquatting-hallucinated-packages-codex-cli-supply-chain-defence-pretooluse-hooks-lockfile-discipline/) [snippet]
- A registry existence check is mechanically simple: an unknown name returns HTTP 404 from both npm and PyPI. — [npm registry 404 probe](https://registry.npmjs.org/zzz-nonexistent-pkg-ras-probe-9x), [PyPI 404 probe](https://pypi.org/pypi/zzz-nonexistent-pkg-ras-probe-9x/json) [opened]

### Inferences
- Existence alone is not enough. `css-color-stop` now returns HTTP 200, so a bare "does it exist" check passes on a name that models invent. The check has to read the record: creation date, number of versions, file count and size, repository link, maintainer. A package created recently with one empty version is a stop sign.
- Concrete rule set for the skill: (a) never name a package from memory without a registry lookup in the same turn; (b) report the registry facts that were read (latest version, last publish date, first publish date); (c) treat a package younger than some threshold or with a single near-empty version as unverified and say so; (d) never run an install for a package that failed these checks; ask the user.
- The drop from 19.7% (2024-2025 models, many open-source) to about 5% (2026 frontier models) is not a like-for-like trend: the model sets differ and the second study is an unreviewed preprint. The fair statement is "roughly one in twenty recommended packages on current frontier models, per one preprint".
- The same lookup habit covers invented APIs: the registry check proves the package, and the installed-source check from the previous question proves the symbol.

### Gaps
- **Sources I could not open** (host blocked by this session's network policy; all need to be allowed in the session's network settings to verify the snippet-level numbers): arxiv.org, export.arxiv.org, ar5iv.labs.arxiv.org, www.alphaxiv.org, www.usenix.org, www.csoonline.com, labs.cloudsecurityalliance.org, ahrefs.com, tenable.com, themoonlight.io, infosecurity-magazine.com, searchengineland.com, blog.npmjs.org, codex.danielvaughan.com, www.decryptiondigest.com, openreview.net, aclanthology.org, api.semanticscholar.org, huggingface.co, web.archive.org, llmstxt.org, context7.com, semver.org, keepachangelog.com, docs.npmjs.com, packaging.python.org, doc.rust-lang.org, osv.dev, securityscorecards.dev, socket.dev. For semver.org, keepachangelog.com, llmstxt.org, the Scorecard docs and the npm and pip docs I read the same text from the projects' GitHub repositories instead. The web UI of crates.io returned HTTP 403; its API worked with a User-Agent. Separately, the GitHub API refused tree listings for npm/cli, pypa/pip, rust-lang/cargo and github/docs (repository not enabled for this session), so I fetched raw files by guessed path; the guessed paths for the Cargo docs and the GitHub Advisory Database doc returned 404.
- Not confirmed from any source: the often-quoted repeat-rate figures from Spracklen et al. (how often the same invented name recurs across repeated runs). A search for them returned nothing usable, so they are left out.
- The Lasso Security / Lanyado `huggingface-cli` experiment (2024), commonly cited as the first demonstration, did not surface in search and is not cited here.
- One search result claimed a nation-state campaign tied to a June 2026 npm compromise; I could not verify it and it conflicts with the CSA statement above, so it is excluded.
- Which of the two papers (2025 or 2026) the 13.4% edit-distance figure comes from.

## What tools and conventions exist to give agents accurate docs, and what their own docs say about limits

### Takeaway
Three mechanisms exist: llms.txt (a site-published index of markdown docs), documentation servers such as Context7 (third-party index, queried by tool call), and the agent's own fetch tool. Each one's own documentation states a limit that matters for a research skill: llms.txt is curated by the site and carries no version guarantee, Context7 disclaims accuracy and has had an injection flaw, and Claude Code's WebFetch returns a small model's summary and not the page.

### Cited Findings
**llms.txt**
- Proposed by Jeremy Howard on 2024-09-03; the proposal page is now "v2", last modified 2026-08-10. — [llms-txt proposal source](https://github.com/AnswerDotAI/llms-txt/blob/main/nbs/index.qmd) [opened]
- Format: a markdown file named `llms.txt` at the site root or any subpath; the only required part is an H1 with the project name, followed by an optional blockquote summary, free text, and H2 sections holding link lists. A section named "Optional" marks links that can be skipped. Where several files apply, the most specific path wins. — [llms-txt proposal source](https://github.com/AnswerDotAI/llms-txt/blob/main/nbs/index.qmd) [opened]
- Companion convention: each page offers a markdown version at the same URL with `.md` appended or replacing the extension. — [llms-txt proposal source](https://github.com/AnswerDotAI/llms-txt/blob/main/nbs/index.qmd) [opened]
- Stated intent: use at inference time, not training; it is "a curated overview", not a full sitemap. The proposal names OpenAI, Anthropic and Gemini developer docs as publishers and says Chrome Lighthouse audits for the file. — [llms-txt proposal source](https://github.com/AnswerDotAI/llms-txt/blob/main/nbs/index.qmd) [opened]
- Live example: `https://code.claude.com/docs/llms.txt` exists (557 lines), follows the format, and links every page as `.md`, including the changelog. — [Claude Code docs llms.txt](https://code.claude.com/docs/llms.txt) [opened]
- Use by crawlers is disputed. An Ahrefs study of 137,000 sites reported 97% of llms.txt files received zero requests; Google's John Mueller said in June 2025 that no AI system used it. These are SEO-industry sources about crawlers and search, not about coding agents fetching docs on demand. — [Ahrefs llms.txt study](https://ahrefs.com/blog/llmstxt-study/) [snippet]; [Search Engine Land guide](https://searchengineland.com/guide/llms-txt) [snippet]

**Context7 (Upstash)**
- Two modes: a CLI (`ctx7 library <name> <query>`, `ctx7 docs <libraryId> <query>`) and an MCP server with tools `resolve-library-id` and `query-docs`. A version is requested by naming it in the prompt: "Context7 will automatically match the appropriate version." — [Context7 README](https://github.com/upstash/context7) [opened]
- Its own disclaimer: "Context7 projects are community-contributed and while we strive to maintain high quality, we cannot guarantee the accuracy, completeness, or security of all library documentation." — [Context7 README](https://github.com/upstash/context7/blob/master/README.md) [opened]
- Only the MCP server is open source: "API backend, parsing engine, and crawling engine — are private". An API key is "recommended" for higher rate limits; the README gives no numbers. — [Context7 README](https://github.com/upstash/context7/blob/master/README.md) [opened]
- "ContextCrush" (found by Noma Security; dates per a CSA research note: probed 2026-02-18, fixed server-side 2026-02-23, disclosed 2026-03-05): the Custom Rules feature let a library owner inject instructions that reached coding agents unsanitized. No exploitation in the wild was reported. — [Infosecurity Magazine](https://infosecurity-magazine.com/news/contextcrush-ai-development-tools) [snippet]; dates from [CSA research note, 2026-04-28](https://labs.cloudsecurityalliance.org/wp-content/uploads/2026/04/CSA_research_note_ai_powered_supply_chain_wave_20260428-csa-styled.pdf) [snippet]; vendor account at [context7.com/guides/contextcrush](https://context7.com/guides/contextcrush) [snippet, host blocked]

**Claude Code's own tools**
- WebFetch "runs the prompt against the content in a separate model call, and Claude receives the result of that call rather than the raw page ... This makes WebFetch lossy by design ... a result that says a page doesn't mention something may only mean the prompt didn't ask about it." The docs advise a more specific prompt "or use `curl` via Bash for the unprocessed page". — [Claude Code tools reference](https://code.claude.com/docs/en/tools-reference.md) [opened]
- WebFetch reads up to 100,000 characters per call, caches each response for 15 minutes, and does not follow redirects to another host; it returns the target for a second call. — [Claude Code tools reference](https://code.claude.com/docs/en/tools-reference.md) [opened]
- MCP: "Verify you trust each server before connecting it. Servers that fetch external content can expose you to prompt injection risk." Tool output warns above 10,000 tokens and is limited to 25,000 tokens by default (`MAX_MCP_OUTPUT_TOKENS`). — [Claude Code MCP docs](https://code.claude.com/docs/en/mcp.md) [opened]
- The security page lists the WebFetch summary step as one of its prompt-injection safeguards. — [Claude Code security docs](https://code.claude.com/docs/en/security.md) [opened]

**Evidence that supplying docs helps**
- Version-specific documentation as context improves version-specific completions but does not fully remove the model's version bias (LibEvolutionEval, NAACL 2025). — [ACL Anthology 2025.naacl-long.348](https://aclanthology.org/2025.naacl-long.348) [snippet]

### Inferences
- Order of preference for getting docs into context, by how close each is to the installed code: (1) docs and type declarations shipped inside the installed package; (2) docs vendored in the repo; (3) the official site's `.md` page or `llms.txt` for the matching version; (4) a documentation server such as Context7; (5) web search. Levels 4 and 5 need the version cross-check from the second question, because neither guarantees the version served.
- For exact API facts (signatures, flags, defaults), the skill should fetch raw text (`curl` to a `.md` page or a raw GitHub file) and quote it, and use WebFetch for locating and skimming. This follows directly from the tools reference calling WebFetch lossy. In this very session, raw fetches gave verbatim spec text where WebFetch gave a paraphrase.
- Fetched docs are data. ContextCrush shows that a docs channel can carry instructions; the skill should say that text inside fetched documentation never changes what the agent is allowed to do.
- llms.txt does not say which library version its links describe, so a skill must still look for a version in the linked page.
- Absence from a WebFetch answer is not evidence of absence on the page.

### Gaps
- context7.com (docs, pricing, rate limits, its ContextCrush write-up) and llmstxt.org were blocked; llms.txt content was read from its GitHub source instead. Context7 rate-limit numbers are unknown.
- I did not research comparable servers (for example GitHub's MCP server for reading source, vendor-run docs MCP servers, DeepWiki-style tools); no claims are made about them.
- `llms-full.txt` is widely used but the v2 proposal text I read does not define it; I did not confirm where it is specified.
- No independent measurement of Context7's accuracy or version-matching was found.
- The crawler-usage statistics come from SEO vendors and conflict with the proposal's own account of adoption by coding agents; neither side was verified from logs.

## For choosing a library: which health signals are used, and their known pitfalls

### Takeaway
OpenSSF Scorecard is the most complete documented set of health checks, and its own README says the checks are heuristics with false positives and negatives and that the aggregate score "tells you nothing" about individual behaviors. Popularity signals are the weakest: npm download counts are raw tarball requests including bots and mirrors, and one study (arXiv preprint, venue not confirmed here) found millions of suspected fake GitHub stars.

### Cited Findings
**OpenSSF Scorecard**
- Checks and their risk levels: Binary-Artifacts (High), Branch-Protection (High), CI-Tests (Low), CII-Best-Practices (Low), Code-Review (High), Contributors (Low), Dangerous-Workflow (Critical), Dependency-Update-Tool (High), Fuzzing (Medium), License (Low), Maintained (High), Packaging (Medium), Pinned-Dependencies (Medium), SAST (Medium), SBOM (Medium), Security-Policy (Medium), Signed-Releases (High), Token-Permissions (High), Vulnerabilities (High), Webhooks (Critical). — [Scorecard checks.md](https://github.com/ossf/scorecard/blob/main/docs/checks.md) [opened]
- Aggregate score is a weighted average: Critical 10, High 7.5, Medium 5, Low 2.5. — [Scorecard README](https://github.com/ossf/scorecard/blob/main/README.md) [opened]
- Stated non-goal: "The checks themselves are heuristics; there are false positives and false negatives." "Aggregate scores in particular tells you nothing about what individual behaviors a repository is or is not doing ... there's multiple ways of arriving at the same score. These scores change as we add new heuristics or refine the existing ones." — [Scorecard README](https://github.com/ossf/scorecard/blob/main/README.md) [opened]
- Maintained check: archived gives the lowest score; "at least one commit per week during the previous 90 days" gives the highest; the check "will only succeed if a GitHub project is >90 days old". — [Scorecard checks.md](https://github.com/ossf/scorecard/blob/main/docs/checks.md) [opened]
- Its own caveat on maintenance: "a lack of active maintenance is not necessarily always a problem. Some software, especially smaller utility functions, does not normally need to be maintained ... A lack of active maintenance should signal that potential users should investigate further". — [Scorecard checks.md](https://github.com/ossf/scorecard/blob/main/docs/checks.md) [opened]
- Other documented limits: several checks are "currently limited to repositories hosted on GitHub"; Signed-Releases "does not verify the signatures"; Dependency-Update-Tool only detects that a tool is enabled, not that its pull requests are merged; a project using other tools "may still receive" a low score. — [Scorecard checks.md](https://github.com/ossf/scorecard/blob/main/docs/checks.md) [opened]
- Public data: more than 1.3 million repositories scanned weekly; pre-computed scores via a REST API at api.scorecard.dev; the weekly scan omits CI-Tests, Contributors and Dependency-Update-Tool; results are CDN-cached. — [Scorecard README](https://github.com/ossf/scorecard/blob/main/README.md) [opened]
- License check: looks for a license via the hosting API or standard file names; "The lack of a license ... creates a legal risk for potential users." — [Scorecard checks.md](https://github.com/ossf/scorecard/blob/main/docs/checks.md) [opened]

**Registry-level signals (fields confirmed live)**
- Release cadence and age: npm `time` map; PyPI `releases` with `upload_time_iso_8601`; crates.io `created_at`, `updated_at` per version. Deprecation and withdrawal: npm `deprecated`, PyPI `yanked` and `yanked_reason`, crates.io `yanked` and `yank_message`. License: npm `license`, PyPI `license_expression`, crates.io `license`. Known vulnerabilities: PyPI `vulnerabilities`. Runtime floor: PyPI `requires_python`, crates.io `rust_version`, npm `engines`. — [npm registry: express](https://registry.npmjs.org/express), [PyPI JSON: requests](https://pypi.org/pypi/requests/json), [crates.io API: serde](https://crates.io/api/v1/crates/serde) [opened]

**Download counts**
- npm exposes counts at `https://api.npmjs.org/downloads/point/{period}[/{package}]` for last-day, last-week, last-month, last-year or a date range. — [npm registry download-counts docs](https://github.com/npm/registry/blob/main/docs/download-counts.md) [opened]
- npm's own explanation (older npm blog post, now archived; date not confirmed): the stat is a count of HTTP 200 responses that served a tarball, and includes automated build servers and mirrors. — [npm blog: how npm download counts work](https://blog.npmjs.org/post/92574016600/numeric-precision-matters-how-npm-download-counts-work.html) [snippet]
- "Download pumping": Tenable reported that publishing many benign versions triggered mirrors, scanners and bots and raised a package to roughly 50,000 downloads in three days; its advice is not to rely on download counts or version histories to judge legitimacy. — [Tenable blog](https://tenable.com/blog/how-cyberattackers-inflate-malicious-package-npm-download-counts) [snippet]

**Stars**
- "Six Million (Suspected) Fake Stars on GitHub" (arXiv 2412.13459 v2; v1 was titled "4.5 Million"): the StarScout tool found 6.0 million suspected fake stars and 18,617 repositories with fake-star campaigns between July 2019 and December 2024, with a sharp rise in 2024. Fake stars helped a repository only for under two months. The authors note the detections are "suspected" and can include false positives. — [arXiv 2412.13459](https://arxiv.org/html/2412.13459v2) [snippet]

### Inferences
- A usable checklist for the skill, each item tied to a field or check above: (1) exists, and first published long enough ago; (2) last release date and spacing of the last several releases; (3) not deprecated, latest version not yanked; (4) license present and compatible with the project; (5) open advisories for the version that would be installed; (6) runtime floor fits the project (`engines`, `requires_python`, `rust_version`); (7) repository link resolves and is not archived; (8) recent maintainer response on issues; (9) individual Scorecard checks that matter for the use (Maintained, Vulnerabilities, Dangerous-Workflow), not the aggregate; (10) downloads and stars only to compare candidates of similar kind.
- Pitfalls to write into the skill:
  - "No commits lately" can mean finished, not abandoned. Scorecard's own text says to investigate, not to reject.
  - A high Scorecard aggregate can hide a failing critical check, and a low one can come from tools Scorecard does not recognize.
  - Scorecard measures repository practices on GitHub; it says little about API fit, performance or docs quality.
  - Download counts include CI and mirrors and can be pumped; stars can be bought.
  - Many open issues can indicate heavy use; the useful signal is whether maintainers answer.
  - `latest` can lag or lead the line a project should use (express ships 5.x as `latest` and 4.x as `latest-4`).
  - A license field in registry metadata can differ from the license file in the repository; neither was checked for conflict here.
- The skill should report the signals it read with their dates and leave the weighting visible, since every source that defines a signal also warns against a single score.

### Gaps
- No source opened gives thresholds (for example "last release within N months" or "bus factor of at least N"); any threshold in the skill is a design choice.
- deps.dev, Libraries.io/SourceRank, Snyk Advisor, Socket and CHAOSS metric definitions were not researched; securityscorecards.dev and socket.dev were blocked.
- PyPI and crates.io download-count semantics (PyPI download statistics come from a separate BigQuery dataset) were not confirmed from primary docs.
- The npm blog post on download counts and the Tenable and fake-star findings are snippet-level.
- I found no study that links any of these health signals to later outcomes such as abandonment or compromise.
