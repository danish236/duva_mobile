const badWords = [
  'fuck', 'shit', 'bitch', 'cunt', 'nigger', 'nigga', 'asshole', 'dick', 'pussy',
  'whore', 'slut', 'bastard', 'cock', 'suck my', 'blowjob', 'handjob', 'rimjob',
  'milf', 'dildo', 'vibrator', 'anal', 'anus', 'clit', 'fag', 'faggot', 'retard',
  'bdsm', 'porn', 'xxx', 'sex tape',
];

const socialPatterns = [
  /(?:^|\s)(?:@[\w.]+\b)/i,
  /(?:^|\s)(?:ig\s*:|insta\s*:|sc\s*:|snap\s*:)/i,
  /(?:^|\s)(?:t\.me|telegram|onlyfans|only\s*fans)\b/i,
  /(?:https?:\/\/)?(?:www\.)?(?:instagram\.com|t\.me|telegram\.me|onlyfans\.com|snapchat\.com)/i,
];

const combinedRegex = new RegExp(
  badWords.map(w => w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|'),
  'i'
);

export function containsProfanity(text: string): boolean {
  if (socialPatterns.some(p => p.test(text))) return true;
  return combinedRegex.test(text);
}
