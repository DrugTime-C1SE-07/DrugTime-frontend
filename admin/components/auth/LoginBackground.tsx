"use client";

import { Pause, Play } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";

const VIDEO_SRC = "/media/login-background.mp4";
const POSTER_SRC = "/media/login-background-poster.jpg";
const REDUCED_MOTION = "(prefers-reduced-motion: reduce)";

type NetworkInformationLike = { saveData?: boolean };

/** Không tự phát khi người dùng muốn giảm chuyển động hoặc tiết kiệm dữ liệu: chỉ hiện poster tĩnh. */
function shouldAutoplay() {
  const saveData = (navigator as Navigator & { connection?: NetworkInformationLike }).connection?.saveData;
  return !window.matchMedia(REDUCED_MOTION).matches && !saveData;
}

/**
 * Video nền trang Đăng nhập (trang trí, không tiếng) + lớp phủ tối + nút tạm dừng (WCAG 2.2.2).
 * Không dùng thuộc tính autoPlay: chỉ gọi play() sau khi mount và kiểm reduced-motion/Save-Data,
 * nên trước đó và khi không phát luôn thấy poster. preload="none": file chỉ tải khi play() được gọi,
 * nên chế độ giảm chuyển động / tiết kiệm dữ liệu không tải video.
 */
export default function LoginBackground() {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [playing, setPlaying] = useState(false);
  // Người dùng chủ động tạm dừng (hoặc không được tự phát): tab hiện lại cũng không phát tiếp.
  const userPaused = useRef(false);

  const play = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    video.play().then(
      () => setPlaying(true),
      // Trình duyệt chặn tự phát (chế độ tiết kiệm pin, chính sách autoplay): giữ poster, nút chuyển sang "Phát".
      () => setPlaying(false),
    );
  }, []);

  const pause = useCallback(() => {
    videoRef.current?.pause();
    setPlaying(false);
  }, []);

  useEffect(() => {
    if (shouldAutoplay()) play();
    else userPaused.current = true;

    const onVisibility = () => {
      if (document.hidden) videoRef.current?.pause();
      else if (!userPaused.current) play();
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => document.removeEventListener("visibilitychange", onVisibility);
  }, [play]);

  const toggle = () => {
    if (playing) {
      userPaused.current = true;
      pause();
    } else {
      userPaused.current = false;
      play();
    }
  };

  return (
    <>
      <div className="admin-login-backdrop" aria-hidden="true">
        <video
          ref={videoRef}
          className="admin-login-backdrop__video"
          poster={POSTER_SRC}
          muted
          loop
          playsInline
          preload="none"
          disablePictureInPicture
          tabIndex={-1}
        >
          <source src={VIDEO_SRC} type="video/mp4" />
        </video>
      </div>

      <div className="admin-login-caption">
        <button
          type="button"
          className="admin-login-video-toggle"
          onClick={toggle}
          aria-label={playing ? "Tạm dừng video nền" : "Phát video nền"}
          title={playing ? "Tạm dừng video nền" : "Phát video nền"}
        >
          {playing ? <Pause size={18} strokeWidth={2.4} aria-hidden="true" /> : <Play size={18} strokeWidth={2.4} aria-hidden="true" />}
        </button>
        <p className="admin-login-caption__text">Quản trị dữ liệu thuốc &amp; quy tắc tương tác</p>
      </div>
    </>
  );
}
