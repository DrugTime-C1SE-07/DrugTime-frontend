export type IconName =
  | 'check' | 'x' | 'plus' | 'menu' | 'arrow-right' | 'bell' | 'pill' | 'alert-triangle'
  | 'users' | 'shield-check' | 'check-circle' | 'scan' | 'calendar-clock' | 'stethoscope'
  | 'lock' | 'mail' | 'heart-pulse';

type Props = { name: IconName; size?: 'xs' | 'sm' | 'md' | 'lg'; className?: string };

/** References a symbol from <IconSprite />. Colour comes from `currentColor`. */
export default function Icon({ name, size, className }: Props) {
  const cls = ['icon', size && `icon--${size}`, className].filter(Boolean).join(' ');
  return (
    <svg className={cls} aria-hidden="true" focusable="false">
      <use href={`#i-${name}`} />
    </svg>
  );
}
