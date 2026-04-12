// src/app/experiment/within/page.tsx
'use client';

import React, { useEffect, useMemo, useState } from 'react';
import { ExperimentRunner } from '@/components/experiment-runner';
import type { Stimulus, Truth } from '@/components/experiment-types';
import { BASE_POSTS, type BasePost } from '@/components/conditions/base-posts';

type Cell = { version: 'Original' | 'Rephrased'; likesLevel: 'Low' | 'High' };

const CELLS: Cell[] = [
  { version: 'Original',  likesLevel: 'Low'  },
  { version: 'Original',  likesLevel: 'High' },
  { version: 'Rephrased', likesLevel: 'Low'  },
  { version: 'Rephrased', likesLevel: 'High' },
];

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

/** Rotate cells using a simple 4-sequence Latin square based on pid */
function latinOrderIndex(pid: string) {
  return Math.floor(seededFloatFromString(pid) * 4) % 4; // 0..3
}
function rotate<T>(xs: T[], k: number): T[] {
  const n = xs.length;
  return xs.map((_, i) => xs[(i + k) % n]);
}

/** Build a within-subject set: equal number per cell, different base post per cell */
function makeWithinSubjectsStimuli(pid: string, perCell: number, pool: BasePost[]): Stimulus[] {
  const need = perCell * CELLS.length;
  if (pool.length < need) {
    throw new Error(`Not enough base posts: need ${need}, have ${pool.length}`);
  }

  const seed = seededFloatFromString(pid);
  const candidates = shuffle(pool, seed).slice(0, need);

  // Counterbalance order of cells across participants
  const seq = rotate(CELLS, latinOrderIndex(pid)); // 4 sequences

  const out: Stimulus[] = [];
  let idx = 0;
  for (let r = 0; r < perCell; r++) {
    for (const cell of seq) {
      const base = candidates[idx++];
      const Comp = cell.version === 'Original' ? base.Original : base.Rephrased;
      const id = `${base.slug}_${cell.version === 'Original' ? 'og' : 'rp'}_${cell.likesLevel.toLowerCase()}`;
      const shownTruth: Truth = cell.version === 'Rephrased' ? 'AI' : base.truth; //ADDED
      out.push({
        id,
        truth: shownTruth,
        version: cell.version, //ADDED
        Component: Comp,
        likesLevel: cell.likesLevel,
      });
    }
  }
  return out;
}

export default function Page() {
  const [stimuli, setStimuli] = useState<Stimulus[] | null>(null);

  useEffect(() => {
    const sp = new URLSearchParams(window.location.search);
    const pid = sp.get('pid') || (crypto?.randomUUID?.() ?? Math.random().toString(36).slice(2));
    const perCell = parseInt(sp.get('k') || '5', 10); // default: 2 trials per cell → total 8 trials //ADDED
    const s = makeWithinSubjectsStimuli(pid, perCell, BASE_POSTS);
    setStimuli(s);
    // also reflect pid in URL so runner uses the same seed
    if (!sp.get('pid')) {
      sp.set('pid', pid);
      const url = `${window.location.pathname}?${sp.toString()}`;
      window.history.replaceState(null, '', url);
    }
  }, []);

  if (!stimuli) return <div className="p-6 text-sm text-muted-foreground">Preparing your session…</div>;
  return <ExperimentRunner stimuli={stimuli} />;
}
