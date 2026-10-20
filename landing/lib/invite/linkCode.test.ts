import { describe, expect, it } from 'vitest';
import { androidIntentUrl, groupCode, parseInviteHash } from './linkCode';

describe('parseInviteHash', () => {
  it('reads the code from the fragment, with or without the leading #', () => {
    expect(parseInviteHash('#code=K7M2Q9XAR4')).toBe('K7M2Q9XAR4');
    expect(parseInviteHash('code=K7M2Q9XAR4')).toBe('K7M2Q9XAR4');
  });

  it('rejects a missing or malformed code', () => {
    for (const hash of [
      '',
      '#',
      '#ma=K7M2Q9XAR4',
      '#code=',
      '#code=k7m2q9xar4',
      '#code=K7M2Q9XAR0',
      '#code=K7M2Q9XAO4',
      '#code=K7M2Q9XAR',
      '#code=K7M2Q9XAR44',
      '#code=<script>',
    ]) {
      expect(parseInviteHash(hash), hash).toBeNull();
    }
  });
});

describe('groupCode', () => {
  it('groups 4-4-2 like the app', () => {
    expect(groupCode('K7M2Q9XAR4')).toBe('K7M2 Q9XA R4');
  });
});

describe('androidIntentUrl', () => {
  it('targets the DrugTime package over https and falls back to the download page', () => {
    const url = androidIntentUrl(
      'K7M2Q9XAR4',
      'drug-time-frontend.vercel.app',
      'https://drug-time-frontend.vercel.app/download',
    );
    expect(url).toBe(
      'intent://drug-time-frontend.vercel.app/link?code=K7M2Q9XAR4' +
        '#Intent;scheme=https;package=vn.drugtime.drugtime_mobile;' +
        'S.browser_fallback_url=https%3A%2F%2Fdrug-time-frontend.vercel.app%2Fdownload;end',
    );
  });
});
