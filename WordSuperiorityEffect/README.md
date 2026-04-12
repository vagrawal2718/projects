# Word Superiority Effect: An Online Experimental Investigation

**Authors:** Mithun Rameshbabu (2023101070), Aditya Nair (2023111029), Vishakha Agrawal (2023101040)

## Project Overview

Word Superiority Effect (WSE) is well-established phenomenon in psycholinguistics wherein letters are recognized more accurately and rapidly when presented within real words compared to isolated letters or nonsense letter strings. This project replicates and extends Reicher's (1969) foundational work using an online experimental platform (PsychoJS/Pavlovia) while incorporating reaction time measurements alongside accuracy metrics.

## Background and Motivation

### The Word Superiority Effect

The Word Superiority Effect describes the robust finding that people can identify or remember target letters more efficiently when those letters appear in familiar words rather than in random letter sequences or isolation. This phenomenon challenges the intuitive assumption that word recognition is merely the sum of recognizing individual letters, and instead supports theories of interactive activation and top-down processing in perception.

### Historical Context: Reicher (1969)

George Reicher's seminal 1969 study, "Perceptual Recognition as a Function of Meaningfulness of Stimulus Material," established the WSE under tightly controlled experimental conditions:

- **Task**: Participants viewed 4-letter stimuli (words, nonwords, or isolated letters) presented via tachistoscope (brief exposure), followed by masking.
- **Design**: A forced-choice task where participants indicated which of two letters appeared in a specific position.
- **Control**: Redundancy was controlled by ensuring both response choices formed valid words (e.g., when testing the last letter of WORD, both D and K formed valid alternatives: WORD vs. WORK).
- **Finding**: Letter recognition accuracy was significantly higher in word contexts than in isolated letters or nonwords, demonstrating that the advantage persists even when statistical word-frequency information cannot be leveraged.

### Theoretical Foundation

The WSE is typically explained by models of parallel processing and interactive activation (McClelland & Rumelhart, 1981), which propose that:
- Letters are processed in parallel within their context
- Feedback from word-level representations enhances perception of constituent letters
- This top-down influence facilitates recognition even when bottom-up (letter-level) information is degraded or ambiguous

## Hypothesis and Research Questions

**Primary Hypothesis:**
Participants will demonstrate higher accuracy and faster response times in identifying a target letter when it appears in a real English word compared to a scrambled nonword (an anagram of the same word), replicating and extending Reicher's findings in a modern online setting.

**Extended Research Question:**
Beyond accuracy, how does stimulus type (word vs. nonword) affect the speed of letter detection (reaction time)?

## Methodology

### Experimental Design

**Design Type:** Within-subjects design. Each participant completed trials in both word and nonword conditions, allowing direct comparison of performance within individual participants and reducing variance due to individual differences.

### Stimuli

The conditions file (conditions3.xlsx) contains 18 trials structured as 9 word-nonword pairs:

**Word Set (9 words):** WORK, CART, WORD, CARD, LARD, LOAD, LEAD, SNIP, SNAP

**Nonword Set (9 matched nonwords):** RWOK, ARCT, RWOD, RCAD, RLAD, AODL, AEDL, PNIS, PNAS

**Nonword Generation:** Each nonword is created by scrambling the letters of its matched word, preserving letter composition while eliminating semantic meaning. For example:
- WORK / RWOK
- CARD / RCAD
- LOAD / AODL

**Critical Letter Distribution:** Critical letters vary across positions:
- **Position 1:** C (CARD/RCAD, LARD/RLAD)
- **Position 2:** O (LOAD/AODL, LEAD/AEDL)
- **Position 3:** I (SNIP/PNIS, SNAP/PNAS)
- **Position 4:** K (WORK/RWOK, WORD/RWOD), T (CART/ARCT)

**Presence/Absence Balance:** For each critical letter, the experiment includes trials where the letter is present in the stimulus (correct answer: yes) and trials where it is absent (correct answer: no). Each word-nonword pair appears twice with different critical letters or positions.

### Trial Structure

Each trial followed a standardized sequence implemented in PsychoJS:

1. **Fixation (500 ms):** A centered plus sign (+) appeared in black text (letterHeight 0.05) on a custom background image to orient attention
2. **Stimulus Presentation (500 ms):** A four-letter string (word or nonword) was displayed in black text (letterHeight 0.08) at the center of the screen
3. **Response Prompt:** The question "Did the word contain the letter [X]?" appeared simultaneously with two response options:
   - **Left Button:** "Yes" (left arrow key or left mouse click on the LEFT TEXT button)
   - **Right Button:** "No" (right arrow key or right mouse click on the RIGHT TEXT button)
4. **Response Collection:** Participants responded via keyboard (left/right arrow keys) or mouse click on onscreen buttons. The response period was self-paced; reaction time was recorded from the onset of the question until response.
5. **Trial Sequencing:** The 18 trials (9 word + 9 nonword pairs) were randomly ordered for each participant to prevent order effects and pattern learning.

**Response Mapping:** Left = Yes, Right = No (consistent across all trials)

### Controlled Variables

The following variables were held constant across all conditions:

- **Stimulus Length:** All stimuli were exactly 4 letters
- **Letter Content:** Nonwords were letter-for-letter anagrams of words
- **Presentation Duration:** Fixation 500 ms, stimulus 500 ms (total 1000 ms pre-mask)
- **Response Mapping:** Left arrow/button = Yes, Right arrow/button = No
- **Task Instructions:** Consistent across all participants

### Confounding Variables

The following potential confounds were identified but not fully controlled (limitations acknowledged in discussion):

- **Individual Differences:** Vocabulary level, reading ability, language background (native vs. non-native English speakers)
- **Environmental Factors:** Screen size, resolution, brightness (especially in online settings); external distractions
- **Task-Related Factors:** Position effects on critical letters; response bias tendencies; potential strategy learning across trials
- **Stimulus Familiarity:** Differential exposure to specific words in the stimulus set

### Implementation Platform

The experiment was implemented using **PsychoJS 2024.2.4** (JavaScript implementation of PsychoPy) and hosted on **Pavlovia**, a web-based platform for online behavioral experiments:

**Technical Stack:**
- **Core Library:** PsychoJS 2024.2.4 (imported from lib/psychojs-2024.2.4.js)
- **Hosting Platform:** Pavlovia (Open Science Framework)
- **Experiment File:** word_superiority_effect_v3.psyexp (PsychoPy Builder file)
- **Compiled JavaScript:** word_superiority_effect_v3.js and word_superiority_effect_v3-legacy-browsers.js
- **Stimulus File:** conditions3.xlsx (trial conditions and stimuli)
- **Visual Assets:** bg.jpg (background image), wse_avatar.png (participant avatar)
- **Data Output Format:** Tab-separated values (.txt) with trial-by-trial and summary statistics
- **Participant ID:** Auto-generated 6-digit identifier
- **Session Logging:** Date/time stamping, frame rate detection, OS platform logging

**Code Repository:** https://gitlab.pavlovia.org/Iris2718/word_superiority_effect_v3

**Advantages of Online Implementation:** 
- Reproducibility across diverse participants and environments
- Automated data collection and standardization
- Real-time sync to Pavlovia server
- Accessible to geographically distributed participants
- Cross-browser compatibility (standard and legacy JavaScript versions)

### Participants

- **Sample Size:** 41 student participants
- **Demographics:** 31 male (75.6%), 10 female (24.4%), mean age approximately 19 years
- **Recruitment:** Participants were recruited from the project authors' academic program/cohort
- **Inclusion Criteria:** Implied (from recruitment): native or fluent English speakers; no documented reading disorders or uncorrected vision problems

## Results

### Data Collection and Analysis

Raw data were collected in tab-separated text format, with each row corresponding to one trial and including:

**Per-Trial Variables:**
- `condition`: "word" or "nonword"
- `this_word`: The displayed 4-letter stimulus (e.g., WORK, RWOK)
- `critical_letter`: The letter participants were asked to identify (e.g., K)
- `letter_position`: Position of the critical letter in the stimulus (1-4)
- `this_question`: The question prompt (e.g., "Did the word contain the letter \"K\"?")
- `corr_ans`: Correct response key ("left" or "right")
- `key_resp.keys`: Key(s) pressed by participant (left/right arrow)
- `key_resp.corr`: Correctness of response (1 = correct, 0 = incorrect)
- `key_resp.rt`: Reaction time in seconds (from question onset to response)
- `mouse.x`, `mouse.y`: Mouse position if mouse was used
- `mouse.clicked_name`: Name of button clicked if mouse was used
- `correct`: Custom variable (1 = correct, 0 = incorrect), stored for analysis
- `rt`: Custom variable storing reaction time, stored for analysis

**Session-Level Summary Variables (calculated at end of experiment):**
- `word_average_acc`: Mean accuracy for word trials (proportion correct)
- `nonword_average_acc`: Mean accuracy for nonword trials (proportion correct)
- `word_average_rt`: Mean reaction time for word trials (seconds)
- `nonword_average_rt`: Mean reaction time for nonword trials (seconds)

**Meta-data:**
- `participant`: 6-digit auto-generated participant ID
- `what is your first language?`: Self-reported first language (default: "English")
- `date`: Experiment date and time
- `expName`: Experiment name ("word_superiority_effect_v3")
- `psychopyVersion`: PsychoPy version (2024.2.4)
- `OS`: Operating system platform
- `frameRate`: Monitor refresh rate (in Hz)

**Statistical Method:** Wilcoxon Signed-Rank Test, a non-parametric test appropriate for comparing paired samples (within-subjects design) with non-normal distributions. This test compares median differences without assuming normality.

### Accuracy Results

**Wilcoxon Signed-Rank Test (one-tailed, testing word > nonword):**
- **Statistic (W):** 396.5
- **p-value:** 0.675 (not statistically significant)

| Condition | Mean Accuracy (%) | Standard Deviation (%) |
|-----------|-------------------|----------------------|
| Word      | 93.5              | 14.3                 |
| Nonword   | 94.6              | 9.7                  |

**Interpretation:** No statistically significant difference in accuracy between word and nonword conditions. Participants performed equally well in both conditions, with both groups exceeding 93% correct responses.

### Reaction Time Results

**Wilcoxon Signed-Rank Test (one-tailed, testing word < nonword):**
- **Statistic (W):** 260.0
- **p-value:** 0.013 (statistically significant at alpha = 0.05)

| Condition | Median RT (seconds) | Standard Deviation (seconds) |
|-----------|---------------------|------------------------------|
| Word      | 0.930               | 0.216                        |
| Nonword   | 0.963               | 0.245                        |

**Interpretation:** Participants responded significantly faster to letter detection questions about words (Mdn = 0.930 s) compared to nonwords (Mdn = 0.963 s), a difference of approximately 33 milliseconds. This finding provides statistical support for the word superiority effect, albeit manifested in response speed rather than accuracy.

## Discussion

### Partial Support for Hypothesis

The results provide **partial support** for the hypothesis:

- **Supported:** Reaction time showed the predicted word superiority effect; participants detected letters in words faster than in nonwords
- **Not Supported:** Accuracy did not show a significant difference; both word and nonword conditions yielded high accuracy

This divergence from the original Reicher findings warrants investigation.

### Ceiling Effect

A likely explanation for the null accuracy finding is a **ceiling effect**:

- Both conditions yielded accuracy above 93%, leaving minimal room for a condition difference to emerge
- The stimulus presentation duration (500 ms) may have been sufficiently long to allow clear perception of all letters regardless of word context
- Modern computer displays and presentation protocols may afford better stimulus visibility compared to Reicher's tachistoscopic methods
- The student participant population, accustomed to attentional and cognitive tasks, may have performed near asymptotic levels of accuracy

The persistence of reaction time differences despite ceiling accuracy suggests that **processing fluency is independent of near-perfect accuracy**: participants can process words more fluently (faster) even when they are equally accurate in both conditions.

### Comparison to Original Studies

Reicher's original study found accuracy advantages for words. The present findings:
- Replicate the accuracy-controlled design but find the advantage manifested in a different dependent variable (RT vs. accuracy)
- Are consistent with modern dual-process models suggesting automatic (fast) and controlled (accurate) processing pathways
- Suggest that the word superiority effect operates across multiple performance metrics, not solely at the level of accuracy

### Speed-Accuracy Tradeoff

The pattern might also reflect a **speed-accuracy tradeoff**:

- Participants may have adopted different strategies for words vs. nonwords
- Words, being inherently more familiar, may be processed via automatic or fluent pathways, leading to faster responses
- Nonwords, lacking semantic or orthographic familiarity, may trigger more controlled, deliberate processing, slowing response times
- This differential processing speed does not substantially affect ultimate accuracy (ceiling effect) but is captured in reaction time metrics

## Limitations

### Task Difficulty and Design

1. **Ceiling Effect on Accuracy:** High accuracy rates (>93%) in both conditions suggest the task may have been insufficiently challenging to differentiate performance. More difficult stimuli or shorter presentation durations might reveal stronger accuracy advantages for words.

2. **Stimulus Presentation Duration:** The 500 ms stimulus presentation is relatively long. Shorter durations (e.g., 100-200 ms) might force participants to rely more heavily on word-context constraints, revealing larger effects.

3. **Stimulus Length:** Four-letter words are relatively short. Longer words (8-10 letters) might show stronger context effects and larger word superiority advantages.

### Experimental Environment and Control

4. **Online Testing Limitations:** Online studies lack control over participant viewing conditions, screen calibration, ambient lighting, and environmental distractions. These factors introduce noise into reaction time measurements and may reduce the detectability of condition effects on accuracy.

5. **Timing Precision:** JavaScript-based timing (PsychoJS) may have lower temporal precision than laboratory-based systems, particularly for reaction time measurements.

6. **Participant Heterogeneity:** Diverse language backgrounds and reading abilities (especially in online samples) can introduce variability in baseline processing speed and word knowledge.

### Statistical and Methodological Considerations

7. **Sample Size:** With 41 participants, the study has moderate statistical power. Larger samples would increase sensitivity to small condition effects, particularly on accuracy metrics.

8. **Learning and Practice Effects:** The present analysis does not appear to exclude initial practice trials. Early trials often show longer and more variable reaction times; excluding the first 1-2 trials might reduce noise and strengthen effect detection.

9. **Position Effects:** The critical letter position (beginning, middle, or end of word) can interact with stimulus type; this was not analyzed separately.

## Conclusions

### Key Findings

1. **Reaction Time:** A statistically significant Word Superiority Effect was demonstrated via faster response times for words (Mdn = 0.930 s) compared to nonwords (Mdn = 0.963 s), p = 0.013.

2. **Accuracy:** No significant difference in accuracy between word (M = 93.5%) and nonword (M = 94.6%) conditions, likely due to ceiling effects.

3. **Theoretical Implication:** Results support interactive activation and parallel processing models wherein words benefit from top-down lexical constraints. These constraints operate at the level of processing speed even when accuracy is not constrained by ambiguity or degradation.


### Theoretical Implications

The findings are consistent with models proposing:
- **Parallel Processing:** Multiple letters are processed simultaneously in context
- **Interactive Activation:** Word-level representations provide feedback that enhances letter-level processing
- **Fluency Advantage:** Even under high-accuracy conditions, the lexical structure of words affords processing advantages
- **Top-Down Constraints:** Knowledge of likely letter sequences in English facilitates faster decision-making

## Future Directions

### Recommended Methodological Improvements

1. **Trial Exclusion:** Exclude the first 1-2 trials from analysis. Participants often exhibit longer and more variable reaction times in early trials as they familiarize themselves with the task structure. Removing these warm-up trials should reduce noise and strengthen effect detection.

2. **Stimulus Length Variation:** Employ longer words (8-10 letters) alongside 4-letter stimuli. Longer words afford stronger contextual constraints and may produce larger word superiority effects, particularly on accuracy metrics.

3. **Presentation Duration Reduction:** Lower stimulus presentation durations (100-200 ms) or introduce masking/noise to increase task difficulty and reduce ceiling effects.

4. **Controlled Laboratory Testing:** Conduct a parallel laboratory-based study using the same stimuli and design to isolate the effects of online testing environment variability.

### Expanded Research Questions

1. **Letter Position Effects:** Analyze whether word superiority effects differ based on critical letter position (initial vs. medial vs. final letters).

2. **Frequency and Orthographic Neighborhood:** Manipulate word frequency and orthographic neighborhood size to test how lexical properties modulate the WSE.

3. **Non-Native Speakers:** Recruit both native and non-native English speakers to examine how language proficiency affects word versus nonword processing.

4. **Individual Differences:** Correlate performance with standardized measures of reading ability, vocabulary, and processing speed to identify which participants benefit most from word context.

5. **Neural Mechanisms:** Collect EEG or fMRI data to identify the neural correlates of the WSE and determine at what stages word context influences letter perception.

## Technical Details

### Repository Contents

```
WordSuperiorityEffect/
├── word_superiority_effect_v3.psyexp          # PsychoPy Builder experiment file
├── word_superiority_effect_v3.js               # Compiled PsychoJS (modern browsers)
├── word_superiority_effect_v3-legacy-browsers.js # Compiled PsychoJS (IE/legacy)
├── conditions3.xlsx                            # Stimulus conditions file (18 trials)
├── bg.jpg                                      # Background image
├── wse_avatar.png                              # Participant avatar/icon
├── index.html                                  # Web interface entry point
├── M1.pptx                                     # Project presentation (authors, methods, results)
├── data/                                       # Directory for participant data files
│   └── [participant_id]_word_superiority_effect_v3_[date].txt
├── README.md                                   # Original brief project documentation
└── code.txt                                    # PsychoJS source code (this file)
```

### Dependencies and Platforms

- **Experiment Builder:** PsychoPy 2024.2.4 (used to create .psyexp file)
- **JavaScript Runtime:** PsychoJS 2024.2.4
- **Hosting Platform:** Pavlovia (https://pavlovia.org)
- **Code Repository:** GitLab (https://gitlab.pavlovia.org/Iris2718/word_superiority_effect_v3)
- **Browser Compatibility:** Modern browsers (Chrome, Firefox, Safari, Edge) via word_superiority_effect_v3.js; legacy browsers (IE) via word_superiority_effect_v3-legacy-browsers.js
- **Analysis Software:** Python (scipy.stats.wilcoxon for Wilcoxon test), R, SPSS, or equivalent statistical package

### Data Analysis Workflow

```python
# Example: Computing Wilcoxon Signed-Rank test on accuracy
from scipy import stats
import pandas as pd

# Load data for all participants
data = pd.read_csv('participant_001_word_superiority_effect_v3_2024-01-15.txt', sep='\t')

# Compute mean accuracy per condition (already calculated in experiment end routine)
word_acc = data[data['condition'] == 'word']['correct'].mean()
nonword_acc = data[data['condition'] == 'nonword']['correct'].mean()

# Wilcoxon Signed-Rank test across participants (18 trials per participant)
# W statistic, p-value = stats.wilcoxon(word_accs, nonword_accs, alternative='greater')
```

### Reproducibility

The full experiment code is available on GitLab (link above). To reproduce or extend this work:

1. Clone or fork the GitLab repository
2. Review the PsychoJS code for stimulus generation, trial sequencing, and response collection logic
3. Modify stimulus parameters, presentation timing, or task instructions as desired
4. Deploy the modified version on Pavlovia or a compatible platform
5. Recruit participants and collect data using the standardized protocol
6. Analyze using appropriate statistical tests (Wilcoxon for paired non-normal data, or parametric tests if data normality is satisfied after larger sample collection)

### Code Organization and Key Functions

**Experiment Flow (from code.txt, PsychoJS):**

1. **Initialization (`experimentInit()`)**: Sets up visual components including background images, text boxes, keyboard and mouse input handlers, and clock objects.

2. **Instructions Routine (`instructionsRoutineBegin/EachFrame/End()`)**: Displays task instructions and waits for participant to press spacebar or click START button. Participants are instructed:
   - "This fun game will show you a series of words"
   - "After each word you will be asked if that word contained a particular letter"
   - "Left Arrow = Yes, Right Arrow = No"

3. **Trial Loop (`trialsLoopBegin/EachFrame/End()`)**: Iterates through 18 randomized trials from conditions3.xlsx:
   - Fixation (+) displayed for 500 ms
   - Stimulus (word or nonword) displayed for 500 ms
   - Response prompt with two button options presented until participant responds
   - Reaction time and accuracy recorded automatically

4. **Score Tracking (from `track_score` code block)**: For each trial:
   - Checks if response was correct via keyboard (`key_resp.corr`) or mouse click
   - Mouse click responses checked against button names ("lefttxt" or "righttxt")
   - Accuracy (1/0) and reaction time stored
   - Running totals accumulated in `word_accuracies`, `nonword_accuracies`, `word_rts`, `nonword_rts` arrays

5. **Feedback Calculation (`endRoutineBegin()`, `calculate` code block)**: Computes summary statistics:
   - Means for accuracy and RT per condition
   - Generates personalized feedback string based on pattern:
     - If word_acc > nonword_acc AND word_rt < nonword_rt: "You showed a word superiority effect!"
     - If word_acc > nonword_acc AND NOT word_rt < nonword_rt: "You were more accurate for words versus non words, but you were faster for non words."
     - If word_rt < nonword_rt AND NOT word_acc < nonword_acc: "You were faster for words versus non words, but you were more accurate for non words."
     - If word_acc < nonword_acc AND word_rt > nonword_rt: "You showed the opposite of a word superiority effect..."
   - Displays final feedback with numerical summaries (accuracy as %, RT in ms)

6. **Data Export**: All trial-by-trial and summary data automatically saved to server in tab-separated format with participant ID and timestamp

**Key Variables:**
- `condition`: Imported from conditions3.xlsx; either "word" or "nonword"
- `this_word`: The displayed stimulus string (e.g., "WORK", "RWOK")
- `critical_letter`: Letter participant searches for (e.g., "K")
- `corr_ans`: Correct response ("left" or "right")
- `key_resp`: Keyboard response handler (returns keys, corr, rt)
- `mouse`: Mouse handler (returns clicked_name, x, y, time)
- `word_accuracies`, `nonword_accuracies`: Lists accumulating trial outcomes
- `word_rts`, `nonword_rts`: Lists accumulating reaction times

## References

McClelland, J. L., & Rumelhart, D. E. (1981). An interactive activation model of context effects in letter perception: Part 1. An account of basic findings. *Psychological Review*, 88(5), 375-407.

Reicher, G. M. (1969). Perceptual recognition as a function of meaningfulness of stimulus material. *Journal of Experimental Psychology*, 81(2), 275-280.

## License and Attribution

This project was conducted as part of coursework for Introduction to Brain and Cognition at IIIT Hyderabad. 

---

**Last Updated:** 2024
**Status:** Completed experimental study with analysis and documentation