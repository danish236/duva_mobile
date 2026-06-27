import naughty from 'naughty-words';

const socialPatterns = [
  /(?:^|\s)(?:@|ig\s*:|insta\s*:|sc\s*:|snap\s*:|t\.me|telegram|onlyfans|only\s*fans)/i,
  /(?:https?:\/\/)?(?:www\.)?(?:instagram\.com|t\.me|telegram\.|onlyfans\.|snapchat\.)/i,
];

const allBadWords: string[] = [
  ...Object.values(naughty).flat(),
];

const combinedRegex = new RegExp(
  allBadWords.map(w => w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|'),
  'i'
);

export function containsProfanity(text: string): boolean {
  if (socialPatterns.some(p => p.test(text))) return true;
  return combinedRegex.test(text);
}
