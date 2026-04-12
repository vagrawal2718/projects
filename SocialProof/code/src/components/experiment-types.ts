export type Truth = 'AI' | 'Human';
export type LikesLevel = 'Low' | 'High';

export type Stimulus = {
  id: string;
  truth: Truth;
  version: 'Original' | 'Rephrased'; //ADDED
  Component: React.ComponentType<{ likes: number }>;
  likesLevel: LikesLevel;           // recorded (not shown)
  likeRange?: [number, number];     // optional per-item (min,max) override
};
