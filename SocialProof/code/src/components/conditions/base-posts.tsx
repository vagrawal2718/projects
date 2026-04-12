// src/components/conditions/base-posts.tsx
'use client';
import type { Truth } from '@/components/experiment-types';
import type React from 'react';
import {
  LinkedInPostCardJaineelOriginal, LinkedInPostCardJaineelRephrased,
  LinkedInPostCardDariusOriginal, LinkedInPostCardDariusRephrased,
  LinkedInPostCardTravelOriginal, LinkedInPostCardTravelRephrased,
  LinkedInPostCardRanjaniOriginal, LinkedInPostCardRanjaniRephrased,
  LinkedInPostCardSunitaOriginal, LinkedInPostCardSunitaRephrased,
  LinkedInPostCardAmitOriginal, LinkedInPostCardAmitRephrased,
  LinkedInPostCardNicholasOriginal, LinkedInPostCardNicholasRephrased,
  LinkedInPostCardCharlesOriginal, LinkedInPostCardCharlesRephrased,
  LinkedInPostCardReemaOriginal, LinkedInPostCardReemaRephrased,
  LinkedInPostCardStefanoOriginal, LinkedInPostCardStefanoRephrased,
  LinkedInPostCardEvolvingAIOriginal, LinkedInPostCardEvolvingAIRephrased,
  LinkedInPostCardPauloOriginal, LinkedInPostCardPauloRephrased,
  LinkedInPostCardMadhavOriginal, LinkedInPostCardMadhavRephrased,
  LinkedInPostCardGaryOriginal, LinkedInPostCardGaryRephrased,
  LinkedInPostCardAmitGuptaOriginal, LinkedInPostCardAmitGuptaRephrased,
  LinkedInPostCardRussellAdamsOriginal, LinkedInPostCardRussellAdamsRephrased,
  LinkedInPostCardBarnaclesOriginal, LinkedInPostCardBarnaclesRephrased,
  LinkedInPostCardLiveShoppingOriginal, LinkedInPostCardLiveShoppingRephrased,
  LinkedInPostCardSudnyaOriginal, LinkedInPostCardSudnyaRephrased,
  LinkedInPostCardAmanOriginal, LinkedInPostCardAmanRephrased

} from '@/components/posts';

export type BasePost = {
  slug: string;                 // stable id like "travel", "jaineel", "darius"
  truth: Truth;                 // "AI" | "Human"
  Original: React.ComponentType<{ likes: number }>;
  Rephrased: React.ComponentType<{ likes: number }>;
};

export const BASE_POSTS: BasePost[] = [
  { slug: 'jaineel', truth: 'Human', Original: LinkedInPostCardJaineelOriginal, Rephrased: LinkedInPostCardJaineelRephrased },
  { slug: 'darius', truth: 'Human', Original: LinkedInPostCardDariusOriginal, Rephrased: LinkedInPostCardDariusRephrased },
  { slug: 'travel', truth: 'Human', Original: LinkedInPostCardTravelOriginal, Rephrased: LinkedInPostCardTravelRephrased },
  { slug: 'ranjani', truth: 'Human', Original: LinkedInPostCardRanjaniOriginal, Rephrased: LinkedInPostCardRanjaniRephrased },
  { slug: 'sunita', truth: 'Human', Original: LinkedInPostCardSunitaOriginal, Rephrased: LinkedInPostCardSunitaRephrased },
  { slug: 'amit', truth: 'Human', Original: LinkedInPostCardAmitOriginal, Rephrased: LinkedInPostCardAmitRephrased },
  { slug: 'nicholas', truth: 'Human', Original: LinkedInPostCardNicholasOriginal, Rephrased: LinkedInPostCardNicholasRephrased },
  { slug: 'charles', truth: 'Human', Original: LinkedInPostCardCharlesOriginal, Rephrased: LinkedInPostCardCharlesRephrased },
  { slug: 'reema', truth: 'Human', Original: LinkedInPostCardReemaOriginal, Rephrased: LinkedInPostCardReemaRephrased },
  { slug: 'stefano', truth: 'Human', Original: LinkedInPostCardStefanoOriginal, Rephrased: LinkedInPostCardStefanoRephrased },
  { slug: 'evolvingai', truth: 'Human', Original: LinkedInPostCardEvolvingAIOriginal, Rephrased: LinkedInPostCardEvolvingAIRephrased },
  { slug: 'paulo', truth: 'Human', Original: LinkedInPostCardPauloOriginal, Rephrased: LinkedInPostCardPauloRephrased },
  { slug: 'madhav', truth: 'Human', Original: LinkedInPostCardMadhavOriginal, Rephrased: LinkedInPostCardMadhavRephrased },
  { slug: 'gary', truth: 'Human', Original: LinkedInPostCardGaryOriginal, Rephrased: LinkedInPostCardGaryRephrased },
  { slug: 'amitgupta', truth: 'Human', Original: LinkedInPostCardAmitGuptaOriginal, Rephrased: LinkedInPostCardAmitGuptaRephrased },
  { slug: 'russelladams', truth: 'Human', Original: LinkedInPostCardRussellAdamsOriginal, Rephrased: LinkedInPostCardRussellAdamsRephrased },
  { slug: 'barnacles', truth: 'Human', Original: LinkedInPostCardBarnaclesOriginal, Rephrased: LinkedInPostCardBarnaclesRephrased },
  { slug: 'live_shopping', truth: 'Human', Original: LinkedInPostCardLiveShoppingOriginal, Rephrased: LinkedInPostCardLiveShoppingRephrased },
  { slug: 'sudnya', truth: 'Human', Original: LinkedInPostCardSudnyaOriginal, Rephrased: LinkedInPostCardSudnyaRephrased },
  { slug: 'aman', truth: 'Human', Original: LinkedInPostCardAmanOriginal, Rephrased: LinkedInPostCardAmanRephrased },

];

