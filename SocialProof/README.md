# Can Social Proof Fool You?
### How Engagement Metrics Affect AI vs Human Content Detection

A behavioural experiment investigating whether social media engagement (likes) influences people's ability to distinguish AI-generated from human-written LinkedIn posts.

**Presenter:** Vishakha Agrawal | BITS Pilani Hyderabad | 2023101040

---

## Table of Contents

- [Overview](#overview)
- [Research Question & Hypotheses](#research-question--hypotheses)
- [Experiment Design](#experiment-design)
- [Repository Structure](#repository-structure)
- [Setup & Installation](#setup--installation)
- [Running the Experiment](#running-the-experiment)
- [Data & Analysis](#data--analysis)
- [Key Results](#key-results)
- [Limitations](#limitations)
- [References](#references)

---

## Overview

AI-generated text is becoming increasingly indistinguishable from human writing, posing challenges for trust, misinformation, and authenticity online. This project asks: does social proof — specifically, the number of likes on a post — bias how people judge whether content was written by an AI or a human?

We ran a **2×2 within-subjects experiment** (N=35) where participants viewed LinkedIn posts paired with either low (3–50) or high (6,000–50,000) like counts, and judged whether each post was written by an AI or a human. Posts were either real LinkedIn posts (Human/Original) or Claude-rephrased versions (AI/Rephrased).

---

## Research Question & Hypotheses

**RQ:** Does social media engagement (likes) affect people's ability to distinguish AI-generated from human-written content?

| Hypothesis | Description |
|---|---|
| **H1** | High engagement (likes) reduces detection accuracy |
| **H2** | Engagement creates asymmetric errors — more AI→Human misclassifications than Human→AI |
| **H3** | High engagement inflates confidence, decoupling it further from accuracy |

---

## Experiment Design

### Variables

**Independent Variables:**
- `text_version`: Original (Human) vs Rephrased (AI) — *Nominal*
- `likes_level`: Low (3–50 likes) vs High (6,000–50,000 likes) — *Ordinal*

**Dependent Variables:**
- `accuracy`: Whether the participant correctly identified the source — *Binary*
- `confidence_0_100`: Self-reported confidence on a 0–100 slider — *Interval*

**Additional Measures:**
- `dwell_ms`: Time spent viewing the stimulus (ms)
- `rt_ms`: Time taken to respond after seeing the answer page (ms)

### Structure

- **Design:** 2×2 Within-Subjects (all participants saw all conditions)
- **Trials per participant:** 20 (5× Human-Low, 5× Human-High, 5× AI-Low, 5× AI-High)
- **Trial order:** Randomised per participant to prevent order effects
- **Sample:** N=35 students (14M, 21F), age 18–23, recruited from Workspace, THub, and Parijat

### Stimuli

- **Human content:** Real LinkedIn posts by verified authors
- **AI content:** The same posts rephrased by Claude Sonnet 4 (same semantic meaning, similar length)
- **Likes:** Sampled log-uniformly within the Low/High ranges and displayed prominently on the post card

### Trial Flow

```
Consent (1 screen)
    ↓
Instructions (1 screen)
    ↓
┌─────────────────────────────────┐
│  Trial Loop  (×20)              │
│  A. Stimulus: LinkedIn post     │
│     displayed with like count   │
│  B. Response: AI or Human?      │
│     Confidence slider 0–100     │
└─────────────────────────────────┘
    ↓
Completion: Thank you + summary + CSV download
```

---

## Repository Structure

```
SocialProof/
│
├── code/                          # Next.js experiment application
│   ├── src/
│   │   ├── app/
│   │   │   ├── experiment/
│   │   │   │   └── within/
│   │   │   │       └── page.tsx   # Main experiment page (within-subjects)
│   │   │   ├── globals.css
│   │   │   ├── layout.tsx
│   │   │   └── page.tsx           # Landing / home page
│   │   ├── components/
│   │   │   ├── conditions/
│   │   │   │   └── base-posts.tsx # Post stimulus data
│   │   │   ├── experiment-runner.tsx  # Core trial loop logic
│   │   │   ├── experiment-types.ts    # TypeScript types
│   │   │   ├── posts.tsx              # Post rendering component
│   │   │   └── ui/
│   │   │       ├── avatar.tsx
│   │   │       ├── button.tsx
│   │   │       └── card.tsx
│   │   └── lib/
│   │       └── utils.ts
│   ├── public/                    # Static assets
│   ├── next.config.ts
│   ├── tsconfig.json
│   ├── package.json
│   ├── postcss.config.mjs
│   ├── eslint.config.mjs
│   ├── components.json
│   └── README.md
│
├── analysis/
│   └── analysis.ipynb             # Full statistical analysis notebook
│
├── data/
│   └── ai_human_experiment_2025-11-07-04-59-04.csv   # Raw collected data
│
├── flow.py                        # Script to generate experiment flow diagram
└── README.md                      # This file
```

---

## Setup & Installation

### Prerequisites

- Node.js ≥ 18
- npm

### Install & Run the Experiment App

```bash
cd code
npm install
npm run dev
```

The experiment will be available at `http://localhost:3000`. Navigate to `/experiment/within` for the within-subjects condition.

### Generate the Flow Diagram

Requires Graphviz system library and the Python `graphviz` package.

```bash
# Install system dependency (Ubuntu/Pop!_OS)
sudo apt-get install graphviz

# Install Python package
pip install graphviz

# Run
python flow.py
```

This outputs `participant_journey.png` in the current directory.

### Run the Analysis Notebook

```bash
pip install jupyter pandas numpy scipy matplotlib seaborn pingouin
jupyter notebook analysis/analysis.ipynb
```

---

## Data & Analysis

### Data File

`data/ai_human_experiment_2025-11-07-04-59-04.csv`

Each row is one trial. Key columns:

| Column | Description |
|---|---|
| `participant_id` | Anonymous UUID |
| `trial_index` | 0–19 |
| `post_id` | Unique post identifier |
| `source_true` | Ground truth: `Human` or `AI` |
| `text_version` | `Original` or `Rephrased` |
| `likes_level` | `Low` or `High` |
| `likes_value` | Actual like count shown |
| `response_choice` | Participant's answer: `Human` or `AI` |
| `confidence_0_100` | Confidence rating (0–100) |
| `dwell_ms` | Stimulus viewing time (ms) |
| `rt_ms` | Response time (ms) |
| `started_at` | Timestamp |
| `device` | Browser user-agent |

### Statistical Tests

| Hypothesis | Test Used |
|---|---|
| H1 — Engagement effect on accuracy | 2×2 Repeated Measures ANOVA |
| H2 — Error asymmetry | Paired t-test |
| H3 — Confidence-accuracy relationship | Paired t-test + 2×2 RM-ANOVA + Brier Score |
| Exploratory | Signal Detection Theory (d′, c) |

---

## Key Results

| Measure | Result |
|---|---|
| Overall accuracy | 54.4% (barely above chance) |
| Mean confidence | 69.4 / 100 |
| Mean dwell time | 29.6 s |
| Mean response time | 5.7 s |

**H1 — NOT SUPPORTED.** Neither text version (F(1,34)=0.089, p=0.767) nor engagement level (F(1,34)=0.265, p=0.610) had a significant main effect on accuracy. The interaction was marginal (p=0.090) and did not reach significance.

**H2 — NOT SUPPORTED.** AI→Human errors (46.3%) and Human→AI errors (44.9%) were nearly identical. Paired t-test: t(34)=0.299, p=0.767, d=0.050.

**H3 — NOT SUPPORTED.** Confidence was unrelated to correctness (t(34)=−0.236, p=0.815). Participants were overconfident by ~15 percentage points (Brier Score=0.307, worse than chance).

**SDT (Exploratory):** Overall d′=0.223 (close to chance), c=0.018 (no systematic bias). High-likes condition showed slightly higher sensitivity (d′=0.274) vs low-likes (d′=0.173), but the difference was not significant.

---

## Limitations

- Small sample (N=35) — underpowered for small effects
- Convenience sample of students — low generalisability
- Only LinkedIn posts and one AI model (Claude Sonnet 4)
- Lab setting lacks ecological validity of real social media browsing
- AI familiarity and LinkedIn usage were not measured as covariates

---

## References

- Jakesch et al. (2023). Human heuristics for AI-generated language are flawed. *PNAS*.
- Weber-Wulff et al. (2023). Testing of detection tools for AI-generated text. *Int. J. Educational Integrity*.
- Metzger et al. (2010). Social and heuristic approaches to credibility evaluation online. *Journal of Communication*.
- Muchnik et al. (2013). Social influence bias: A randomized experiment. *Science*.
- Zhu et al. (2025). Labels create anti-AI bias in content evaluation.
- Boot, Dijkstra & Zwaan (2021). Processing and evaluation of news content influenced by peer-user commentary. *HSSC*.
- Fleming (2023). Metacognition and confidence. *Annual Review of Psychology*.

---

## License

This project was conducted as part of a course project for Behavioral Research: Experimental Designat IIITH. 