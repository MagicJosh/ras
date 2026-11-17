# Measured evidence on what makes LLM research agents accurate (as of November 2026)

Provenance tags used on every finding:

- **[opened]**: I read the page or file itself in this session (GitHub raw READMEs and result files, one Microsoft Research page).
- **[search summary]**: the number comes from a web-search result summary. I could not open the primary page from this network. Treat these as leads to confirm, not as verified figures. The linked URL is the primary source the summary pointed to.

Network limits in this session: only `github.com`, `raw.githubusercontent.com` and `www.microsoft.com` were reachable for page reads. The full list of hosts that failed is under Gaps in the first section.

## What benchmarks exist for deep research agents, what do they measure, and what do top systems score?

### Takeaway
There are two families: short-answer browsing benchmarks (BrowseComp, BrowseComp-Plus, GAIA, Mind2Web 2) scored by answer match, and report benchmarks (DeepResearch Bench I and II, ResearchRubrics, LiveResearchBench, DRACO, ReportBench, FINDER, DeepResearchEval) scored by rubric plus a separate citation check. On the report benchmarks the best systems still meet well under 70% of expert rubric items, and presentation scores are high while information recall and factual support are low.

### Cited Findings

**DeepResearch Bench (DRB, ICLR 2026)**
- 100 PhD-level tasks (50 Chinese, 50 English) over 22 fields, with the topic mix taken from 96,147 real user queries. [opened] — [DRB README](https://github.com/Ayanami0730/deep_research_bench)
- Two scores. RACE rates report quality on comprehensiveness, insight/depth, instruction-following and readability, with task-specific criteria and weights, scored against a reference report. FACT extracts statement-URL pairs, deduplicates them, scrapes each cited page and has an LLM judge whether the page supports the statement. FACT reports Citation Accuracy (share of citations that are supported) and Effective Citations (supported citations per task). [opened] — [DRB README](https://github.com/Ayanami0730/deep_research_bench)
- Stored result file for Claude 3.7 Sonnet with search: 28.07 citations per task, 24.51 valid, valid rate 0.873; RACE overall 0.4218 (comprehensiveness 0.4110, insight 0.4051, instruction following 0.4621, readability 0.4172). [opened] — [fact_result.txt](https://raw.githubusercontent.com/Ayanami0730/deep_research_bench/main/results/fact/claude-3-7-sonnet-latest/fact_result.txt), [race_result.txt](https://raw.githubusercontent.com/Ayanami0730/deep_research_bench/main/results/race/claude-3-7-sonnet-latest/race_result.txt)
- Original paper figures: Perplexity Deep Research had the highest citation accuracy at 90.24%; OpenAI Deep Research 75.01%; Gemini-2.5-Pro Deep Research had the most effective citations (165) with lower accuracy. The paper notes a trade-off between citation count and citation accuracy. [search summary] — [arXiv 2506.11763](https://arxiv.org/abs/2506.11763)
- The live leaderboard is on Hugging Face, which I could not open. One search summary said the top entry scored 57.00 overall as of 16 April 2026; I did not find that text in the README, so it is unverified. [search summary] — [leaderboard](https://huggingface.co/spaces/muset-ai/DeepResearch-Bench-Leaderboard)
- LangChain's Open Deep Research scored RACE 0.4344 (rank 6 on 2 August 2025) and 0.4943 with GPT-5. [opened] — [open_deep_research README](https://github.com/langchain-ai/open_deep_research)

**DeepResearch Bench II (January 2026)**
- 9,430 binary rubric items taken from expert-written review articles, in three dimensions: information recall, analysis, presentation. Each item is atomic, has explicit numeric tolerances, and is scored 1 (met with valid evidence), 0 (not mentioned) or -1 (mentioned but relies on a blocked reference). 130 tasks are currently scored (tasks 112 and 114 excluded). [opened] — [DRB II README](https://github.com/imlrz/DeepResearch-Bench-II)
- Results: the best system meets fewer than 50% of rubric items. OpenAI o3 Deep Research: recall 39.98, analysis 49.85, presentation 89.16, total 45.40. Gemini-3-Pro Deep Research: 39.09 / 48.94 / 91.85 / 44.60. [search summary] — [arXiv 2601.08536](https://arxiv.org/abs/2601.08536)

**ResearchRubrics (Scale AI, ICLR 2026)**
- Reports are graded against weighted, human-written rubric items. Released code uses binary grading; compliance = Σ(weight × score) / Σ(positive weights); negative-weight items are penalties and are left out of the denominator. [opened] — [researchrubrics README](https://github.com/scaleapi/researchrubrics)
- Best system (Gemini Deep Research) reaches 67.7% compliance; Perplexity Deep Research about 56%. Failures are attributed mainly to missed implicit context and weak reasoning over retrieved material. Response length correlates with compliance only at r ≈ 0.24–0.28. [search summary] — [arXiv 2511.07685](https://arxiv.org/abs/2511.07685)

**LiveResearchBench (Salesforce, ICLR 2026)**
- Expert-curated live tasks across daily life, enterprise and academia (100 tasks per search summary); DeepEval scores five criteria with three protocols (details in the rubric section). [opened, except the task count] — [LiveResearchBench README](https://github.com/SalesforceAIResearch/LiveResearchBench)
- 17 systems tested. Multi-agent systems averaged 69.5 against 62.8 for single-agent web search. Single-agent deep research systems wrote longer reports but had lower citation association and more unsupported claims. Authors' summary: systems act as "deep searchers" more than "deep researchers". [search summary] — [arXiv 2510.14240](https://arxiv.org/abs/2510.14240)

**BrowseComp (OpenAI, April 2025) and BrowseComp-Plus (ACL 2026)**
- BrowseComp: hard-to-find short-answer questions. GPT-4o 0.6%, GPT-4o with browsing 1.9%, o1 9.9%, Deep Research 51.5%. OpenAI notes the Deep Research model was trained on BrowseComp-style data. [search summary] — [openai.com/index/browsecomp](https://openai.com/index/browsecomp/)
- BrowseComp-Plus replaces the live web with a fixed corpus of about 100K human-verified documents so the retriever and the agent can be compared separately. Two LLM judges (GPT-4.1 and Qwen3-32B) differ by under 1% on average. [opened] — [BrowseComp-Plus README](https://github.com/texttron/BrowseComp-Plus), [llm_as_judge.md](https://raw.githubusercontent.com/texttron/BrowseComp-Plus/main/docs/llm_as_judge.md)
- BrowseComp-Plus results: GPT-5 55.9% with BM25, 70.1% with Qwen3-Embedding-8B (and fewer search calls), 59.9% with Google Search API. With all relevant documents handed over, GPT-4.1 reaches 93.49%. [search summary] — [ACL 2026 paper](https://aclanthology.org/2026.acl-long.1023/)

**Mind2Web 2 (NeurIPS 2025)**
- Long-horizon tasks with time-varying answers (130 tasks per search summary). Each task has a judge agent built from a tree-structured rubric that checks both answer correctness and source attribution; agents must give URL sources for critical facts, and cited pages are cached before judging. [opened] — [Mind2Web-2 README](https://github.com/OSU-NLP-Group/Mind2Web-2)
- Best system (OpenAI Deep Research) reaches 50–70% of human performance in about half the time. Full task success up to 28% for agents against 54% for humans. [search summary] — [arXiv 2506.21506](https://arxiv.org/abs/2506.21506)

**ReportBench (ByteDance, August 2025)**
- 100 tasks reverse-engineered from peer-reviewed arXiv survey papers. Scores reference overlap with the survey's own citations, citation match rate for cited statements, and web-checked accuracy of uncited statements. Result table is in the citation section below. [opened] — [ReportBench README](https://github.com/ByteDance-BandAI/ReportBench)

**FINDER and DEFT (OPPO, December 2025)**
- FINDER: 100 human-curated tasks with 419 checklist items. DEFT: 14 failure modes across reasoning, retrieval and generation. [opened] Built from about 1,000 reports. [search summary] — [FINDER_DEFT README](https://github.com/OPPO-PersonalAI/FINDER_DEFT)
- Authors' conclusion: agents fail at evidence integration, verification and planning, not at understanding the task. One fabrication mode is named "strategic content fabrication". [search summary] — [arXiv 2512.01948](https://arxiv.org/abs/2512.01948)

**DeepResearchEval (January 2026)**
- Quality judged on task-specific dimensions; a separate "active fact-checking" agent extracts statements and verifies them by web search even when no citation is given. Best quality score: Gemini-2.5-Pro 8.51/10. Best factual correctness: Manus, 82.3% of statements correct. [opened] — [DeepResearchEval README](https://github.com/Infinity-AILab/DeepResearchEval)

**DRACO (Perplexity, February 2026)**
- 100 tasks from real Perplexity Deep Research requests, 10 domains. Weighted rubrics on factual accuracy, breadth and depth, presentation, citation quality. Perplexity reports its own system on top; an outside write-up says systems now excel at presentation and still struggle with factual accuracy. [search summary] — [arXiv 2602.11685](https://arxiv.org/abs/2602.11685)

**GAIA**
- No single agreed 2026 leaderboard. Princeton HAL board: top agent 74.55% (Claude Sonnet 4.5), Level 3 tops out at 65.39%; human baseline 92%. A vendor self-reports 93.36% on the private test set. [search summary] — [GAIA leaderboard](https://gaia-benchmark-leaderboard.hf.space/)

### Inferences
- Candidate rule: score a research output on two separate axes, report quality and citation support. Every benchmark that measures both finds they diverge (DRB II presentation near 90 with recall near 40; DRB citation count against citation accuracy).
- Candidate rule: do not treat report length or number of citations as a quality signal. ResearchRubrics finds only weak correlation with length, and DRB and LiveResearchBench find more citations or longer reports go with lower support rates.
- Candidate check: a "coverage" check against an explicit list of what the answer must contain is the gap these benchmarks expose most (best recall about 40% on DRB II, 67.7% compliance on ResearchRubrics). A small skill can approximate it by writing the list of required points before searching and ticking them off at the end.
- Benchmark scores depend on the judge model and on training exposure (DRB changed judge twice; OpenAI trained on BrowseComp-style data), so a skill should not quote a leaderboard number as a quality guarantee.

### Gaps
- Hosts I could not open (DNS failure or proxy 403): arxiv.org, export.arxiv.org, browse.arxiv.org, www.arxiv.org, arxiv.gg, ar5iv.labs.arxiv.org, www.alphaxiv.org, huggingface.co, openreview.net, aclanthology.org, api.semanticscholar.org, www.semanticscholar.org, mlanthology.org, deepresearch-bench.github.io, openai.com, cdn.openai.com, www.cjr.org, www.niemanlab.org, www.ebu.ch, www.bbc.co.uk, pmc.ncbi.nlm.nih.gov, www.nature.com, proceedings.neurips.org, hal.cs.princeton.edu, paperswithcode.com, api.openalex.org, doi.org, web.archive.org, r.jina.ai, en.wikipedia.org, www.emergentmind.com, liner.com, papers.cool, www.perplexity.ai, blog.langchain.com. The GitHub API (`gh api`) was also refused for repos outside this session; raw file reads worked.
- No current DRB or DRB II leaderboard table could be read (both are on Hugging Face or agentresearchlab.org). Top scores for late 2026 are unknown to me.
- DeepResearchGym: found no repo or readable page; nothing to report.
- GAIA: no primary leaderboard read; the figures conflict across boards.
- DRB II paper PDF path in the repo (`paper/main.pdf`) returned 404.

## What do studies report about citation accuracy: how often do cited sources fail to support the claim, or not exist?

### Takeaway
Across studies from 2023 to 2026, roughly one citation in four to one in two does not support the claim it is attached to, and the rate has not clearly improved with deep research products. Links that resolve and look on-topic are a poor proxy: one 2026 study reports over 94% working links and over 80% relevant content alongside only 39–77% factual support.

### Cited Findings

**Generative search engines**
- Liu, Zhang, Liang (Stanford, EMNLP Findings 2023), human audit of Bing Chat, NeevaAI, perplexity.ai and YouChat: 51.5% of generated sentences fully supported by their citations; 74.5% of citations support their sentence. [search summary] — [arXiv 2304.09848](https://arxiv.org/abs/2304.09848)
- The released judgment data for that study: of 8,834 training judgments, 6,415 complete support, 1,552 partial support, 867 no support (my arithmetic: 72.6% / 17.6% / 9.8%). [opened] — [repo README](https://github.com/nelson-liu/evaluating-verifiability-in-generative-search-engines)
- Tow Center, Columbia Journalism Review, published 6 March 2025: 8 AI search tools, 200 news excerpts each (1,600 queries), asked to identify the source article, publisher and URL. Over 60% of answers wrong overall. Perplexity 37% wrong, ChatGPT Search 67%, Grok 3 94%. Grok 3 linked to error pages 154 times out of 200; Gemini and Grok 3 gave fabricated or broken URLs in more than half of cases. Paid tiers gave more confidently wrong answers than free ones. Tools rarely used hedging words; Copilot was the exception and declined 104 of 200 queries. Tools also cited syndicated or copied versions instead of the original. [search summary] — [CJR / Tow Center](https://www.cjr.org/tow_center/we-compared-eight-ai-search-engines-theyre-all-bad-at-citing-news.php)
- EBU and BBC, published 22 October 2025, 22 public broadcasters, 18 countries, 14 languages, four assistants: 45% of answers had at least one significant issue; 31% had serious sourcing problems (missing, misleading or incorrect attribution); Gemini had significant issues in 76% of responses. [search summary] — [EBU press release](https://www.ebu.ch/news/2025/10/ai-s-systemic-distortion-of-news-is-consistent-across-languages-and-territories-international-study-by-public-service-broadcaste)
- SourceCheckup (Wu et al., Nature Communications, 16 April 2025), 7 LLMs, 800 medical questions, 58,000 statement-source pairs: for GPT-4o with web search about 30% of individual statements are unsupported and nearly half of responses are not fully supported. The 2024 preprint reported 50–90% of responses not fully supported. The automated verifier agreed 88% with a consensus of three physicians. [search summary] — [Nature Communications](https://pmc.ncbi.nlm.nih.gov/articles/PMC12003634/); method confirmed [opened] in [SourceCheckup README](https://github.com/kevinwu23/SourceCheckup)

**Deep research products**
- DeepTRACE (Venkit et al., listed on Microsoft Research, September 2025, ICLR 2026): eight metrics over answer text, sources and citations, using statement decomposition and a citation matrix against a factual-support matrix. Abstract: deep research modes reduce overconfidence and cite thoroughly, yet stay one-sided on debate queries and leave large shares of statements unsupported; citation accuracy ranges 40–80% across systems. [opened, via page summary] — [Microsoft Research page](https://www.microsoft.com/en-us/research/publication/deeptrace-auditing-deep-research-ai-systems-for-tracking-reliability-across-citations-and-evidence/)
- DeepTRACE per-system: GPT-5 deep research 79.1% citation accuracy, 12.5% unsupported statements, 87.5% citation thoroughness; Perplexity and Copilot deep research 58–62% citation accuracy; Gemini deep research 40.3%. [search summary] — [arXiv 2509.04499](https://arxiv.org/abs/2509.04499)
- Unverified and in tension with the above: a third-party summary says Perplexity deep research had 97.5% unsupported statements. Do not use without checking the paper's table. [search summary] — [arXiv 2509.04499](https://arxiv.org/abs/2509.04499)
- ReportBench table (cited statements checked against the scraped source; uncited statements fact-checked by web-connected LLM vote). [opened] — [ReportBench README](https://github.com/ByteDance-BandAI/ReportBench)

  | System | Citation match rate | Cited statements per report | Uncited-statement accuracy | Reference precision vs expert survey | Recall |
  |---|---:|---:|---:|---:|---:|
  | OpenAI Deep Research | 78.87% | 88.2 | 95.83% | 0.385 | 0.033 |
  | Gemini Deep Research | 72.94% | 96.2 | 92.21% | 0.145 | 0.036 |
  | claude4-sonnet | 73.67% | 14.93 | 92.64% | 0.337 | 0.021 |
  | gemini-2.5-pro | 59.24% | 6.58 | 96.08% | 0.269 | 0.010 |
  | gemini-2.5-flash | 44.88% | 12.1 | 98.52% | 0.237 | 0.012 |
  | o3 | 31.43% | 16.16 | 82.22% | 0.299 | 0.031 |

- "Cited but Not Verified" (Onweller et al., May 2026), 14 models, each citation judged on three axes (link works, content relevant, fact check): frontier models score over 94% on link works and over 80% on relevant content, yet fact-check pass ranges 39–77% (24–77% over the full model set). Models that produce more citations had lower fact-check accuracy (39–59%). [search summary] — [arXiv 2605.06635](https://arxiv.org/abs/2605.06635)
- DRB FACT, two systems' values from the 2025 paper (not a full range): OpenAI Deep Research 75.01%, Perplexity Deep Research 90.24% [search summary] — [arXiv 2506.11763](https://arxiv.org/abs/2506.11763); 87.3% for Claude 3.7 Sonnet with search [opened] — [fact_result.txt](https://raw.githubusercontent.com/Ayanami0730/deep_research_bench/main/results/fact/claude-3-7-sonnet-latest/fact_result.txt)
- DeepResearchEval: best system has 82.3% of statements judged correct by active fact-checking. [opened] — [DeepResearchEval README](https://github.com/Infinity-AILab/DeepResearchEval)
- LiveResearchBench sorts citation errors into invalid links, irrelevant links and unsupported claims; unsupported claims are the most common even in top systems. [search summary] — [arXiv 2510.14240](https://arxiv.org/abs/2510.14240)

### Inferences
- Candidate check: for every cited claim, open the cited page and confirm the specific claim is on it. "URL resolves" and "page is on topic" are not enough; the 2026 three-axis study shows those pass at 94% and 80% while factual support passes at 39–77%.
- Candidate rule: the dominant failure is a real source that does not say what is claimed, not an invented source. Invented or dead links are a second, cheaper check (Tow: over half of Gemini and Grok 3 links broken; LiveResearchBench error type "invalid links").
- Candidate rule: never report a number or attribution seen only in a search snippet as verified. The Tow study's task (match a quote to its article) is exactly the snippet-level attribution that tools get wrong over 60% of the time.
- Candidate rule: cite the original, not a syndicated copy or aggregator (Tow finding), and state when the original could not be opened.
- Candidate rule: require hedged wording or an explicit "could not verify" when support is partial. Tow and DeepTRACE both measure confident wording on wrong or one-sided answers.
- Uncited statements were more often correct (82–98% in ReportBench) than cited statements were supported (31–79%). Reading: the errors concentrate in the claim-to-source link, so the check belongs there.
- A reasonable planning figure for an unchecked agent draft is that 20–40% of citations will not fully support their claim.

### Gaps
- None of the primary papers in this section could be opened, apart from GitHub READMEs and the Microsoft Research abstract page. All percentages tagged [search summary] need confirmation against the papers.
- Not searched: the rate of fully invented (non-existent) sources as a separate number, for example fabricated-reference studies of chatbots. The studies I did find report "link works" or "invalid link" rates instead.
- DeepTRACE per-system table not read; the 97.5% figure is unresolved.
- Tow Center methodology detail (how "partially correct" was counted) not read.

## Which techniques have measured benefit?

### Takeaway
The best-supported gains are from better retrieval and reading the full document, an independent verification pass over drafted claims, and iterative draft-revise loops with retrieval. More searching or more tokens alone is not reliably better: one 2026 preprint (search summary only) reports factual support falling as tool calls rise from 2 to 150, and Open Deep Research's own uncontrolled runs show 3.6 times the tokens for a 0.0035 RACE gain.

### Cited Findings

**Retrieval quality and reading full pages**
- BrowseComp-Plus: swapping BM25 for a strong dense retriever lifts GPT-5 from 55.9% to 70.1% and reduces search calls; with oracle documents GPT-4.1 reaches 93.49%. Retrieval, not reasoning, is the main limit. [search summary] — [ACL 2026 paper](https://aclanthology.org/2026.acl-long.1023/)
- BrowseComp-Plus full-document tool: giving GPT-4.1 a tool to read the full document instead of the truncated preview raised accuracy from 35.42% to 43.61%; the gain was smaller for weaker models. [search summary, secondary site only] — [arXiv 2508.06600](https://arxiv.org/abs/2508.06600)
- A 2026 paper on text ranking in deep research notes that returning truncated documents loses relevant content, and that passage-level retrieval can beat document-level retrieval without a full-document reader. [search summary] — [arXiv 2602.21456](https://arxiv.org/abs/2602.21456)
- gpt-researcher's own benchmark of a context filter on 28 tasks with replayed sources: 73% of kept passages relevant against 46% for embedding filtering. Vendor self-report. [opened] — [gpt-researcher README](https://github.com/assafelovic/gpt-researcher)

**Verification and citation-checking passes**
- Chain-of-Verification (Meta, 2023): draft, plan verification questions, answer them independently of the draft, then revise. FActScore on long-form biographies rose from 55.9 to 71.4 with the factored-and-revise variant. [search summary] — [arXiv 2309.11495](https://arxiv.org/abs/2309.11495)
- CiteFix (Amazon, ACL 2025 industry track): post-processing that re-matches each generated citation against the retrieved articles gave up to 15.46% relative improvement in the system's accuracy metric, and the authors say it would let them use a model about 12 times cheaper and 3 times faster at comparable quality. The best correction method varied by LLM. [search summary] — [arXiv 2504.15629](https://arxiv.org/abs/2504.15629)
- "Do You Need a Frontier Model as a Citation Verifier?" (July 2026): 624 claim-citation pairs, 1,248 human-reviewed judgments; a small model (GPT-5-mini) had the highest source-relevance F1 at 0.908. [search summary] — [arXiv 2607.08700](https://arxiv.org/abs/2607.08700)
- Automated citation judges agree with humans well enough to be used as a check: SourceCheckup verifier 88% agreement with physician consensus [search summary] — [Nature Communications](https://pmc.ncbi.nlm.nih.gov/articles/PMC12003634/); DRB II judge 91.19% three-way accuracy and Cohen's κ 0.80 against human labels on 738 judgments [opened] — [DRB II README](https://github.com/imlrz/DeepResearch-Bench-II)
- DeepSurvey (2026) checks citation-claim alignment after each paragraph; its ablation says removing the refinement stage hurts both content and citation metrics. No numbers seen. [search summary] — [arXiv 2605.29522](https://arxiv.org/abs/2605.29522)

**Iteration, reflection, planning**
- Google's Test-Time Diffusion Deep Researcher (July 2025), win rate against OpenAI Deep Research: backbone agent 39.4% (LongForm Research) and 24.5% (DeepConsult); adding self-evolution of each component 60.9% and 59.8%; adding draft revision with retrieval at each step 69.1% and 74.5%. [search summary] — [arXiv 2507.16075](https://arxiv.org/abs/2507.16075)
- DeepPlanner ablation: removing the explicit planning stage causes short-sighted retrieval and wrong answers. No numbers seen. [search summary] — [arXiv 2510.12979](https://arxiv.org/abs/2510.12979)
- FINDER/DEFT: failures cluster at initial information gathering, intermediate integration and the final cross-check. [search summary] — [arXiv 2512.01948](https://arxiv.org/abs/2512.01948)

**More compute, more searches, more agents**
- BrowseComp: Deep Research accuracy rises smoothly with browsing effort. Running 64 attempts per question and aggregating lifts accuracy by "15–25%" (unclear whether points or relative); picking the answer with the highest self-reported confidence works best, although calibration is poor. Across 64 trials, 16% of tasks were solved every time and 14% never. [search summary] — [openai.com/index/browsecomp](https://openai.com/index/browsecomp/)
- Against that: "Cited but Not Verified" reports fact-check accuracy dropping about 42% on average for two frontier models as tool calls scale from 2 to 150, while link validity and relevance stay flat. [search summary] — [arXiv 2605.06635](https://arxiv.org/abs/2605.06635)
- Open Deep Research on DRB, same research model (GPT-4.1): 58.0M tokens and $45.98 gave RACE 0.4309; 207.0M tokens and $87.83 gave 0.4344. A stronger research model mattered more: GPT-5 0.4943 at 204.6M tokens; Claude Sonnet 4 0.4401 at 138.9M tokens and $187.09. The runs differ in commit and helper models, so this is not a controlled ablation. [opened] — [open_deep_research README](https://github.com/langchain-ai/open_deep_research)
- LiveResearchBench: multi-agent systems average 69.5 against 62.8 for single-agent web search and lead on presentation and citation association; single-agent web search is better on factual and logical consistency. [search summary] — [arXiv 2510.14240](https://arxiv.org/abs/2510.14240)
- A 2026 study of poisoning via user-generated content finds snippet-only retrieval makes injected text more prominent; full-page reading dilutes it and does not remove the risk. [search summary] — [arXiv 2605.24245](https://arxiv.org/abs/2605.24245)

### Inferences
- Candidate rule: open and read the page before citing it; a search result alone is not a source. Supported by the full-document gain on BrowseComp-Plus and by the snippet-attribution error rates in the citation section.
- Candidate check: a separate verification step after drafting, done with fresh context that sees the claim and the source text, not the draft's reasoning. CoVe's gain comes from answering verification questions independently; CiteFix and the verifier-size paper suggest this step can be cheap.
- Candidate rule: stop searching when new results stop changing the answer. Breadth past that point costs factual support (the 2-to-150 tool call result) and tokens (Open Deep Research runs).
- Candidate rule: write a short plan of sub-questions and the required points first, then revise the draft against retrieved evidence at least once. Supported by TTD-DR's stepwise gains and the DEFT finding that failures sit at gathering, integration and final cross-check.
- Candidate rule: prefer better queries and sources over more of them. The retriever swap is a large measured gain (about 14 points), similar in size to the verification-pass gain (CoVe, 15.5 points).
- For a small skill, a second agent is best spent on verification, not on more parallel searching. Multi-agent evidence is mixed: better presentation and citation association, worse consistency.
- Self-reported confidence carries some signal (best-of-N on BrowseComp), so asking the agent to mark low-confidence claims for checking is defensible, with the caveat that calibration is poor.

### Gaps
- I found no controlled ablation that isolates "snippet only" against "full page" on citation accuracy for a deep research report. The BrowseComp-Plus figure is answer accuracy and comes from a secondary summary.
- I found no measured before-and-after for a dedicated citation-checking agent inside a deep research product (for example support rate with and without the pass). CiteFix measures a RAG system's composite accuracy, not report citation support.
- No numbers seen for reflection steps alone, separate from retrieval.
- The 42% drop with more tool calls is from search summaries of one preprint; whether it is relative or absolute is unclear.
- All technique papers here were unreachable; only the Open Deep Research and gpt-researcher figures were read directly.

## What evaluation rubrics do builders use for research output (criteria and how they are scored)?

### Takeaway
Builders have converged on two layers: a claim-level citation check (extract claim-source pairs, fetch the source, judge support, report a rate) and a rubric for the report (coverage against a task-specific checklist, analysis depth, instruction following, presentation). Binary or three-way atomic checklist items scored by an LLM judge agree best with humans; holistic 1–10 scores are used less for anything factual.

### Cited Findings

**Claim-level citation checks**
- DRB FACT: extract statement-URL pairs, deduplicate, scrape the page, LLM judges support or not. Outputs Citation Accuracy and Effective Citations per task. Judge is a small model (GPT-5.4-mini; earlier Gemini-2.5-Flash). [opened] — [DRB README](https://github.com/Ayanami0730/deep_research_bench)
- ReportBench: cited statements are checked by scraping the source and having an LLM locate the supporting passage; uncited factual statements (common knowledge filtered out) are fact-checked by several web-connected LLMs with a majority vote. [opened] — [ReportBench README](https://github.com/ByteDance-BandAI/ReportBench)
- "Cited but Not Verified": three questions per citation: does the link work, is the content relevant, does it support the fact. [search summary] — [arXiv 2605.06635](https://arxiv.org/abs/2605.06635)
- HKUDS DeepResearch-ReportEval: three-way support label per claim against the scraped page: -1 not supported, 0 uncertain, 1 supported, with the supporting evidence quoted. [opened] — [DeepResearch-Eval README](https://github.com/HKUDS/DeepResearch-Eval)
- Liu et al. labels: complete support, partial support, no support. [opened] — [repo README](https://github.com/nelson-liu/evaluating-verifiability-in-generative-search-engines)
- DeepTRACE's eight dimensions cover answer text (one-sidedness, overconfidence, relevance of statements), sources (uncited sources, source necessity) and citations (accuracy, thoroughness, unsupported statements), computed from a citation matrix and a factual-support matrix. [opened, via page summary, for the framework; search summary for the metric names] — [Microsoft Research page](https://www.microsoft.com/en-us/research/publication/deeptrace-auditing-deep-research-ai-systems-for-tracking-reliability-across-citations-and-evidence/)
- DeepResearchEval active fact-checking verifies statements by fresh web search even where the report gives no citation. [opened] — [DeepResearchEval README](https://github.com/Infinity-AILab/DeepResearchEval)
- Mind2Web 2: pages cited in an answer are cached first, then a task-specific judge agent walks a rubric tree checking correctness and attribution together. [opened] — [Mind2Web-2 README](https://github.com/OSU-NLP-Group/Mind2Web-2)

**Report rubrics**
- DRB RACE: four dimensions (comprehensiveness, insight/depth, instruction-following, readability); criteria and weights generated per task; scored relative to a reference report. [opened] — [DRB README](https://github.com/Ayanami0730/deep_research_bench)
- DRB II: binary atomic rubric items in three dimensions (information recall, analysis, presentation), written from expert articles through LLM extraction, self-check against the source article, manual revision and expert review. Score per item 1 / 0 / -1. Judged in batches of 50 items. [opened] — [DRB II README](https://github.com/imlrz/DeepResearch-Bench-II)
- ResearchRubrics: weighted items tagged by axis (for example "Explicit Criteria"), binary Satisfied / Not Satisfied in the released code (the paper also reports a ternary variant [search summary]); negative-weight items penalise unwanted content. Compliance = Σ(weight × score) / Σ(positive weights). [opened] — [researchrubrics README](https://github.com/scaleapi/researchrubrics)
- LiveResearchBench DeepEval picks the protocol per criterion from a human-alignment study. [opened] — [LiveResearchBench README](https://github.com/SalesforceAIResearch/LiveResearchBench)
  - Checklist, binary per item: Presentation (10 fixed questions) and Coverage (custom checklist per query).
  - Error counting, score 10–100 by number of issues: Factual and Logical Consistency (count contradictions) and Citation Association (count missing citations).
  - Pairwise comparison with position swap: Analysis Depth, on granularity, insight, critique, evidence, density.
- HKUDS ReportEval: five scored dimensions (comprehensiveness, coherence, clarity, insightfulness, overall) plus a redundancy score from sampled paragraph pairs. [opened] — [DeepResearch-Eval README](https://github.com/HKUDS/DeepResearch-Eval)
- FINDER: checklist pass rate over 419 items; DEFT assigns each report failure modes from a 14-item taxonomy. [opened] — [FINDER_DEFT README](https://github.com/OPPO-PersonalAI/FINDER_DEFT)
- DRACO: weighted task-specific rubrics over factual accuracy, breadth and depth, presentation, citation quality; reports normalized score and pass rate. [search summary] — [arXiv 2602.11685](https://arxiv.org/abs/2602.11685)

**How well LLM judges track humans**
- DRB RACE: human inter-annotator agreement 68.78%; the three candidate judges scored 70.11–71.82 overall agreement with humans on 200 articles, GPT-5.5 highest. [opened] — [DRB README](https://github.com/Ayanami0730/deep_research_bench)
- DRB II binary rubric judging: 91.19% three-way accuracy, κ 0.7993, task-level Pearson r 0.9587 for GPT-5.5 on 738 judgments from 10 reports; Claude Opus 4.8 83.33%, κ 0.6479. The authors call this a small-scale study. [opened] — [DRB II README](https://github.com/imlrz/DeepResearch-Bench-II)
- BrowseComp-Plus short-answer judging: two different judge models differ by under 1% on average. [opened] — [llm_as_judge.md](https://raw.githubusercontent.com/texttron/BrowseComp-Plus/main/docs/llm_as_judge.md)

### Inferences
- Candidate self-check for the skill, taken from the common core of these rubrics:
  1. Every factual claim has a source, or is marked as the agent's own inference.
  2. Every cited source was opened, and the claim is found in it (label: supported / partly / not supported / could not open).
  3. Links resolve.
  4. The required points listed at planning time are each answered or listed as a gap.
  5. No internal contradictions between sections.
  6. Conflicting sources are shown, not silently resolved (DeepTRACE one-sidedness).
  7. Confidence wording matches the support label.
- Use atomic yes/no items, not a 1–10 impression. An LLM judge matched human labels on atomic rubric items at 91.19% with κ 0.80 (DRB II, small study), and LiveResearchBench chose binary checklists for coverage and presentation after its human-alignment study. The DRB RACE agreement figures (about 70–72, against a 68.78% human baseline) are a different metric and are not directly comparable.
- Report the support rate as a number in the output ("N of M cited claims confirmed on the page") the way FACT does; it is cheap and is the metric every benchmark converged on.
- Keep presentation checks minimal. Presentation is the one dimension where current systems already score 84–92% (DRB II), so it is not where errors are.
- A three-way label with an explicit "uncertain / could not open" value fits a constrained network better than a binary one, and matches HKUDS and Liu et al.

### Gaps
- The exact rubric prompts (judge instructions) were not read for any benchmark; only README-level descriptions.
- ResearchRubrics axis list and the share of negative-weight items were not read (dataset is on Hugging Face).
- DRACO rubric mechanics (weights, penalty items) not found.
- DeepTRACE's eight metric definitions come from summaries, not the paper.
- I found no lab engineering post in this pass, other than the excluded Anthropic ones, that publishes a scored rubric with results; OpenAI and Perplexity pages were unreachable.
