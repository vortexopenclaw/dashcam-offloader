(() => {
  const script = document.currentScript;
  const existing = document.querySelectorAll('iframe[data-vr-recording-time]');
  const frames = [...existing];
  if (!frames.length && script) {
    const frame = document.createElement('iframe');
    frame.src = new URL('./index.html', script.src).href;
    frame.title = 'Vortex Radar dashcam recording time calculator';
    frame.loading = 'lazy';
    frame.style.cssText = 'display:block;width:100%;height:1100px;border:0;';
    script.after(frame);
    frames.push(frame);
  }
  for (const frame of frames) {
    if (frame.dataset.vrResizeReady) continue;
    frame.dataset.vrResizeReady = 'true';
    const origin = new URL(frame.src).origin;
    window.addEventListener('message', event => {
      if (event.origin !== origin || event.source !== frame.contentWindow || event.data?.type !== 'vr-recording-height') return;
      const height = event.data.height;
      if (Number.isFinite(height) && height >= 200 && height <= 6000) frame.style.height = `${Math.ceil(height) + 2}px`;
    });
    const measure = () => frame.contentWindow?.postMessage({type:'vr-recording-measure'}, origin);
    frame.addEventListener('load', measure);
    measure();
  }
})();
