(() => {
  const script = document.currentScript;
  const url = new URL('./index.html', script.src);
  const frame = document.createElement('iframe');
  frame.src = url.href;
  frame.title = 'Vortex Radar dashcam recording time calculator';
  frame.loading = 'lazy';
  frame.style.cssText = 'display:block;width:100%;height:1100px;border:0;';
  window.addEventListener('message', event => {
    if (event.origin !== url.origin || event.source !== frame.contentWindow || event.data?.type !== 'vr-recording-height') return;
    const height = event.data.height;
    if (Number.isFinite(height) && height >= 200 && height <= 6000) frame.style.height = `${Math.ceil(height) + 2}px`;
  });
  script.after(frame);
})();
