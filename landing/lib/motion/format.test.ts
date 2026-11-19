import { describe, expect, it } from 'vitest';
import { formatCount } from './format';

describe('formatCount', () => {
  it('groups thousands the Vietnamese way', () => {
    expect(formatCount(1234567)).toBe('1.234.567');
  });

  it('can skip grouping for identifiers such as a decree number', () => {
    expect(formatCount(5948, '', false)).toBe('5948');
  });

  it('appends the suffix', () => {
    expect(formatCount(2, ' phút')).toBe('2 phút');
    expect(formatCount(0, 'đ')).toBe('0đ');
  });

  it('rounds intermediate animation frames', () => {
    expect(formatCount(1.6)).toBe('2');
  });

  it('clamps negative and non-finite input to zero', () => {
    expect(formatCount(-3)).toBe('0');
    expect(formatCount(Number.NaN)).toBe('0');
  });
});
