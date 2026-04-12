'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Stimulus, Truth } from './experiment-types';

/** What one trial write-out looks like in the CSV */
type TrialRecord = {
  participant_id: string;
  trial_index: number;
  post_id: string;
  source_true: Truth;
  text_version: 'Original' | 'Rephrased';  //ADDED
  likes_level: 'Low' | 'High';
  likes_value: number;
  order: number;
  response_choice: Truth | null;
  confidence_0_100: number; // 0..100, step=10, default 50 allowed
  dwell_ms: number;         // time on stimulus page
  rt_ms: number;            // time on response page
  started_at_iso: string;
  device: string;
  viewport_w: number;
  viewport_h: number;
};

/* =========================
   Likes: variable by range
   ========================= */
const DEFAULT_LOW_RANGE: [number, number] = [3, 50];
const DEFAULT_HIGH_RANGE: [number, number] = [6000, 50000];

/** Sample a number ~log-uniform within [min,max] using u in [0,1] */
 function sampleLogUniform([min, max]: [number, number], u: number): number {
  const lo = Math.log10(min);
  const hi = Math.log10(max);
  return Math.round(10 ** (lo + u * (hi - lo)));
} 

/** Deterministic likes per (participant, stimulus.id) so it’s stable per participant */
 function chooseLikes(stim: Stimulus, pid: string): number {
  const key = `${pid}|${stim.id}`;
  const u = seededFloatFromString(key); // 0..1
  const range = stim.likeRange ?? (stim.likesLevel === 'Low' ? DEFAULT_LOW_RANGE : DEFAULT_HIGH_RANGE);
  return sampleLogUniform(range, u);
}
 

/* =========================
   RNG helpers (seeded)
   ========================= */
function cryptoRandomId() {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID();
  return Math.random().toString(36).slice(2);
}
function seededFloatFromString(s: string) {
  let h = 2166136261 >>> 0; // FNV-1a
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h % 100000) / 100000;
}
function shuffle<T>(arr: T[], seed: number): T[] {
  const a = arr.slice();
  let s = Math.floor(seed * 1e9) || 1;
  for (let i = a.length - 1; i > 0; i--) {
    s = (s * 1664525 + 1013904223) % 4294967296;
    const j = s % (i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/* =========================
   Main reusable runner
   ========================= */
export function ExperimentRunner({ stimuli }: { stimuli: Stimulus[] }) {
  // Generate participant id ONLY on the client to avoid hydration mismatch
  const [pid, setPid] = useState<string>('');
  useEffect(() => {
    const sp = new URLSearchParams(window.location.search);
    setPid(sp.get('pid') || cryptoRandomId());
  }, []);

  const deviceStr = typeof navigator !== 'undefined' ? navigator.userAgent : 'unknown';
  const vw = typeof window !== 'undefined' ? window.innerWidth : 0;
  const vh = typeof window !== 'undefined' ? window.innerHeight : 0;

/*   // Build randomized trial list (order + likes computed from ranges), once pid exists
  const trials = useMemo(() => {
    if (!pid) return [] as Array<Stimulus & { order: number; likes: number }>;
    const seed = seededFloatFromString(pid);
    const randomized = shuffle(stimuli, seed);
    return randomized.map((s, i) => ({
      ...s,
      order: i,
      likes: chooseLikes(s, pid),
    }));
  }, [stimuli, pid]);
 */
  const trials = useMemo(() => {
    if (!pid) return [] as Array<Stimulus & { order: number; likes: number }>;
  
    // Must be multiple of 4 (four cells)
    if (stimuli.length % 4 !== 0) {
      console.warn('Stimuli length should be a multiple of 4. Got', stimuli.length);
    }
    const perCell = Math.floor(stimuli.length / 4);
    const seed0 = seededFloatFromString(pid);
  
    // The builder emits stimuli as blocks of 4 in the order [round0: 4 items], [round1: 4 items], ...
    const blocks: Stimulus[][] = [];
    for (let r = 0; r < perCell; r++) {
      blocks.push(stimuli.slice(r * 4, r * 4 + 4));
    }
  
    // Shuffle *within* each block so every set of 4 trials contains all 4 cells, in random order.
    const inOrder: Stimulus[] = [];
    for (let b = 0; b < blocks.length; b++) {
      // different seed per block, derived from pid
      inOrder.push(...shuffle(blocks[b], seed0 + (b + 1) * 0.123456789));
    }
  
    // Finalize with per-trial likes + index
    return inOrder.map((s, i) => ({
      ...s,
      order: i,
      likes: chooseLikes(s, pid),
    }));
  }, [stimuli, pid]); 
  
  // Flow state
  // consent -> instructions -> stimulus -> response -> done
  const [phase, setPhase] = useState<'consent' | 'instructions' | 'stimulus' | 'response' | 'done'>('consent');
  const [idx, setIdx] = useState(0);
  const [choice, setChoice] = useState<Truth | null>(null);
  const [confidence, setConfidence] = useState<number>(50); // default 50; movement not required

  const [rows, setRows] = useState<TrialRecord[]>([]);
  const stimStartRef = useRef<number>(0);
  const respStartRef = useRef<number>(0);

  // Wait for PID before rendering to avoid hydration mismatch
  if (!pid) {
    return (
      <div className="min-h-screen bg-zinc-100">
        <div className="max-w-[760px] mx-auto p-6 text-sm text-muted-foreground">
          Preparing your session…
        </div>
      </div>
    );
  }

  const cur = trials[idx];

  function beginStimulus() {
    setChoice(null);
    setConfidence(50);
    stimStartRef.current = performance.now();
    setPhase('stimulus');
  }

  function goToResponse() {
    respStartRef.current = performance.now();
    setPhase('response');
  }

  function recordAndNext() {
    const now = performance.now();
    const dwell = Math.max(0, Math.round((respStartRef.current || now) - (stimStartRef.current || now)));
    const rt = Math.max(0, Math.round(now - (respStartRef.current || now)));

    const rec: TrialRecord = {
      participant_id: pid,
      trial_index: idx,
      post_id: cur.id,
      source_true: cur.truth,
      text_version: cur.version, //ADDED
      likes_level: cur.likesLevel,
      likes_value: cur.likes,
      order: cur.order,
      response_choice: choice,
      confidence_0_100: confidence,
      dwell_ms: dwell,
      rt_ms: rt,
      started_at_iso: new Date().toISOString(),
      device: deviceStr,
      viewport_w: vw,
      viewport_h: vh,
    };
    setRows((r) => [...r, rec]);

    const next = idx + 1;
    if (next < trials.length) {
      setIdx(next);
      beginStimulus();
    } else {
      setPhase('done');
    }
  }

  /* ========= RENDER PHASES ========= */

  if (phase === 'consent') {
    return (
      <div className="min-h-screen bg-zinc-100">
        <div className="max-w-[760px] mx-auto p-6 space-y-6">
          <h1 className="text-2xl font-semibold">Consent</h1>
          <p className="text-sm text-muted-foreground">
            You will view social media posts and judge whether they were written by an AI (Artificial Intelligence) or a human, then rate your confidence.
            Your responses are anonymous.
          </p>

          <fieldset className="space-y-3">
            <legend className="text-sm font-medium">Do you consent to participate?</legend>
            {/* Yes-only option (required to proceed per your spec) */}
            <label className="flex items-center gap-2 cursor-pointer">
              <input type="radio" name="consent" value="yes" defaultChecked aria-label="consent-yes" />
              <span>Yes, I consent</span>
            </label>
          </fieldset>

          <div className="pt-2">
            <Button onClick={() => setPhase('instructions')}>Continue</Button>
          </div>

          <div className="text-xs text-muted-foreground">
            Participant ID: <b suppressHydrationWarning>{pid}</b>
          </div>
        </div>
      </div>
    );
  }

  if (phase === 'instructions') {
    return (
      <div className="min-h-screen bg-zinc-100">
        <div className="max-w-[760px] mx-auto p-6 space-y-4">
          <h2 className="text-xl font-semibold">Instructions</h2>
          <ul className="list-disc pl-5 space-y-1">
            <li>Read each post carefully.</li>
            <li>Answer whether it was written by <b>AI</b> or a <b>Human</b>.</li>
            <li>
              Rate your confidence from <b>0</b> to <b>100</b> in steps of <b>10</b>. The default is <b>50</b> and is valid.
            </li>
          </ul>
          <div className="pt-2">
            <Button onClick={beginStimulus}>Start</Button>
          </div>
          <div className="text-xs text-muted-foreground">
            Participant ID: <b suppressHydrationWarning>{pid}</b>
          </div>
        </div>
      </div>
    );
  }
type Stats = { n: number; correct: number; incorrect: number; acc: number };
type Matrix = {
  AI_AI: number;       // true AI, responded AI (TP)
  AI_Human: number;    // true AI, responded Human (FN)
  Human_AI: number;    // true Human, responded AI (FP)
  Human_Human: number; // true Human, responded Human (TN)
};

function mkStats(rows: TrialRecord[]): Stats {
  const n = rows.length;
  const correct = rows.filter(r => r.source_true === r.response_choice).length;
  return { n, correct, incorrect: n - correct, acc: n ? (100 * correct) / n : 0 };
}

function computeSummary(rows: TrialRecord[]) {
  const valid = rows.filter(r => r.response_choice === 'AI' || r.response_choice === 'Human');

  const cm: Matrix = {
    AI_AI:       valid.filter(r => r.source_true === 'AI'    && r.response_choice === 'AI').length,
    AI_Human:    valid.filter(r => r.source_true === 'AI'    && r.response_choice === 'Human').length,
    Human_AI:    valid.filter(r => r.source_true === 'Human' && r.response_choice === 'AI').length,
    Human_Human: valid.filter(r => r.source_true === 'Human' && r.response_choice === 'Human').length,
  };

  const overall = mkStats(valid);

  const byVersion = {
    Original:  mkStats(valid.filter(r => r.text_version === 'Original')),
    Rephrased: mkStats(valid.filter(r => r.text_version === 'Rephrased')),
  };

  const byLikes = {
    Low:  mkStats(valid.filter(r => r.likes_level === 'Low')),
    High: mkStats(valid.filter(r => r.likes_level === 'High')),
  };

  // Optional: full 2×2 cell breakdown (Version × Likes)
  const byCell = {
    Original_Low:  mkStats(valid.filter(r => r.text_version === 'Original'  && r.likes_level === 'Low')),
    Original_High: mkStats(valid.filter(r => r.text_version === 'Original'  && r.likes_level === 'High')),
    Rephrased_Low: mkStats(valid.filter(r => r.text_version === 'Rephrased' && r.likes_level === 'Low')),
    Rephrased_High:mkStats(valid.filter(r => r.text_version === 'Rephrased' && r.likes_level === 'High')),
  };

  // Optional: class-wise TPR/TNR + balanced accuracy
  const trueAI = cm.AI_AI + cm.AI_Human;
  const trueHuman = cm.Human_AI + cm.Human_Human;
  const tprAI = trueAI ? (100 * cm.AI_AI) / trueAI : 0;           // sensitivity for AI class
  const tnrHuman = trueHuman ? (100 * cm.Human_Human) / trueHuman : 0; // specificity for Human class
  const balancedAcc = (tprAI + tnrHuman) / 2;

  return { cm, overall, byVersion, byLikes, byCell, tprAI, tnrHuman, balancedAcc };
}

function pct(x: number) {
  return `${x.toFixed(1)}%`;
}

  if (phase === 'stimulus') {
    const C = cur.Component;
    return (
      <div className="min-h-screen bg-zinc-100">
        <div className="max-w-[760px] mx-auto p-6">
          {/* Show the post; likes are visible inside the post footer */}
          <C likes={cur.likes} />
          <div className="mt-4">
            <Button onClick={goToResponse}>Answer</Button>
          </div>
        </div>
      </div>
    );
  }

  if (phase === 'response') {
    return (
      <div className="min-h-screen bg-zinc-100">
        <div className="max-w-[760px] mx-auto p-6 space-y-6">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-semibold">Your judgment</h3>
            <div className="text-sm text-muted-foreground">
              Trial {idx + 1} / {trials.length}
            </div>
          </div>

          {/* Choice */}
          <fieldset className="space-y-2">
            <legend className="text-sm font-medium">Who do you think wrote this post?</legend>
            <div className="flex gap-6">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="radio"
                  name="choice"
                  value="AI"
                  checked={choice === 'AI'}
                  onChange={() => setChoice('AI')}
                />
                <span>AI</span>
              </label>
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="radio"
                  name="choice"
                  value="Human"
                  checked={choice === 'Human'}
                  onChange={() => setChoice('Human')}
                />
                <span>Human</span>
              </label>
            </div>
          </fieldset>

          {/* Confidence: 0..100 step=10, default 50, movement NOT required */}
          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="conf">
              How Confident are you in your response? (0–100)
            </label>
            <p id="conf-help" className="text-xs text-muted-foreground">
              0 = least confidence, 100 = most confidence. Steps of 10; 50 = unsure/neutral.
            </p>
            <input
              id="conf"
              type="range"
              min={0}
              max={100}
              step={10}
              value={confidence}
              onChange={(e) => setConfidence(parseInt(e.target.value, 10))}
              className="w-full"
            />
            <div className="flex justify-between text-xs text-muted-foreground">
              {[0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100].map((v) => (
                <span key={v}>{v}</span>
              ))}
            </div>
            <div className="text-sm">
              Your value: <b>{confidence}</b>
            </div>
          </div>

          <div className="pt-1">
            <Button onClick={recordAndNext} disabled={choice === null}>
              {idx + 1 === trials.length ? 'Finish' : 'Next'}
            </Button>
          </div>
        </div>
      </div>
    );
  }

/*   // Done
  return (
    <div className="min-h-screen bg-zinc-100">
      <div className="max-w-[900px] mx-auto p-6 space-y-4">
        <h3 className="text-lg font-semibold">All done — thank you!</h3>
        <p>
          You completed <b>{trials.length}</b> trial{trials.length === 1 ? '' : 's'}.
        </p>
        <div className="flex gap-3">
          <Button onClick={() => downloadCSV(rows)}>Download CSV</Button>
          <Button variant="secondary" onClick={() => window.location.assign(window.location.pathname)}>
            Restart
          </Button>
        </div>
        <pre className="mt-4 bg-muted p-3 rounded text-xs overflow-auto max-h-[320px]">
          {JSON.stringify(rows, null, 2)}
        </pre>
      </div>
    </div>
  );*/
  // Done
return (
  <div className="min-h-screen bg-zinc-100">
    <div className="max-w-[900px] mx-auto p-6 space-y-6">
      <h3 className="text-lg font-semibold">All done — thank you!</h3>
      <p>
        You completed <b>{trials.length}</b> trial{trials.length === 1 ? '' : 's'}.
      </p>

      {/* Accuracy / performance summary */}
      {(() => {
        const S = computeSummary(rows);
        const total = S.overall.n;
        return (
          <div className="bg-white rounded-lg border shadow-sm p-4 space-y-4">
            <h4 className="text-base font-semibold">Your performance</h4>

            {/* Overall */}
            <div className="grid grid-cols-2 gap-3 text-sm">
              <div className="p-3 rounded bg-zinc-50 border">
                <div className="text-zinc-500">Overall Accuracy</div>
                <div className="text-xl font-semibold">{pct(S.overall.acc)}</div>
                <div className="text-zinc-500">
                  Correct {S.overall.correct} / {total} (Incorrect {S.overall.incorrect})
                </div>
              </div>
              <div className="p-3 rounded bg-zinc-50 border">
                <div className="text-zinc-500">Balanced Accuracy</div>
                <div className="text-xl font-semibold">{pct(S.balancedAcc)}</div>
                <div className="text-zinc-500">
                  AI TPR {pct(S.tprAI)} · Human TNR {pct(S.tnrHuman)}
                </div>
              </div>
            </div>

            {/* Confusion matrix */}
            <div>
              <div className="text-sm font-medium mb-2">Confusion matrix</div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm border-collapse">
                  <thead>
                    <tr>
                      <th className="border px-2 py-1 text-left"></th>
                      <th className="border px-2 py-1 text-left">Responded AI</th>
                      <th className="border px-2 py-1 text-left">Responded Human</th>
                      <th className="border px-2 py-1 text-left">Row total</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr>
                      <td className="border px-2 py-1 font-medium">True AI</td>
                      <td className="border px-2 py-1">{S.cm.AI_AI}</td>
                      <td className="border px-2 py-1">{S.cm.AI_Human}</td>
                      <td className="border px-2 py-1">{S.cm.AI_AI + S.cm.AI_Human}</td>
                    </tr>
                    <tr>
                      <td className="border px-2 py-1 font-medium">True Human</td>
                      <td className="border px-2 py-1">{S.cm.Human_AI}</td>
                      <td className="border px-2 py-1">{S.cm.Human_Human}</td>
                      <td className="border px-2 py-1">{S.cm.Human_AI + S.cm.Human_Human}</td>
                    </tr>
                    <tr>
                      <td className="border px-2 py-1 font-medium">Column total</td>
                      <td className="border px-2 py-1">{S.cm.AI_AI + S.cm.Human_AI}</td>
                      <td className="border px-2 py-1">{S.cm.AI_Human + S.cm.Human_Human}</td>
                      <td className="border px-2 py-1">{total}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            {/* By text version */}
            <div className="grid grid-cols-2 gap-3 text-sm">
              <div className="p-3 rounded bg-zinc-50 border">
                <div className="font-medium mb-1">Original</div>
                <div>Acc: <b>{pct(S.byVersion.Original.acc)}</b></div>
                <div>n={S.byVersion.Original.n}, correct {S.byVersion.Original.correct}, incorrect {S.byVersion.Original.incorrect}</div>
              </div>
              <div className="p-3 rounded bg-zinc-50 border">
                <div className="font-medium mb-1">Rephrased</div>
                <div>Acc: <b>{pct(S.byVersion.Rephrased.acc)}</b></div>
                <div>n={S.byVersion.Rephrased.n}, correct {S.byVersion.Rephrased.correct}, incorrect {S.byVersion.Rephrased.incorrect}</div>
              </div>
            </div>

            {/* By likes level */}
            <div className="grid grid-cols-2 gap-3 text-sm">
              <div className="p-3 rounded bg-zinc-50 border">
                <div className="font-medium mb-1">Low Likes</div>
                <div>Acc: <b>{pct(S.byLikes.Low.acc)}</b></div>
                <div>n={S.byLikes.Low.n}, correct {S.byLikes.Low.correct}, incorrect {S.byLikes.Low.incorrect}</div>
              </div>
              <div className="p-3 rounded bg-zinc-50 border">
                <div className="font-medium mb-1">High Likes</div>
                <div>Acc: <b>{pct(S.byLikes.High.acc)}</b></div>
                <div>n={S.byLikes.High.n}, correct {S.byLikes.High.correct}, incorrect {S.byLikes.High.incorrect}</div>
              </div>
            </div>

            {/* Optional: the 4 cells (Version × Likes) */}
            <details className="text-sm">
              <summary className="cursor-pointer select-none">Details by cell (Version × Likes)</summary>
              <div className="mt-2 grid grid-cols-2 gap-3">
                {([
                  ['Original_Low','Original · Low'],
                  ['Original_High','Original · High'],
                  ['Rephrased_Low','Rephrased · Low'],
                  ['Rephrased_High','Rephrased · High'],
                ] as const).map(([k,label]) => {
                  const s = (S.byCell as any)[k] as Stats;
                  return (
                    <div key={k} className="p-3 rounded bg-zinc-50 border">
                      <div className="font-medium mb-1">{label}</div>
                      <div>Acc: <b>{pct(s.acc)}</b></div>
                      <div>n={s.n}, correct {s.correct}, incorrect {s.incorrect}</div>
                    </div>
                  );
                })}
              </div>
            </details>
          </div>
        );
      })()}

      {/* Your existing buttons */}
      <div className="flex gap-3">
        <Button onClick={() => downloadCSV(rows)}>Download CSV</Button>
        <Button variant="secondary" onClick={() => window.location.assign(window.location.pathname)}>
          Restart
        </Button>
      </div>

      <pre className="mt-2 bg-muted p-3 rounded text-xs overflow-auto max-h-[320px]">
        {JSON.stringify(rows, null, 2)}
      </pre>
    </div>
  </div>
);

} 

/* =========================
   CSV helpers
   ========================= */
function downloadCSV(rows: TrialRecord[]) {
  const headers = [
    'participant_id',
    'trial_index',
    'post_id',
    'source_true',
    'text_version', //ADDED
    'likes_level',
    'likes_value',
    'order',
    'response_choice',
    'confidence_0_100',
    'dwell_ms',
    'rt_ms',
    'started_at_iso',
    'device',
    'viewport_w',
    'viewport_h',
  ] as const;

  const esc = (v: any) => {
    const s = v === null || v === undefined ? '' : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const lines = [headers.join(',')];
  for (const r of rows) {
    lines.push(headers.map((h) => esc((r as any)[h])).join(','));
  }

  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `ai_human_experiment_${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}
