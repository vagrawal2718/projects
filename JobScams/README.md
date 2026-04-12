# Understanding Job Scam Victimization: A Behavioral Economics Perspective

> **Authors:** Goni Anagha (2023101124) · Vishakha Agrawal (2023101040)  
> **Institution:** IIIT Hyderabad  
> **Course — Introduction to Neuroeconomics**

---

## Table of Contents

- [Overview](#overview)
- [Research Questions & Hypotheses](#research-questions--hypotheses)
- [Methodology](#methodology)
- [Repository Structure](#repository-structure)
- [Data](#data)
- [Analysis Notebooks](#analysis-notebooks)
- [Key Findings](#key-findings)
- [Proposed Interventions](#proposed-interventions)
- [Setup & Usage](#setup--usage)
- [Limitations](#limitations)
- [References](#references)

---

## Overview

Job scams represent an increasingly sophisticated form of cyber-enabled fraud. While most research focuses on technical detection, this study takes a **human-centered, behavioral economics perspective** — asking not just *what* scams look like, but *why* intelligent, educated individuals fall for them even when warning signs exist.

This project investigates two primary job scam typologies through the lens of behavioral economics:

| Scam Type | Description |
|---|---|
| **Pay-to-Get-a-Job** | Victims pay upfront fees (registration, training, refundable deposits) to secure employment that never materialises |
| **Task-Based** | Victims complete simple micro-tasks (product rating, app optimization) and receive real initial payments, before being asked to invest their own money to "unlock" higher tasks — which never pay out |

Cryptocurrency losses to job scams hit **$41 million in H1 2024** — nearly double all of 2023 — highlighting the urgency of understanding the psychological mechanisms that make people vulnerable.

### Core Argument

Vulnerability to job scams is **not** primarily a consequence of informational deficits or technical deception. It is **systematically driven by predictable cognitive biases** — specifically the sunk cost fallacy, loss aversion, and social proof — that influence judgment under uncertainty. Traditional cybersecurity frameworks (detection, awareness campaigns, technological safeguards) fail to address these behavioral mechanisms.

---

## Research Questions & Hypotheses

### Primary Research Question
> Do cognitive biases — specifically sunk cost fallacy, loss aversion, and social proof — predict payment decisions in job scam encounters?

### Hypotheses

| ID | Hypothesis |
|---|---|
| **H1** | Higher sunk cost influence is associated with higher payment likelihood |
| **H2** | Fear of losing opportunity (loss aversion) is associated with payment |
| **H3** | Urgency/time pressure (loss aversion) is associated with payment |
| **H4** | Financial vulnerability moderates the relationship between loss aversion and payment |
| **H5** | Social proof influence is associated with payment likelihood |
| **H5a** | Social proof effects are stronger among younger participants |
| **H5b** | Professional appearance and social proof elements interact multiplicatively on payment |

### Secondary Research Questions (Missing Data Analysis)

| RQ | Question |
|---|---|
| RQ1 | Do scam victims differentially avoid disclosing financial information? |
| RQ2 | Does emotional distress predict disclosure avoidance? |
| RQ3 | Do emotions predict reporting behaviour? |
| RQ4 | Do emotional profiles differ by scam type? |
| RQ8 | Does survey fatigue explain missingness? |
| RQ9 | Are missingness patterns correlated across sensitive items? |

---

## Methodology

### Survey Design

- **Platform:** Google Forms (anonymous, no PII collected)
- **Target population:** IIIT Hyderabad community — students, faculty, staff, alumni, and their networks
- **Recall window:** 12-month look-back for scam encounters

### Survey Structure (8 Sections with Conditional Branching)

```
Section 0: Consent
    ↓
Section A: Demographics & Socioeconomics
    ↓
Section B: Scam Awareness & Exposure
    ├── Encountered scam? → Section C (Encounter Details)
    │       ├── Payment-based → Section C1 (detailed payment variables)
    │       ├── Task-based   → Section C2 (detailed task variables)
    │       └── Other/Unsure → Section Z (open narrative)
    │           ↓
    │       Section D: Aftermath (emotions, reporting)
    └── No encounter → Section E (Safety Behaviours & Risk Perception)
    ↓
Debrief (resources + thank you)
```

### Key Measured Variables

**Independent Variables (Psychological Mechanisms)**
- Sunk cost influence (1–5 Likert scale)
- Fear of losing opportunity (binary checkbox)
- Urgency/time pressure (binary checkbox)
- Social proof influence (1–5 Likert scale)
- Financial vulnerability composite (0–4 score)

**Dependent Variable**
- Payment decision (binary: made payment vs. did not pay)

**Additional Measures**
- Engagement level (none / brief / including payment)
- Emotional aftermath (anger, anxiety, embarrassment — 1–5 scales)
- Reporting behaviour (binary + platform)
- Risk perception (3 hypothetical scenarios, 1–5 scale)
- Verification behaviours (7-item checklist)

### Analytical Methods

| Analysis | Method |
|---|---|
| Descriptive statistics | Frequency distributions, cross-tabulations |
| Sunk cost → payment | Fisher's Exact Test, Binary Logistic Regression (L2-regularised), Bayesian Bootstrap, Propensity Score Matching, Mann-Whitney U |
| Loss aversion → payment | Fisher's Exact Test, Odds Ratios, Risk Ratios, Hierarchical Logistic Regression |
| Social proof → payment | Mann-Whitney U, Spearman correlation, Mediation analysis (Baron & Kenny), Random Forest feature importance |
| Emotion classification | NLP sentiment analysis on open-text narratives |
| Missing data | Spearman correlation (fatigue), missingness correlation matrix, chi-square |
| Signal detection | Random Forest classifier for feature importance ranking |

---

## Repository Structure

```
JobScams/
│
├── 16_data_2023101124_2023101040.xlsx          # Raw survey response data
│
├── 16_QA_2023101124_2023101040.xlsx            # Q&A from presentation
│
├── 16_form_flow_2023101124_2023101040.jpeg     # Survey conditional flow diagram
│
├── 16_ppt_2023101124_2023101040.pptx           # Presentation slides
│
├── 16_report_2023101124_2023101040.pdf         # Full research report (39 pages)
│
└── 16_code_2023101124_2023101040/              # Analysis notebooks
    ├── 16_Descriptive_Statistics_2023101124_2023101040.ipynb
    ├── 16_2023101124_sunk_cost_analysis_2023101040.ipynb
    ├── 16_Loss_Aversion_&_Framing_Effects_2023101124_2023101040.ipynb
    ├── 16_social_proof_analysis_2023101124_2023101040.ipynb
    ├── 16_Sentiment_Analysis_2023101124_2023101040.ipynb
    └── 16_missing_data_analysis_2023101124_2023101040.ipynb
```

---

## Data

**File:** `16_data_2023101124_2023101040.xlsx`

**Sample:** N = 96 consenting respondents | 37 (38.5%) reported scam encounters | 16 (16.7%) made payments

**Demographics:**
- ~84.5% current students; age 18–24 dominant
- ~64.8% reported no personal income (students)
- ~75.8% used company websites/LinkedIn for verification
- Recruited from IIIT Hyderabad and extended network

**Key columns (selected):**

| Column | Description |
|---|---|
| `Timestamp` | Response datetime |
| `Community relation` | Student / Faculty / Alumni / etc. |
| `Age band` | Categorical age ranges |
| `Household financial situation` | Comfortable / Manageable / Struggling / In debt |
| `In the past 12 months, have you personally encountered...` | Encounter screening (Yes / No / Unsure) |
| `How much did social proof...influence your decision` | 1–5 scale |
| `How much did the time and effort...influence your decision` | 1–5 scale (sunk cost) |
| `Did you engage with it at all?` | Engagement level |
| `Total amount paid (approx.)` | Binned INR ranges |
| `What affected you to pay at the time?` | Multi-select: urgency, fear, social proof, etc. |
| `After this experience, how much did you feel: Anger/Anxiety/Embarrassment` | 1–5 scales |
| `Did you report this experience anywhere?` | Binary |
| `How risky do you perceive this scenario to be?` (×3) | 1–5 risk scenarios |

---

## Analysis Notebooks

### 1. `16_Descriptive_Statistics_...ipynb`
Pure descriptive analysis across four groups:
- **Group 1:** Sample overview, demographics, scam awareness
- **Group 2:** Encounter details, payment behaviour, engagement funnel
- **Group 3:** Psychological influence factors, scammer tactics, financial loss
- **Group 4:** Outcomes, cross-tabulations, behavioural patterns

### 2. `16_2023101124_sunk_cost_analysis_...ipynb`
Tests H1 — whether prior investment (time/effort/interactions) predicts payment:
- Fisher's Exact Test with sensitivity analysis across threshold definitions (≥2.5 to ≥4.0)
- Bayesian Bootstrap posterior distribution
- Propensity Score Matching (PSM) for confound control
- L2-regularised logistic regression (Models 1–3)
- Random Forest feature importance

### 3. `16_Loss_Aversion_&_Framing_Effects_...ipynb`
Tests H2, H3, H4 — fear of opportunity loss and urgency as payment predictors:
- 2×2 contingency tables (fear/urgency × payment)
- Fisher's Exact Test, Odds Ratios, Risk Ratios, Cohen's h
- Stratified analysis by financial vulnerability
- Hierarchical logistic regression with interaction term
- Multivariate comparison of loss aversion vs. sunk cost

### 4. `16_social_proof_analysis_...ipynb`
Tests H5, H5a, H5b — social proof and legitimacy signals:
- Mann-Whitney U comparing payers vs. non-payers on social proof ratings
- Age moderation (Spearman ρ in ≤24 vs >24 groups)
- Professional appearance × social proof multiplicative interaction
- Mediation analysis (trust susceptibility as mediator)
- Random Forest feature importance for relative predictor comparison

### 5. `16_Sentiment_Analysis_...ipynb`
NLP emotion classification on open-text victim narratives:
- Emotion extraction from free-text responses (anger, fear, joy, sadness, surprise, disgust)
- Comparison of emotion distributions by scam type and reporting behaviour
- Chi-square / Fisher's Exact tests for emotion-reporting association
- Cross-tabulation of emotions by scam type (payment-based vs. task-based)

### 6. `16_missing_data_analysis_...ipynb`
Structural and psychological analysis of non-response:
- Spearman correlation between question position and missingness rate (survey fatigue test)
- Missingness rates by question type (open-ended, financial, emotional, demographic)
- Correlation matrix of missingness indicators for sensitive items
- Stratified missingness by scam type and vulnerability group

---

## Key Findings

### Overall Sample
| Metric | Value |
|---|---|
| Consenting respondents | 96 |
| Scam encounter rate | 38.5% (37/96) |
| Payment rate (among encounterers) | 43.2% (16/37) |
| Non-reporting rate | 91.9% (34/37) |

### H1 — Sunk Cost (Suggestive, Not Significant)
- High prior investment (≥3 interactions) → **60.0% payment rate** vs. 31.8% for low investment
- Fisher's Exact p = 0.107; Bayesian Bootstrap gives **92.3% posterior probability** of positive effect
- PSM average treatment effect: **+33.3 percentage points**
- Random Forest ranks sunk cost as **2nd most important** predictor overall
- **Conclusion:** Suggestive evidence; requires replication with larger sample

### H2 & H3 — Loss Aversion (Strongly Supported)
- **Fear of losing opportunity:** 57.1% payment rate among endorsers vs. **0%** among non-endorsers (p < 0.001)
- **Urgency/time pressure:** 75.0% payment rate vs. 1.1% (OR = 273.0, p < 0.001)
- **H4 Conjunction effect:** High vulnerability + high loss aversion → **57.1% payment rate** vs. 0% for all other combinations
- **Conclusion:** Loss aversion is the dominant psychological driver of payment

### H5 — Social Proof (Null Direct Effect; Suggestive Interaction)
- Self-reported social proof influence did not predict payment: U = 174.0, p = 0.431, r = −0.036
- Age moderation not observed (ρ = 0.040 among younger group)
- **Exploratory H5b:** Professional appearance + social proof simultaneously present → +43.8pp payment rate increase (n = 2–4 per cell; hypothesis-generating only)
- **Conclusion:** Direct effect null; multiplicative legitimacy-signalling warrants larger-scale study

### Sentiment Analysis
- Fear is the most prevalent emotion across all scam types (22–50%)
- Task-based scams uniquely show elevated **joy** (33%) — reflecting the "winning" sensation of early task rewards before the scam reveals itself
- Anger, anxiety, and embarrassment are near-perfectly correlated (r = 0.978–1.000), suggesting categorical emotional avoidance in non-disclosure

### Missing Data
- Significant survey fatigue: ρ = 0.346, p = 0.006 — missingness rises from 12.3% (early questions) to 89.5% (late questions)
- Financial questions had 87.1% missingness — second only to open-ended narratives (95.5%)
- Perfect within-domain missingness correlations indicate participants skip entire sensitive domains rather than individual items

---

## Proposed Interventions

Four evidence-based, platform-deployable interventions grounded in behavioral economics:

### 1. Loss Aversion Warning System
**Evidence:** Fear (p<0.001) and urgency (OR=273, p<0.001) are dominant predictors  
**Target:** Real-time detection of urgency language ("limited spots," "act now," "offer expires")  
**Action:** Interstitial warning before payment actions, reframing "opportunity loss" → "financial loss"  
**Platforms:** WhatsApp, Telegram, LinkedIn, email clients

### 2. Sunk Cost Exit Prompts
**Evidence:** 92.3% Bayesian probability of positive effect; 60% vs 31.8% payment rate  
**Target:** After ≥3 interactions, 2+ hours invested, or first payment request  
**Action:** Display cumulative investment, sunk cost literacy message, decision-independence framing  
**Platforms:** Messaging app thread tracking, email thread depth analysis, job portal multi-stage monitoring

### 3. Social Proof Verification Friction
**Evidence:** Professional appearance + social proof → +43.8pp payment rate (exploratory)  
**Target:** Job postings combining professional branding + social proof + payment requests  
**Action:** Mandatory verification delay; employer badge verification; friction before payment confirmation  
**Platforms:** LinkedIn, job portals, social media platforms

### 4. Vulnerability-Targeted Warnings
**Evidence:** High vulnerability + high loss aversion → 57.1% payment rate vs. 0% for all others  
**Target:** Users with financial vulnerability signals (income data, behavioral markers)  
**Action:** Personalised enhanced warnings, presentation of vetted legitimate opportunities, financial literacy modules  
**Note:** Requires opt-in consent and transparent data usage policies

---

## Setup & Usage

### Requirements

```bash
pip install pandas numpy matplotlib seaborn scipy scikit-learn openpyxl jupyterlab
```

For NLP / sentiment analysis:

```bash
pip install transformers torch
```

### Running the Notebooks

```bash
jupyter lab
# or
jupyter notebook
```

Recommended order:
1. `16_Descriptive_Statistics_...ipynb` — understand the data first
2. `16_2023101124_sunk_cost_analysis_...ipynb`
3. `16_Loss_Aversion_&_Framing_Effects_...ipynb`
4. `16_social_proof_analysis_...ipynb`
5. `16_Sentiment_Analysis_...ipynb`
6. `16_missing_data_analysis_...ipynb`

> **Note:** Notebooks expect the data file at a relative path. Place `16_data_2023101124_2023101040.xlsx` in the same directory as the notebooks, or update the file path in each notebook's data loading cell.

---

## Limitations

### Sampling
- **Small N:** Only 37 encounters and 16 payers — severely underpowered; wide confidence intervals
- **Convenience sample:** IIIT Hyderabad only — young, highly educated, tech-savvy, predominantly middle-class; not generalisable to rural, older, or less digitally literate populations
- **Self-selection:** Respondents willing to disclose scam encounters may differ systematically from those who did not

### Design
- **Cross-sectional:** Cannot establish causality — associations only (e.g., does fear cause payment, or do payers retrospectively rationalise via fear?)
- **Retrospective self-report:** Emotions and influence factors recalled after the fact; subject to cognitive reappraisal and social desirability bias
- **Single institution:** Homogeneous cultural and socioeconomic context limits transferability

### Statistical
- **Perfect separation:** Loss aversion logistic regression produced numerically unstable odds ratios (OR = 273 to OR → ∞) — structural artefacts due to zero cells, not reliable population parameters
- **Single-item constructs:** Sunk cost, social proof, and loss aversion each measured with one item rather than validated multi-item scales
- **NLP model:** Emotion classifiers trained on general corpora, not victim narratives; small text sample (n = 35) prevents robust conclusions

---

## References

1. FBI IC3, "2024 Internet Crime Report," 2024.
2. FTC, "Paying to get paid: Gamified job scams drive record losses," Data Spotlight, 2024.
3. Arkes & Blumer (1985) — The psychology of sunk cost. *Organizational Behavior and Human Decision Processes.*
4. Kahneman & Tversky (1979) — Prospect Theory. *Econometrica.*
5. Cialdini (1984) — *Influence: The Psychology of Persuasion.*
6. Metzger et al. (2010) — Social and heuristic approaches to credibility online. *Journal of Communication.*
7. Baron & Kenny (1986) — The moderator-mediator variable distinction. *Journal of Personality and Social Psychology.*
8. Cross (2015) — No laughing matter: Blaming the victim of online fraud. *IJCC.*
9. Norris, Brookes & Dowell (2019) — Psychology of Internet fraud victimisation. *Journal of Police and Criminal Psychology.*
10. Modic & Lea (2013) — Scam compliance and the psychology of persuasion. SSRN.

---

## Ethics

- Fully anonymous — no PII collected; participants identified by timestamp only
- Informed consent obtained at survey start; right to withdraw at any time
- No compensation provided; voluntary participation
- Debrief section with fraud reporting resources provided to all participants

---

*This is a course research project. All findings are exploratory and should not be treated as confirmatory. Replication with larger, more diverse samples is required before any policy application.*