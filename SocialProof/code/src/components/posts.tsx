'use client';

import * as React from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarImage, AvatarFallback } from "@/components/ui/avatar";
import { MoreHorizontal, Globe, ThumbsUp } from "lucide-react";

/* ------------------------------------------------------------------ */
/* Small helpers                                                       */
/* ------------------------------------------------------------------ */

function VerifiedBadge() {
  return (
    <span
      className="inline-flex items-center justify-center align-middle ml-1 h-4 w-4 rounded-full bg-sky-500 text-white text-[10px] font-bold"
      aria-label="Verified"
      title="Verified"
    >
      ✓
    </span>
  );
}

function RelationPill({ text }: { text: string }) {
  return (
    <span className="ml-1 text-xs text-muted-foreground rounded-full bg-muted px-1.5 py-0.5">{text}</span>
  );
}

function Dot() {
  return <span className="mx-1 text-muted-foreground">·</span>;
}

function formatLikes(n: number): string {
  if (!Number.isFinite(n)) return "0";
  return n.toLocaleString();
}

function FooterBar({ likes }: { likes: number }) {
  return (
    <div className="pt-3 flex items-center gap-2" role="group" aria-label="Reactions">
      <ThumbsUp className="h-4 w-4 text-muted-foreground" aria-hidden />
      <span className="text-sm text-muted-foreground" aria-label="likes count">{formatLikes(likes)}</span>
    </div>
  );
}

/* ======================================================================
   POST 1: TRAVEL — ORIGINAL
   ====================================================================== */
export function LinkedInPostCardTravelOriginal({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Kawaljeet Kaur" />
              <AvatarFallback>KK</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Kawaljeet Kaur</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">Growth Partner at The Date Crew</div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>4d</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (original) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>If you aren’t a passionate "traveller" & "hiker", you can’t get married!</p>
          <p>According to people’s matrimony profiles these days, everyone is a "passionate traveller" and a "hiker." <span role="img" aria-label="smiling with sweat">😅</span></p>
          <p>Which is weird, because I'm pretty sure most of us are just on the sofa right now, trying to decide what to order for lunch. <span role="img" aria-label="yum">😋</span></p>
          <p>We're all so terrified of being boring that we create these adventure-resumes for our love lives.</p>
          <p>But here’s a secret: Nobody falls in love with a travel itinerary.</p>
          <p>They fall in love with the person they can be wonderfully, comfortably "boring" with.</p>
          <p>The real compatibility test isn't climbing a mountain together. It's sitting on a sofa, in your oldest pajamas, in total silence, and still being perfectly happy.</p>
          <p>At <a className="text-sky-600 hover:underline font-medium" href="#">The Date Crew</a>, we skip the fake adventure-resume. We're interested in the real you.</p>
          <p>Now if you'll excuse me, I have a very important date with my sofa. <span role="img" aria-label="party">🥳</span></p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

/* ======================================================================
   POST 1: TRAVEL — REPHRASED
   ====================================================================== */
export function LinkedInPostCardTravelRephrased({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Kawaljeet Kaur" />
              <AvatarFallback>KK</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Kawaljeet Kaur</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">Growth Partner at The Date Crew</div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>4d</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (rephrased) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>Apparently, if you’re not a “traveller” or a “hiker,” you’re not marriage material.</p>
          <p>Scroll matrimony profiles and suddenly everyone’s a “passionate traveller” and a “hiker.” <span role="img" aria-label="smiling with sweat">😅</span></p>
          <p>Funny, because most of us are on the couch right now, trying to decide what to order for lunch. <span role="img" aria-label="yum">😋</span></p>
          <p>We’re so scared of seeming boring that we build adventure-résumés for our love lives.</p>
          <p>Here’s the truth: nobody falls in love with a travel itinerary.</p>
          <p>People fall in love with someone they can be comfortably, wonderfully “boring” with.</p>
          <p>Real compatibility isn’t climbing a mountain; it’s sharing a sofa in your oldest pajamas, in total silence, and still feeling perfectly happy.</p>
          <p>At <a className="text-sky-600 hover:underline font-medium" href="#">The Date Crew</a>, we skip the fake adventure-résumé. We’re interested in the real you.</p>
          <p>Now, if you’ll excuse me, I have a very important date with my couch. <span role="img" aria-label="party">🥳</span></p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

/* ======================================================================
   POST 2: JAINEEL — ORIGINAL (escape “-->” as “--&gt;”)
   ====================================================================== */
export function LinkedInPostCardJaineelOriginal({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Jaineel A." />
              <AvatarFallback>JA</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Jaineel A.</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">
                Founder @ PlayVerse solving for "Joy Infinitum" | 2x Entrepreneur with 1 successful exit
              </div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>1d</span>
                <Dot />
                <span>Edited</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (original) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>Respectfully, <a className="text-sky-600 hover:underline font-medium" href="#">Piyush Goyal</a></p>
          <p>"Aatma Nirbhar" Bharat, "Made in India", "Countering Tariffs with diversifying exports"........ etc., etc.</p>
          <p>This is the reality on the ground for a 1st time exporter:</p>
          <p>1) First, there is too much unnecessary paperwork and red tape while exporting products out of India. The best part? You have to repeat this process for each port (Mumbai vs Mundra, for example) and each time you change the means of export, for example, Sea vs Air, despite having a proper IEC certificate and AD code !!</p>
          <p>2) Then, there is friction while bringing funds into India. GST offsets (where applicable) or available export subsidies. More paperwork, mutiple follow-up needed for approval.</p>
          <p>3) And God forbid you are one of the unfortunate ones whose funds get stuck - You are toast......Literally</p>
          <p>--&gt; Back in 2016, in my earlier venture, we had supplied a shipment to a reputed company called Nerd Block in Canada, which unfortunately went belly up and was liquidated under proper bankruptcy laws of Canada (with appointed Liquidator, etc).</p>
          <p>Ofcourse, we got nothing and lost $80,000, but the torture we endured for the next 2 years from RBI in explaining why our goods were sent out but money didn't come in was a nightmare in itself.</p>
          <p>Social Media and Conventional Media is obsessed with IPOs, Valuations, Big talks but rarely take up the cause of solving real problems that are easily solvable with resolve.</p>
          <p>This post is one humble attempt to echo in those chambers that matter! Please tag a bureaucrat or someone in the Commerce Ministry who can hopefully do something about this unnecessary friction!</p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

/* ======================================================================
   POST 2: JAINEEL — REPHRASED
   ====================================================================== */
export function LinkedInPostCardJaineelRephrased({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header duplicated to preserve look */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Jaineel A." />
              <AvatarFallback>JA</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Jaineel A.</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">
                Founder @ PlayVerse solving for "Joy Infinitum" | 2x Entrepreneur with 1 successful exit
              </div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>1d</span>
                <Dot />
                <span>Edited</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (rephrased) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>Respectfully, <a className="text-sky-600 hover:underline font-medium" href="#">Piyush Goyal</a>,</p>
          <p>We hear a lot about “Aatmanirbhar Bharat,” “Made in India,” and “countering tariffs by diversifying exports.”</p>
          <p>Here’s the on-ground reality for a first-time exporter:</p>
          <p>1) <strong>Paperwork & red tape:</strong> Excessive, repetitive documentation. You redo it for each port (e.g., Mumbai vs. Mundra) and every time you switch modes (Sea vs. Air), even with a valid IEC and AD code.</p>
          <p>2) <strong>Bringing money back:</strong> Receiving funds, applying GST offsets (where applicable) or export incentives demands more forms and multiple follow-ups for approvals.</p>
          <p>3) <strong>When funds get stuck:</strong> You’re in real trouble.</p>
          <p>— In 2016, at an earlier venture, we shipped to a reputed Canadian company, Nerd Block. It went bankrupt and was liquidated. We recovered nothing—losing <strong>$80,000</strong>—and then spent two years answering RBI queries about why proceeds didn’t arrive despite documented bankruptcy.</p>
          <p>Social and mainstream media celebrate IPOs and valuations, but rarely push for simple, practical fixes to long-standing frictions.</p>
          <p>This post is a humble attempt to reach the rooms that matter. Please tag a bureaucrat or someone in the Commerce Ministry who can help remove this unnecessary friction.</p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

/* ======================================================================
   POST 3: DARIUS — ORIGINAL
   ====================================================================== */
export function LinkedInPostCardDariusOriginal({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Darius Burschka" />
              <AvatarFallback>DB</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Darius Burschka</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">Professor CIT (TUM) - Visual Analysis of Dynamic Scenes</div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>1d</span>
                <Dot />
                <span>Edited</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (original) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>Mixed feelings. I am happy to see someone using a #novel method to solve an old problem, but here comes my first remark. Why is everything thrown into the same pool "#AI", where everyone thinks some #LLM was involved. We need to start disambiguate the different "learning approaches" or useful applications will keep useless approaches (used by most) alive.</p>
          <p>"THOR AI sidesteps these limitations [classical integration techniques would require computational times exceeding the age of the universe] using a mathematical innovation known as tensor train cross interpolation. This technique breaks down the high-dimensional data cube of the equation into smaller, linked tensors essentially simplifying an impossible calculation into a manageable one."</p>
          <p>My question is if the novel method really needs AI or if this could also be ran on a classical system. It seems like someone used a novel approach and packaged it into "AI hype" to get funding?</p>
          <p><a className="text-sky-600 hover:underline font-medium" href="https://lnkd.in/ecSxxJk4">https://lnkd.in/ecSxxJk4</a></p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

/* ======================================================================
   POST 3: DARIUS — REPHRASED
   ====================================================================== */
export function LinkedInPostCardDariusRephrased({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Darius Burschka" />
              <AvatarFallback>DB</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Darius Burschka</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">Professor CIT (TUM) - Visual Analysis of Dynamic Scenes</div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>1d</span>
                <Dot />
                <span>Edited</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (rephrased) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>Mixed feelings. Great to see a <span className="font-medium">#novel</span> method tackle an old problem — but here’s my first concern. Why is everything tossed into the same “#AI” bucket, as if a <span className="font-medium">#LLM</span> was always involved? We should clearly distinguish learning approaches; otherwise useful applications may keep weak ones (popular, but unhelpful) alive.</p>
          <p>THOR AI claims to avoid the classic bottlenecks — where traditional integration would take longer than the age of the universe — by using <em>tensor train cross interpolation</em>. In short, it decomposes a high-dimensional equation into smaller, linked tensors, turning an intractable computation into a manageable one.</p>
          <p>My question: does this method actually require AI, or could a classical system run it just as well? It reads like a novel technique repackaged as “AI hype” for funding.</p>
          <p><a className="text-sky-600 hover:underline font-medium" href="https://lnkd.in/ecSxxJk4">https://lnkd.in/ecSxxJk4</a></p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}
/* =====================================================================================
   RANJANI MANI
   ===================================================================================== */

   export function LinkedInPostCardRanjaniOriginal({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Ranjani Mani" />
                <AvatarFallback>RM</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Ranjani Mani</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">Director and Country Head, Gen…</div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>8h</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body: EXACT ORIGINAL TEXT */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>I did this thing in school</p>
            <p>Cover my ears and rock to cut out the noise around to focus on my books, the nerd that I was</p>
            <p>My friends still tease me about it</p>
            <p>Met a few school friends last weekend — people who knew other before the titles, before the metrics, before life started needing calendars.</p>
            <p>There is something strange about meeting people you know from when you were 3 years old - you meet after decades and yet fall right into rhythm in minutes</p>
            <p>It’s strange how time folds when you meet them. The laughter returns effortlessly, but so does a mirror — showing who you were, who you became, and what you may have lost in between.</p>
            <p>We’ve all taken different routes since then — some brave, some accidental, all real. And that contrast is what makes it beautiful.</p>
            <p>Maybe growth isn’t about becoming someone new. It’s about remembering your roots — and choosing which parts of yourself to keep as you evolve.</p>
            <p>Funny how the people who knew our unpolished selves still see us the dearest.<br/>Who would your 15-year-old self be proud to meet today?</p>
            <p>*************************************</p>
            <p>Ranjani Mani<br/>#reviewswithranjani</p>
            <p>#Technology | #Books | #BeingBetter</p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  
  export function LinkedInPostCardRanjaniRephrased({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header (same UI) */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Ranjani Mani" />
                <AvatarFallback>RM</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Ranjani Mani</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">Director and Country Head, Gen…</div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>8h</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body: REPHRASED (same layout) */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>In school, I used to cover my ears and rock back and forth to block out noise and study — peak nerd energy.</p>
            <p>My friends still tease me about it.</p>
            <p>Last weekend I met old school friends — the kind who knew us before job titles, metrics, and calendar chaos.</p>
            <p>There’s something uncanny about meeting people you’ve known since you were three: decades pass, and within minutes the rhythm returns.</p>
            <p>Time folds. The laughter is effortless — and so is the mirror it holds up: who you were, who you became, and what you may have lost along the way.</p>
            <p>We’ve all taken different paths — some brave, some accidental, all real. That contrast is part of the beauty.</p>
            <p>Maybe growth isn’t becoming someone new, but remembering your roots — choosing which parts of yourself to keep as you evolve.</p>
            <p>The people who knew our unpolished selves still see us most clearly. Who would your 15-year-old self be proud to meet today?</p>
            <p>*************************************</p>
            <p>Ranjani Mani<br/>#reviewswithranjani</p>
            <p>#Technology | #Books | #BeingBetter</p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  
  /* =====================================================================================
     SUNITA VENKATA…
     ===================================================================================== */
  
  export function LinkedInPostCardSunitaOriginal({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Sunita Venkata…" />
                <AvatarFallback>SV</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Sunita Venkata…</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">Investor | Founder | Advisor | Cu…</div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>11h</span>
                  <Dot />
                  <span>Edited</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body: EXACT ORIGINAL TEXT */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>An unforgettable flight — without ever leaving the ground! And it was lovely catching up with Sam Al-Schamma after a few years!</p>
            <p>I had a truly fascinating experience at Flight Experience Singapore, flying a Boeing 737 simulator under the guidance of Flight Instructor Sam Al-Schamma and his wonderful crew.</p>
            <p>It began with a detailed pre-flight briefing in their lounge, and then unlike every other flight, I turned left into the cockpit instead of right into the cabin! Really thrilling to slide into the pilot's seat while Sam was my co-pilot! From there, Sam walked me through the controls, calmly and expertly, and before I knew it, we were taking off from Changi Runway 1, circling Singapore!</p>
            <p>What struck me most was the sheer sophistication of the systems designed to keep us safe when we fly and the incredible realism of the simulator. Seeing the familiar skyline, runways, and even the coastline from the pilot’s seat was surreal.</p>
            <p>Sam, a qualified pilot and hypnotherapist who helps people overcome their fear of flying, was the perfect instructor — empathetic, and deeply knowledgeable.</p>
            <p>For anyone curious about aviation, or looking for a unique, hands-on experience, I highly recommend giving this a try.</p>
            <p>👉 <a className="text-sky-600 hover:underline font-medium" href="https://lnkd.in/gXB_6Mfa">https://lnkd.in/gXB_6Mfa</a></p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  
  export function LinkedInPostCardSunitaRephrased({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header (same UI) */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Sunita Venkata…" />
                <AvatarFallback>SV</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Sunita Venkata…</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">Investor | Founder | Advisor | Cu…</div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>11h</span>
                  <Dot />
                  <span>Edited</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body: REPHRASED (same layout) */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>A flight I’ll never forget — and we never left the ground. I also got to reconnect with Sam Al-Schamma after years.</p>
            <p>At Flight Experience Singapore I flew a Boeing 737 simulator with Flight Instructor Sam Al-Schamma and his fantastic crew.</p>
            <p>We started with a thorough pre-flight briefing. Then, unlike a normal flight, I turned left into the cockpit — not right into the cabin — and slid into the pilot’s seat while Sam co-piloted. He walked me through the controls, calm and precise, and soon we were rolling down Changi Runway 1, circling Singapore.</p>
            <p>Two things stood out: the sophistication of the safety systems and how real the simulator felt — skyline, runways, even the coastline, all from the pilot’s view.</p>
            <p>Sam is a licensed pilot and hypnotherapist who helps people overcome fear of flying — empathetic and deeply knowledgeable.</p>
            <p>If you’re curious about aviation or want a unique, hands-on experience, I highly recommend it.</p>
            <p>👉 <a className="text-sky-600 hover:underline font-medium" href="https://lnkd.in/gXB_6Mfa">https://lnkd.in/gXB_6Mfa</a></p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  /* =====================================================================================
   AMIT KUMAR B. (VETERAN)
   ===================================================================================== */
export function LinkedInPostCardAmitOriginal({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Amit Kumar Bhardwaj (Veteran)" />
              <AvatarFallback>AK</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Amit Kumar Bhardwaj (Veteran)</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">
                International Team Lead @ Evergreen | Safety operations centre l…
              </div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>2d</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body: EXACT ORIGINAL TEXT */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>They crowned concrete, but ignored a monolith carved from a single rock.</p>
          <p>
            Christ the Redeemer in Rio de Janeiro was completed in 1931, built over 9 years (1922–1931)
            using reinforced concrete and soapstone tiles, supported by modern cranes and machinery.
          </p>
          <p>
            Now compare that to Kailasa Temple at Ellora, carved around 756–773 CE during the Rashtrakuta
            dynasty — a monolithic structure excavated top-down from a single basalt mountain. Nearly
            200,000 tons of rock were manually removed with precision, without steel, cement, or modern tools.
          </p>
          <p>It’s not just a temple; it’s an engineering masterpiece that has stood strong for over 1,200 years.</p>
          <p>
            Yet, the world crowned concrete and ignored carved stone.
            This shows the hypocrisy of the World Wonder Foundation, which didn’t even shortlist Ellora Caves in the top 21 monuments.
          </p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

export function LinkedInPostCardAmitRephrased({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header (same UI) */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Amit Kumar Bhardwaj (Veteran)" />
              <AvatarFallback>AK</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Amit Kumar Bhardwaj (Veteran)</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">
                International Team Lead @ Evergreen | Safety operations centre l…
              </div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>2d</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body: REPHRASED */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>We celebrate concrete, yet overlook a wonder carved from a single rock.</p>
          <p>
            Christ the Redeemer (Rio) finished in 1931 after nine years, built with reinforced concrete and
            soapstone tiles using modern cranes and machinery.
          </p>
          <p>
            Contrast that with the Kailasa Temple at Ellora (756–773 CE): a monolith excavated top-down from
            basalt. Nearly 200,000 tons of stone were removed by hand — no steel, cement, or modern tools —
            with astonishing precision.
          </p>
          <p>That’s more than a temple; it’s an engineering feat standing strong for 1,200+ years.</p>
          <p>
            Yet carved stone was ignored while concrete was crowned. The World Wonder Foundation didn’t even
            shortlist Ellora among the top 21 — a baffling omission.
          </p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}
/* =====================================================================================
   NICHOLAS NOURI
   ===================================================================================== */
   export function LinkedInPostCardNicholasOriginal({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Nicholas Nouri" />
                <AvatarFallback>NN</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Nicholas Nouri</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">
                  Founder | APAC Entrepreneur of the year | Author | AI Global tale…
                </div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>Ad</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body: EXACT ORIGINAL TEXT */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>
              The home robot, priced around $20,000, is (almost) here. It promises to handle your household chores.
              Think sweeping floors, folding laundry, even washing dishes.
            </p>
            <p>But there’s a small - and important - detail.</p>
            <p>
              If the robot struggles with a task, a human operator might step in remotely to guide it. In other words,
              someone could be controlling it from afar, seeing what it sees. The company behind it is transparent about
              this - they use the captured data to improve performance, and it’s stored securely. Still, it raises some
              uncomfortable questions.
            </p>
            <p>
              What does “secure” really mean when a human can see into your living space - potentially spotting sensitive
              details like financial documents, or just private moments? Is it on the user to make their home “robot-safe,”
              the same way parents childproof a house or pet owners adjust for safety?
            </p>
            <p>
              Would you trust a $20,000 robot to tidy your living room, knowing it might need a human’s eyes to help?
            </p>
            <p>#innovation #technology #future #management #startups</p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  
  export function LinkedInPostCardNicholasRephrased({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header (same UI) */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Nicholas Nouri" />
                <AvatarFallback>NN</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Nicholas Nouri</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">
                  Founder | APAC Entrepreneur of the year | Author | AI Global tale…
                </div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>Ad</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body: REPHRASED */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>
              A ~$20,000 home robot is nearly here, promising to sweep, fold laundry, and wash dishes.
            </p>
            <p>One important caveat:</p>
            <p>
              When the robot gets stuck, a human may remote in to guide it — seeing what it sees. The company says this
              data improves performance and is stored securely, but it still raises privacy questions.
            </p>
            <p>
              If a person can peer into your living room, what counts as “secure”? Could they glimpse sensitive papers or
              private moments? Are users expected to make their homes “robot-safe,” like child-proofing or pet-proofing?
            </p>
            <p>
              Would you trust a $20k robot to tidy up, knowing it might need human eyes on occasion?
            </p>
            <p>#innovation #technology #future #management #startups</p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }

/* =====================================================================================
   CHARLES PACKER
   ===================================================================================== */
export function LinkedInPostCardCharlesOriginal({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Charles Packer" />
              <AvatarFallback>CP</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Charles Packer</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">Co-Founder & CEO at Letta</div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>5d</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body: EXACT ORIGINAL TEXT */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>
            Today we’re releasing Context-Bench, a benchmark (and live leaderboard!) measuring LLMs on Agentic Context
            Engineering. Context-Bench directly measures the ability of an agent to manually manipulate its own context
            window, a necessary condition for creating AI agents that can self-improve and continually learn.
          </p>
          <p>
            In 2023 and 2024, we manually loaded context into agents, copy-pasting code snippets into ChatGPT. RAG also
            emerged as a dominant paradigm, and a lot of attention focused around tips and tricks to identify "chunks"
            of data that could be injected into a context window prior to inference.
          </p>
          <p>
            In 2025, it’s clear that RAG is "dead", and that the future is agentic context engineering. Modern agents
            like Claude Code, Codex, and Cursor use tools to retrieve information into their context windows, from
            searching the web and external APIs/MCPs, to editing code with Bash and Unix tools, to more advanced
            use-cases such as editing long-term memories and loading skills.
          </p>
          <p>
            Frontier AI labs like Anthropic are now explicitly training their new models to be "self-aware" of their
            context windows to increase their context engineering capabilities. Despite the critical importance of
            agentic context engineering, there’s no clear open benchmark for evaluating this capability.
          </p>
          <p>
            That’s why we built Context-Bench: to evaluate how well frontier models can chain file operations, trace
            entity relationships, and manage complex multi-step retrieval for long-horizon tasks. Context-Bench is a
            challenging benchmark: even Sonnet 4.5 only hits 74%.
          </p>
          <p>
            Context-Bench is an exciting moment for the open source community: the gap between OS LLMs with 6M token
            models and frontier models appears to be narrowing.
          </p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

export function LinkedInPostCardCharlesRephrased({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header (same UI) */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Charles Packer" />
              <AvatarFallback>CP</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Charles Packer</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">Co-Founder & CEO at Letta</div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>5d</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body: REPHRASED */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>
            We’re launching **Context-Bench**—a public benchmark and leaderboard for *agentic context engineering*.
            It measures how well an agent can manage and modify its own context window, a capability needed for
            self-improving agents.
          </p>
          <p>
            After years of copy-pasting context (and the rise of RAG), the field is shifting: modern agents pull,
            edit, and organize information inside their windows using tools and APIs. Long-term memories and skills can
            be loaded on the fly.
          </p>
          <p>
            Labs are even training models to be context-aware. Yet there hasn’t been an open benchmark to evaluate this.
          </p>
          <p>
            Context-Bench tests chaining file ops, tracking entities, and managing multi-step retrieval over long
            horizons. It’s tough—Sonnet 4.5 scores ~74%.
          </p>
          <p>
            The encouraging sign: open-source models with very large windows are catching up to frontier systems.
          </p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}
/* =====================================================================================
   REEMA BHARTI
   ===================================================================================== */
   export function LinkedInPostCardReemaOriginal({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Reema Bharti" />
                <AvatarFallback>RB</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Reema Bharti</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">
                  Growth & Monetization, Flipkart Ads | Ex-Amazon, Ex-MakeMyT…
                </div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>1d</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body: EXACT ORIGINAL TEXT */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>Our team at MakeMyTrip had 0 layoffs during Covid even when travel shut down!</p>
            <p>In 2020-21, corporate travel was zero.<br/>We had every reason to be cut.<br/>But instead, we were told—“Your jobs are safe.”</p>
            <p>
              So we showed up daily, trying anything to earn a rupee—even selling sanitizers through brand tie-ups.
              Because when your company stands by you, you go all in for it.
            </p>
            <p>
              In times like these when layoffs dominate headlines, I keep remembering that phase.
              Some companies don’t just survive tough times—<br/>They stand taller because of how they treat their people.
              My team at MakeMyTrip was one of them 🙌
            </p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  
  export function LinkedInPostCardReemaRephrased({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header (same UI) */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Reema Bharti" />
                <AvatarFallback>RB</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Reema Bharti</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">
                  Growth & Monetization, Flipkart Ads | Ex-Amazon, Ex-MakeMyT…
                </div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>1d</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body: REPHRASED */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>During Covid, even as travel stopped, our MakeMyTrip team had zero layoffs.</p>
            <p>
              2020–21 corporate travel was at zero. We expected cuts. Instead we heard: “Your jobs are safe.”
            </p>
            <p>
              So we showed up every day and found ways to keep moving—even selling sanitizers via brand tie-ups.
              When a company backs you, you go all in.
            </p>
            <p>
              With layoffs back in the news, I think of that period often. Some companies don’t just survive tough
              stretches; they stand taller because of how they treat people. Ours was one of them. 🙌
            </p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
/* =====================================================================================
   STEFANO PUNTONI
   ===================================================================================== */
   export function LinkedInPostCardStefanoOriginal({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Stefano Puntoni" />
                <AvatarFallback>SP</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Stefano Puntoni</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">Wharton Professor and Behavioral Scientist</div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>1d</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body: EXACT ORIGINAL TEXT */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>
              Every time a new powerful technology comes along, people worry about jobs. One reason is that there is a
              difference in the time horizons of the emerging threat and opportunity.
            </p>
            <p>
              The threat to existing jobs is apparent early on as people quickly match the emerging capabilities to those
              required for work tasks.
            </p>
            <p>
              The opportunity created by the new technology is much harder to see early on because the new jobs created by
              the technology start emerging only slowly. It takes time and imagination to figure those out.
            </p>
            <p>
              This article (link in comment) from <span className="underline">The Washington Post</span> lists 16 new jobs
              created by AI. The list includes jobs like “interaction designer”, “knowledge architect”, and “orchestration
              engineer”. Many more jobs will surely follow.
            </p>
            <p>
              To be clear: this should not be an excuse for complacency. Most jobs will be affected and many will be
              displaced. Companies and governments need to have policies in place to help support and upskill those
              affected.
            </p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  
  export function LinkedInPostCardStefanoRephrased({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header (same UI) */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Stefano Puntoni" />
                <AvatarFallback>SP</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Stefano Puntoni</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">Wharton Professor and Behavioral Scientist</div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>1d</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body: REPHRASED */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>
              Each wave of powerful tech brings job anxiety. A key reason: the *threat* shows up fast, while the
              *opportunity* takes longer to materialize.
            </p>
            <p>
              It’s easy to map new capabilities onto current tasks and see what could be automated.
            </p>
            <p>
              It’s harder to imagine the roles that will emerge later. Those appear slowly and require creativity to see.
            </p>
            <p>
              A recent list (link in comments) from <span className="underline">The Washington Post</span> highlights
              16 AI-created roles—like interaction designer, knowledge architect, and orchestration engineer—with more on
              the way.
            </p>
            <p>
              None of this argues for complacency. Many jobs will change or disappear. We’ll need policies and programs to
              support and upskill affected workers.
            </p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }


// ---------------------
// POST: Evolving AI — ORIGINAL
// ---------------------
export function LinkedInPostCardEvolvingAIOriginal({ likes = 44 }: { likes?: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Evolving AI" />
              <AvatarFallback>EA</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Evolving AI</span>
              </div>
              <div className="text-muted-foreground text-sm">108,775 followers</div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>21h</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body: EXACT ORIGINAL TEXT */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>🎉 New York restaurants have started hiring cashiers from the Philippines who work remotely through Zoom for just $3.75 an hour.</p>
          <p>Customers walk up to a tablet and speak to someone thousands of miles away who takes their order in real time.</p>
          <p>For many small restaurant owners, it’s a way to cut costs and stay open as rent and wages keep rising in the city.</p>
          <p>But this shift is raising questions about what comes next.</p>
          <p>If people can already run a register from across the world, how long before AI voice and vision systems take over the job completely?</p>
          <p>The same setup could easily use speech recognition and camera tools to identify customers, take orders, and process payments, with no human involved at all.</p>
          <p>What are your thoughts on this? 🤔💬</p>
          <p className="text-muted-foreground">Want to keep up with AI?<br />
            Follow <span className="text-sky-600 font-medium">Evolving AI</span> to stay ahead of your competition (trusted by +4 million followers online)
          </p>
          <p>🧵 Join 80,000+ newsletter readers and stay updated on the latest AI insights:
            <a className="text-sky-600 hover:underline font-medium" href="https://lnkd.in/em9B--mb"> https://lnkd.in/em9B--mb</a>
          </p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

// ---------------------
// POST: Evolving AI — REPHRASED
// ---------------------
export function LinkedInPostCardEvolvingAIRephrased({ likes = 44 }: { likes?: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header (same UI) */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Evolving AI" />
              <AvatarFallback>EA</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Evolving AI</span>
              </div>
              <div className="text-muted-foreground text-sm">108,775 followers</div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>21h</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body: REPHRASED */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>🎉 Some NYC restaurants now use remote cashiers in the Philippines—on Zoom—for about $3.75/hour.</p>
          <p>Guests speak to a tablet; a person thousands of miles away takes the order live.</p>
          <p>For small owners, it’s a lifeline as rent and wages rise. But it also raises the bigger question: what comes next?</p>
          <p>If a register can be run from abroad today, how soon before AI voice + vision replace the role entirely?</p>
          <p>The same setup could add speech recognition and cameras to identify customers, take orders, and process payments—no human in the loop.</p>
          <p>Thoughts? 🤔💬</p>
          <p className="text-muted-foreground">Follow <span className="text-sky-600 font-medium">Evolving AI</span> for more updates, and join 80k+ readers:
            <a className="text-sky-600 hover:underline font-medium" href="https://lnkd.in/em9B--mb"> https://lnkd.in/em9B--mb</a>
          </p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}
// ---------------------
// POST: R. Paulo Delgado — ORIGINAL
// ---------------------
export function LinkedInPostCardPauloOriginal({ likes = 44 }: { likes?: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="R. Paulo Delgado" />
              <AvatarFallback>RD</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">R. Paulo Delgado</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">Developing custom apps for businesses since 2003 / Occasional…</div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>2d</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body: EXACT ORIGINAL TEXT */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>After using AI extensively for 4 coding projects over the last year, I can say unequivocally that:</p>
          <p>1. Used in moderation (autocomplete, small suggestions, one-off tasks), it’s a game-changer.</p>
          <p>2. But used more than that, it becomes the biggest barrier in the road of getting production-ready code.</p>
          <p>You’re ultimately better off reading the docs and doing things yourself, even if it takes days.</p>
          <p>We all “sensed” AI’s stupidity in the creative world.</p>
          <p>But its lack of real intelligence is undeniable in the technical world.</p>
          <p>Man, it…is…really…STUPID. <span role="img" aria-label="laugh">😅</span></p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

// ---------------------
// POST: R. Paulo Delgado — REPHRASED
// ---------------------
export function LinkedInPostCardPauloRephrased({ likes = 44 }: { likes?: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header (same UI) */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="R. Paulo Delgado" />
              <AvatarFallback>RD</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">R. Paulo Delgado</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">Developing custom apps for businesses since 2003 / Occasional…</div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>2d</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body: REPHRASED */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>After a year using AI across four coding projects, here’s my blunt take:</p>
          <p>1) Used lightly—autocomplete, tiny suggestions, one-off helpers—AI is fantastic.</p>
          <p>2) Lean on it heavily and it becomes the biggest obstacle to shipping production-ready code.</p>
          <p>You’ll usually finish faster by reading docs and writing the code yourself.</p>
          <p>We all sensed the limits of AI in creative work; in engineering, those limits are impossible to miss.</p>
          <p>Bottom line: for serious technical work, it’s often… painfully… dumb. <span role="img" aria-label="laugh">😅</span></p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}
/* ======================================================================
   POST: MADHAV KASTURIA — ORIGINAL
   ====================================================================== */
   export function LinkedInPostCardMadhavOriginal({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Madhav Kasturia" />
                <AvatarFallback>MK</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Madhav Kasturia</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">
                  Founder &amp; CEO @ Zippee — India’s #1 Quick Commerce Logistics
                </div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>1w</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body (original) */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>How does a company that would have shut down in just 7 days end up becoming the largest fashion &amp; ecommerce giant in India?</p>
            <p>Bengaluru, 2013. Seven days of cash. Payroll is about to bounce. Amazon had just landed.</p>
            <p><b>Flipkart vs Amazon</b> was the headline.</p>
            <p><a className="text-sky-600 hover:underline font-medium" href="#">Myntra</a> looked like collateral damage.<br/>But Mukesh Bansal didn’t write a eulogy. He bought time and picked a lane.</p>
            <p>→ A $5M bridge when capital dried up.<br/>→ A $330M sale to Flipkart in 2014 to get rail access and a long runway.</p>
            <p>Then the hard call that changed the P&amp;L: own fashion, not “e-com”.</p>
            <p>1) Private labels showed up first — Roadster, HRX &amp; friends. By 2017 they were ~40% of GMV. That meant gross margin to fund growth, not just discounting.</p>
            <p>2) Global brands followed. Nike, H&amp;M, Puma plugged in because the pipes worked and the audience was already there.</p>
            <p>3) Jabong was acquired in 2016, and the category got consolidated.</p>
            <p>They then built a shopping holiday (EORS), a loyalty loop (Insider), and returns that didn’t break the business.</p>
            <p>Fashion went from “too risky to sell online” to a weekly habit.</p>
            <p>The numbers make the case: ₹773 crore in FY15 to ₹6,043 crore in FY25. From losses every year to a ₹548 crore profit in FY25.</p>
            <p>18× scale in a decade, while fashion itself became ~30% of India’s e-com GMV, and Myntra now clears about a third of that pie.</p>
            <p><b>Simple takeaway?</b><br/>In Indian e-com, winners are merchants of habit, not merchants of everything.</p>
            <p>Don’t build an app; build the operating system for your category and for your customer’s week.</p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  
  /* ======================================================================
     POST: MADHAV KASTURIA — REPHRASED (readability)
     ====================================================================== */
  export function LinkedInPostCardMadhavRephrased({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header (same UI) */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Madhav Kasturia" />
                <AvatarFallback>MK</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Madhav Kasturia</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">
                  Founder &amp; CEO @ Zippee — India’s #1 Quick Commerce Logistics
                </div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>1w</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body (rephrased) */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>2013: Myntra had seven days of cash while Amazon was entering India. Instead of winding down, Mukesh Bansal bought time (a $5M bridge) and reach (a $330M sale to Flipkart in 2014).</p>
            <p>The strategic bet: <b>own fashion</b>, not generic e-commerce.</p>
            <p>• Launch private labels (Roadster, HRX, etc.). By 2017 they drove ~40% of GMV—funding growth with margin, not discounts.</p>
            <p>• Bring global brands once the pipes were ready (Nike, H&amp;M, Puma).</p>
            <p>• Consolidate the category (Jabong acquisition).</p>
            <p>Then engineer habit: EORS shopping holiday, Insider loyalty, and returns that didn’t wreck unit economics.</p>
            <p>Outcome: from ₹773cr FY15 to ₹6,043cr FY25, swinging from losses to ₹548cr profit. Fashion ≈30% of India e-com GMV; Myntra handles ~⅓ of that.</p>
            <p><b>Lesson:</b> in Indian e-com, winners build weekly habits—effectively the OS for a category—rather than selling “everything”.</p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  
  /* ======================================================================
     POST: GARY VAYNERCHUK — ORIGINAL
     ====================================================================== */
  export function LinkedInPostCardGaryOriginal({ likes }: { likes: number }) {
    return (
      <Card className="max-w=[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Gary Vaynerchuk" />
                <AvatarFallback>GV</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Gary Vaynerchuk</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">
                  Chairman — VaynerX; CEO — VaynerMedia; Creator — VeeFriends
                </div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>1w</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body (original) */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>The reason these 25-year-olds don’t want to come and work for you for $62k or $40k is because they can make that much flipping sh*t on eBay …</p>
            <p>It’s because they can make $100K in brand deals on TikTok in a snap.</p>
            <p>And I’m not talking about Charlie D’Amelio and Logan Paul .. I’m talking about the millions of everyday people that are making $50K, $60K, $70K, $80K, $120K a year in YouTube AdSense, in brand deals, and on flipping stuff.</p>
            <p>Everyone wants to talk about the younger generation being “lazy”… I think they’ve just finally figured out their options. They’re not “entitled” .. they’re just awake to their alternatives: flip life, making content, starting a podcast with their friends.. There’s just so much more opportunity for people to do stuff they actually care about.</p>
            <p>The question for us as business owners is, how will we stand out? A paycheck or fancy job title is no longer enough .. How can you add value?</p>
            <p>PS: of course, there’s entitled and delusional and lazy youngsters, but I have seen that in Boomers, X’ers, and Millennials too .. we’re more alike than we think.</p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  
  /* ======================================================================
     POST: GARY VAYNERCHUK — REPHRASED (readability)
     ====================================================================== */
  export function LinkedInPostCardGaryRephrased({ likes }: { likes: number }) {
    return (
      <Card className="max-w=[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header (same UI) */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Gary Vaynerchuk" />
                <AvatarFallback>GV</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Gary Vaynerchuk</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">
                  Chairman — VaynerX; CEO — VaynerMedia; Creator — VeeFriends
                </div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>1w</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
              <button className="p-1 rounded hover:bg-muted" aria-label="More options">
                <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
              </button>
            </div>
          </div>
  
          {/* Body (rephrased) */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>Many 20-somethings skip $40–62k jobs because they can earn similar money elsewhere—flipping on eBay, YouTube AdSense, brand deals, or TikTok.</p>
            <p>This isn’t about a few celebrities. Millions of regular creators make $50k–$120k a year across these channels.</p>
            <p>So when we label them “lazy,” we miss the point. They’ve discovered alternatives they care about: creating content, flipping, launching podcasts with friends.</p>
            <p>For business owners, that means a title or salary isn’t enough. The edge is <b>real value</b> and compelling work.</p>
            <p>And yes—every generation has entitled people. That’s not unique to Gen Z.</p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }

  /* ======================================================================
   POST: AMIT GUPTA — ORIGINAL
   ====================================================================== */
export function LinkedInPostCardAmitGuptaOriginal({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Amit Gupta" />
              <AvatarFallback>AG</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Amit Gupta</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">
                Associate Director — Experience Design & AI Consulting
              </div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>1d · Edited</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (original) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>The problem isn’t that your product is boring. It’s that your performance is invisible.</p>
          <p>Last evening, I went to a restaurant called Indian Pavilion in Orlando, Florida and tried their viral TikTok chaat—an ordinary chaat, served in an extraordinary style.</p>
          <p>It wasn’t just food. It was theatre.</p>
          <p>The waiter brought it out like a magician revealing a trick.</p>
          <p>Lights. Smoke. Timing.</p>
          <p>Every second designed to make people pull out their phones.</p>
          <p>It reminded me of <span className="text-sky-600 underline">Joe Pine</span> who said that every business is a stage— and every customer experience is a performance.</p>
          <p>Because the product wasn’t the chaat. The product was the performance.</p>
          <p>And that’s true for every business.</p>
          <p>Whether you run a restaurant, a clinic, or a consulting firm —<br/>- your employees are the actors,<br/>- your product is the prop,<br/>- and your business is the stage.</p>
          <p>People don’t just buy things anymore. They buy moments that feel worth remembering.</p>
          <p>The difference between “just another” and “that was incredible” is how you stage the experience.</p>
          <p>If you’re an entrepreneur who feels your business has become routine, or if you want me to review how your experience can create more wow, reach out to me.</p>
          <p>Let’s turn your business into a stage worth remembering.</p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

/* ======================================================================
   POST: AMIT GUPTA — REPHRASED (readability)
   ====================================================================== */
export function LinkedInPostCardAmitGuptaRephrased({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header (same UI) */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Amit Gupta" />
              <AvatarFallback>AG</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Amit Gupta</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">
                Associate Director — Experience Design & AI Consulting
              </div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>1d · Edited</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (rephrased) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>Your product may be fine; what’s missing is the <em>performance</em>.</p>
          <p>At Indian Pavilion (Orlando) I tried their viral TikTok chaat. The dish was simple. The delivery was theatre—smoke, lights, timing—the whole room watching.</p>
          <p>It proved Joe Pine’s point: every business is a stage, and every experience is a performance.</p>
          <p>The chaat wasn’t the product. The <em>moment</em> was.</p>
          <p>Whatever you run—restaurant, clinic, consultancy—employees are the actors, the offering is the prop, and the business is the stage.</p>
          <p>People don’t just buy things; they buy memories.</p>
          <p>The gap between “okay” and “unforgettable” is how you stage the experience. If your brand feels routine, let’s review the performance and add back the wow.</p>
          <p>Make your business a stage worth remembering.</p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

/* ======================================================================
   POST: RUSSELL ADAMS — ORIGINAL
   ====================================================================== */
export function LinkedInPostCardRussellAdamsOriginal({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Russell Adams" />
              <AvatarFallback>RA</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Russell Adams</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">
                A-hed editor at The Wall Street Journal
              </div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>23h</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (original) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>In an increasingly cashless world, a penny shortage doesn’t seem like a big deal. But at chains like Burger King, it’s cause for panic. The prospect of running out of the one-cent coin has franchisees stockpiling pennies, even asking employees to pick up rolls when any of them go to the bank.</p>
          <p>The problem: many fast-food chains are still heavily reliant on cash transactions, and the prospect of not being able to make exact change is daunting for both customers and cashiers who are getting a crash course in rounding. “You are trying to have lunch or dinner and you are stuck with a math quiz,” said Jimmy Harmon, chief executive of a company that owns 25 Burger Kings in Indiana, Michigan and Ohio.</p>
          <p><span className="text-sky-600 underline">Heather Haddon’s</span> latest A-hed is a fascinating and funny look at why some people are still fighting for the dying coin.</p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

/* ======================================================================
   POST: RUSSELL ADAMS — REPHRASED (readability)
   ====================================================================== */
export function LinkedInPostCardRussellAdamsRephrased({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header (same UI) */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Russell Adams" />
              <AvatarFallback>RA</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Russell Adams</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">A-hed editor at The Wall Street Journal</div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>23h</span>
                <Dot />
                <Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (rephrased) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>We’re more cashless than ever, yet a simple penny shortage is scrambling fast-food operations.</p>
          <p>Burger King franchisees are hoarding rolls of coins and asking staff to grab pennies at the bank—because many stores still depend on cash and can’t easily make exact change.</p>
          <p>Customers and cashiers are suddenly doing rounding math at the register. As one operator put it: “You came for lunch and got a pop quiz.”</p>
          <p><span className="text-sky-600 underline">Heather Haddon’s</span> new A-hed digs into why people keep defending the one-cent coin—and what happens when it disappears.</p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}
/* ======================================================================
   POST: “Advisors are like barnacles” — ORIGINAL (Dave Kellogg)
   ====================================================================== */
   export function LinkedInPostCardBarnaclesOriginal({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Dave Kellogg" />
                <AvatarFallback>DK</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Dave Kellogg</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">EIR, Independent Consultant, Author</div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>15h</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
  
          {/* Body (original) */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>Advisors are like barnacles.</p>
            <p>Your company collects them over time: one to help a first-time CEO, one for finance and legal, one who’s close to a VC, another tied into academia to track the latest tech—then another.</p>
            <p>I once took over as CEO and reviewed every open option grant. The cofounder was gone. The professor wouldn’t return calls. The brand-name advisor was only useful for a market we’d already exited. I hired a CFO; we didn’t need the “finance/legal” advisor anymore. The VC’s friend wasn’t adding value.</p>
            <p>I’m not saying don’t use advisors. I’m saying they <em>stick</em>. They grow on the business unless you scrape them off.</p>
            <p>If they don’t answer the phone, scrape. If their expertise is no longer relevant, scrape. If they aren’t adding value now—and you don’t see a path where they will—scrape.</p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  
  /* ======================================================================
     POST: “Advisors are like barnacles” — REPHRASED (clearer, same meaning)
     ====================================================================== */
  export function LinkedInPostCardBarnaclesRephrased({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header same UI as original */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Dave Kellogg" />
                <AvatarFallback>DK</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Dave Kellogg</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">EIR, Independent Consultant, Author</div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>15h</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
  
          {/* Body (rephrased for readability) */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>Advisors accumulate like barnacles.</p>
            <p>As the company grows, you add one for coaching, one for finance/legal, one with VC connections, one with university ties—until you’ve got a crowd.</p>
            <p>When I stepped in as CEO, I audited every grant. The star professor didn’t return calls. The big name only mattered in a market we’d left. After hiring a CFO, the “finance/legal” advisor was redundant. And the VC’s friend wasn’t moving the needle.</p>
            <p>Advisors can be useful. They also linger. Review them regularly.</p>
            <p>No response? Remove. Expertise no longer relevant? Remove. Not adding value today and unlikely to tomorrow? Remove.</p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  
  /* ======================================================================
     POST: Live social shopping — ORIGINAL (rename from Gary V. to Ravi Kapoor)
     ====================================================================== */
  export function LinkedInPostCardLiveShoppingOriginal({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Ravi Kapoor" />
                <AvatarFallback>RK</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Ravi Kapoor</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">Founder & CEO at SocialSpark Media</div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>1d</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
  
          {/* Body (original idea, renamed) */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>Want to make extra money in 2026?</p>
            <p>Buy products at wholesale, then sell them live on TikTok Shop and other live-shopping platforms. Go <em>hard</em>, and a determined solo creator can hit serious numbers—$1M in profit in a year or two.</p>
            <p>Right now, among all the options, live shopping is at the top of my list for the next five years in the U.S.</p>
            <p>Six years ago I told people to get on short-form video. Today those same people say, “I should’ve listened.” Now I’m saying: do <strong>live social shopping</strong>. Either you start, or you regret not starting later.</p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  
  /* ======================================================================
     POST: Live social shopping — REPHRASED (clearer, same meaning)
     ====================================================================== */
  export function LinkedInPostCardLiveShoppingRephrased({ likes }: { likes: number }) {
    return (
      <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
        <CardContent className="p-4">
          {/* Header same UI */}
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarImage src="" alt="Ravi Kapoor" />
                <AvatarFallback>RK</AvatarFallback>
              </Avatar>
              <div className="leading-tight">
                <div className="flex items-center flex-wrap">
                  <span className="font-semibold">Ravi Kapoor</span>
                  <VerifiedBadge />
                  <RelationPill text="3rd+" />
                </div>
                <div className="text-muted-foreground text-sm">Founder & CEO at SocialSpark Media</div>
                <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                  <span>1d</span>
                  <Dot />
                  <Globe className="h-3.5 w-3.5" aria-hidden />
                </div>
              </div>
            </div>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
  
          {/* Body (rephrased) */}
          <div className="mt-3 space-y-3 text-[15px] leading-6">
            <p>Looking for a 2026 side-income play?</p>
            <p>Source at wholesale and sell via live streams on TikTok Shop/others. With focus and volume, a solo seller can reach seven figures in 12–24 months.</p>
            <p>Of all the new opportunities, live social shopping is my #1 bet for the next five years.</p>
            <p>Years ago, I pushed people toward short-form. Many ignored it and now regret it. This time, don’t miss it: start live shopping now—or wish you had.</p>
          </div>
  
          <FooterBar likes={likes} />
        </CardContent>
      </Card>
    );
  }
  /* ======================================================================
   POST: Sudnya — ORIGINAL
   ====================================================================== */
export function LinkedInPostCardSudnyaOriginal({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Sudnya D." />
              <AvatarFallback>SD</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Sudnya D.</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">
                Enabling humans & machines to work together effectively
              </div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>2d</span><Dot /><span>Edited</span><Dot /><Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (original) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>When I joined a startup while pregnant, many well-meaning friends asked why I’d take on a stressful job instead of a big company with generous maternity benefits.</p>
          <p>Because I refused to let motherhood be a reason to play small.</p>
          <p>I care deeply about my career. I love hard work, building meaningful things, and pushing myself. Becoming a mom didn’t change that.</p>
          <p>Yes, 8 weeks of leave is meager and pumping in a supply closet wasn’t glamorous.</p>
          <p>But I wanted to set an example for other women engineers: don’t shy away from opportunities—or stay in unfulfilling jobs—because of motherhood.</p>
          <p>The grass often looks greener at big tech. Yet I’ve heard from moms about subtle penalties after maternity leave: lower ratings, delayed promotions, low-visibility projects.</p>
          <p>I’m not here to name and shame, but to call for change. Let’s stop using motherhood as an excuse to stall women’s careers.</p>
          <p>Motherhood didn’t slow me down; it sharpened me. It forced focus on what matters and ruthless prioritization.</p>
          <p>Parents are often the best time managers and leaders. Why penalize women for being mothers?</p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

/* ======================================================================
   POST: Sudnya — REPHRASED (readability)
   ====================================================================== */
export function LinkedInPostCardSudnyaRephrased({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header (same UI) */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Sudnya D." />
              <AvatarFallback>SD</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Sudnya D.</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">
                Enabling humans & machines to work together effectively
              </div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>2d</span><Dot /><span>Edited</span><Dot /><Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (rephrased) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>I joined a startup while pregnant. Friends suggested a safer job with better benefits. I chose impact.</p>
          <p>Motherhood didn’t shrink my ambition. It clarified it.</p>
          <p>Eight weeks of leave and pumping in a closet were hard. Setting an example mattered more.</p>
          <p>Too many moms in big tech face quiet penalties after leave—lower ratings, slower promotions, low-visibility work.</p>
          <p>Let’s change that. Don’t use motherhood to sideline women’s careers.</p>
          <p>Parenting sharpened my focus and time management. Some of the best leaders I know are parents.</p>
          <p>So why do we penalize women for being mothers?</p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

/* ======================================================================
   POST: Aman — ORIGINAL
   ====================================================================== */
export function LinkedInPostCardAmanOriginal({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Aman S." />
              <AvatarFallback>AS</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Aman S.</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">
                Senior Manager | Stanford LEADer professional
              </div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>9h</span><Dot /><Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (original) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>🌞 Proud Parent Moment 🌞</p>
          <p>Overjoyed to share that my 9-year-old daughter has just released her third book — <em>The Magic Book of India Art</em> 🐘.</p>
          <p>It’s a vibrant celebration of India’s art—colors, traditions, and timeless expressions—through the eyes of a young, passionate creator.</p>
          <p>What makes it special: hands-on painting activities at the end of each style so readers can learn and connect with the traditions themselves.</p>
          <p>Perfect for anyone who cherishes Indian art and believes in nurturing young voices. 📚</p>
          <p>Available in India & internationally at the links in comments.</p>
          <p>Let’s keep encouraging our children to dream big and express boldly. #IndianArt #YoungAuthor #ProudParent</p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}

/* ======================================================================
   POST: Aman — REPHRASED (readability)
   ====================================================================== */
export function LinkedInPostCardAmanRephrased({ likes }: { likes: number }) {
  return (
    <Card className="max-w-[640px] w-full border rounded-lg shadow-sm">
      <CardContent className="p-4">
        {/* Header (same UI) */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src="" alt="Aman S." />
              <AvatarFallback>AS</AvatarFallback>
            </Avatar>
            <div className="leading-tight">
              <div className="flex items-center flex-wrap">
                <span className="font-semibold">Aman S.</span>
                <VerifiedBadge />
                <RelationPill text="3rd+" />
              </div>
              <div className="text-muted-foreground text-sm">
                Senior Manager | Stanford LEADer professional
              </div>
              <div className="text-muted-foreground text-xs flex items-center mt-0.5">
                <span>9h</span><Dot /><Globe className="h-3.5 w-3.5" aria-hidden />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button variant="secondary" size="sm" className="rounded-full px-4">Follow</Button>
            <button className="p-1 rounded hover:bg-muted" aria-label="More options">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </button>
          </div>
        </div>

        {/* Body (rephrased) */}
        <div className="mt-3 space-y-3 text-[15px] leading-6">
          <p>🌞 Proud parent update: my 9-year-old just published book #3, <em>The Magic Book of India Art</em>.</p>
          <p>A tour of India’s artistic heritage—told through a child’s eyes—with paint-along activities after each style.</p>
          <p>If you love Indian art or want to nurture young creators, you’ll enjoy it. Links in comments for India & international orders.</p>
          <p>Let’s keep cheering kids who dream big and create boldly. #IndianArt #YoungAuthor #LinkedInFamily</p>
        </div>

        <FooterBar likes={likes} />
      </CardContent>
    </Card>
  );
}
