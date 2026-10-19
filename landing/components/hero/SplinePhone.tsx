'use client';

import { useEffect, useRef, useState } from 'react';
import type { Application } from '@splinetool/runtime';
import { readMotionEnv, shouldLoad3D } from '@/lib/motion/capabilities';
import { SPLINE_SCENE_URL } from '@/lib/seo/metadata';
import PhoneFallback from './PhoneFallback';

const LOAD_TIMEOUT_MS = 12_000;
/** Name of the phone group inside the Spline scene (see SPLINE_SCENE_URL). */
const SPLINE_PHONE_OBJECT = 'iPhone 14 Pro';
const IDLE_TIMEOUT_MS = 2_500;

type Status = 'idle' | 'loading' | 'ready' | 'failed';

/**
 * Hero iPhone: the static PhoneFallback renders first (LCP, no layout shift). On desktop with
 * motion allowed, the Spline runtime is imported once the browser is idle and the hero is on
 * screen, then the scene crossfades in. Off-screen or in a hidden tab the scene stops rendering.
 * Any load error or timeout keeps the fallback.
 */
export default function SplinePhone() {
  const wrapRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [wanted, setWanted] = useState(false);
  const [status, setStatus] = useState<Status>('idle');

  // Decide whether to load, then wait for idle time with the hero in view.
  useEffect(() => {
    const el = wrapRef.current;
    if (!el || !shouldLoad3D(readMotionEnv())) return;

    let idleId: number | undefined;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const start = () => setWanted(true);
    const io = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) return;
      io.disconnect();
      if ('requestIdleCallback' in window) idleId = window.requestIdleCallback(start, { timeout: IDLE_TIMEOUT_MS });
      else timer = setTimeout(start, 1_200);
    });
    io.observe(el);

    return () => {
      io.disconnect();
      if (idleId !== undefined) window.cancelIdleCallback(idleId);
      if (timer) clearTimeout(timer);
    };
  }, []);

  // Load the runtime and the scene; pause while off-screen or hidden.
  useEffect(() => {
    const wrap = wrapRef.current;
    const canvas = canvasRef.current;
    if (!wanted || !wrap || !canvas) return;

    let app: Application | undefined;
    let done = false;
    let onScreen = true;

    const sync = () => {
      if (!app) return;
      const shouldRun = onScreen && !document.hidden;
      if (shouldRun && app.isStopped) app.play();
      else if (!shouldRun && !app.isStopped) app.stop();
    };
    const io = new IntersectionObserver(([entry]) => { onScreen = entry.isIntersecting; sync(); });

    // The canvas is inert (it never traps scrolling or focus), so the scene's own "follow the
    // cursor" interaction gets the pointer only while it is over the stage; leaving the stage
    // sends a point at the canvas centre so the phone settles back in the middle of the orbit.
    const stage = wrap.closest<HTMLElement>('.stage') ?? wrap;
    const forward = (x: number, y: number) =>
      canvas.dispatchEvent(new PointerEvent('pointermove', { clientX: x, clientY: y, pointerType: 'mouse', bubbles: false }));
    const recenter = () => {
      const r = canvas.getBoundingClientRect();
      forward(r.left + r.width / 2, r.top + r.height / 2);
    };
    const onStageMove = (e: PointerEvent) => { if (e.pointerType === 'mouse') forward(e.clientX, e.clientY); };
    const settleTimers: ReturnType<typeof setTimeout>[] = [];

    const teardown = () => {
      done = true;
      clearTimeout(timeout);
      io.disconnect();
      document.removeEventListener('visibilitychange', sync);
      stage.removeEventListener('pointermove', onStageMove);
      stage.removeEventListener('pointerleave', recenter);
      settleTimers.forEach(clearTimeout);
      app?.dispose();
      app = undefined;
    };
    const fail = (error: unknown) => {
      if (done) return;
      console.warn('[hero] Spline scene failed, keeping the static phone.', error);
      teardown();
      setStatus('failed');
    };
    const timeout = setTimeout(() => fail(new Error(`Spline scene not ready after ${LOAD_TIMEOUT_MS} ms`)), LOAD_TIMEOUT_MS);

    setStatus('loading');
    import('@splinetool/runtime')
      .then(async ({ Application: SplineApp }) => {
        if (done) return;
        app = new SplineApp(canvas, { renderOnDemand: true });
        await app.load(SPLINE_SCENE_URL);
        if (done) return;
        // The scene ships with an opaque backdrop; let the hero aurora show through.
        app.setBackgroundColor('transparent');
        // The scene is exported with mouseEventTarget = "window": it would track the cursor
        // across the whole page and swing off-centre while people read the copy. Listen on the
        // (inert) canvas instead and feed it pointer positions from the stage only.
        app.setGlobalEvents(false);
        // The phone group is authored at x = -160 in the scene, so it renders left of centre in
        // our canvas; put it on the origin so it sits in the middle of the feature orbit.
        const phone = app.findObjectByName(SPLINE_PHONE_OBJECT);
        if (phone) phone.position.x = 0;
        else console.warn(`[hero] "${SPLINE_PHONE_OBJECT}" not found in the Spline scene; phone may be off-centre.`);
        clearTimeout(timeout);
        io.observe(wrap);
        document.addEventListener('visibilitychange', sync);
        stage.addEventListener('pointermove', onStageMove);
        stage.addEventListener('pointerleave', recenter);
        // The scene's event handlers start a few frames after load(); keep nudging the pointer to
        // the centre for a moment so the phone leaves its authored (tilted, off-centre) pose.
        for (const delay of [0, 150, 400, 800, 1500]) settleTimers.push(setTimeout(recenter, delay));
        setStatus('ready');
      })
      .catch(fail);

    return teardown;
  }, [wanted]);

  return (
    <div ref={wrapRef} className={`phone3d phone3d--${status}`}>
      <PhoneFallback />
      {wanted && status !== 'failed' && (
        // inert: the runtime injects a focusable, pointer-catching iframe here; keep it out of
        // the tab order and away from the mouse (pointer moves are forwarded from the stage).
        <div className="phone3d__canvas" aria-hidden="true" inert>
          <canvas ref={canvasRef} />
        </div>
      )}
    </div>
  );
}
