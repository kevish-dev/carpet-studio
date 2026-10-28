import { Spring, clamp, sampleCloth } from './cloth-physics.mjs';
import { ClothRenderer } from './cloth-renderer.mjs';

const screen = document.querySelector('#desktop-screen');
const rug = document.querySelector('#demo-rug');
const rugImage = document.querySelector('#rug-image');
const status = document.querySelector('#demo-status');
const peekButton = document.querySelector('#peek-button');
const sweepButton = document.querySelector('#sweep-button');
const resetButton = document.querySelector('#reset-button');
const grip = document.querySelector('.rug-grip-peek');
const swatches = [...document.querySelectorAll('.style-swatch')];
const galleryCards = [...document.querySelectorAll('[data-gallery-style]')];
const icons = [...document.querySelectorAll('.desktop-icon')];
const names = { persian: 'Persian', kilim: 'Kilim', 'woven-grid': 'Woven Grid', midnight: 'Midnight' };
const state = { x: 0, y: 0, width: 0, height: 0, style: 'persian', peek: false, gathered: false, interacted: false };
const area = { width: 1, height: 1, icons: [] };
const lift = new Spring(0, 17, .72);
const dragX = new Spring(0, 23, .8);
const dragY = new Spring(0, 23, .8);
const ripple = new Spring(0, 15, .62);
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let pointer = null, frame = 0, lastTime = 0, geometryDirty = true, iconsDirty = true;
let renderer = null, visible = true;

const canvas = document.createElement('canvas');
canvas.className = 'cloth-canvas'; canvas.setAttribute('aria-hidden', 'true');
screen.insertBefore(canvas, rug);
function availability(available) {
  screen.classList.toggle('has-cloth-renderer', available);
  requestFrame();
}
try { renderer = new ClothRenderer(canvas, availability); availability(true); }
catch { availability(false); }

function requestFrame() {
  if (!frame && !document.hidden && visible) frame = requestAnimationFrame(animate);
}
function animate(now) {
  frame = 0;
  const dt = lastTime ? (now - lastTime) / 1000 : 1 / 60;
  lastTime = now;
  const active = [lift, dragX, dragY, ripple].map(spring => spring.step(dt, reducedMotion.matches)).some(Boolean);
  if (geometryDirty) {
    rug.style.width = `${state.width}px`;
    rug.style.height = `${state.height}px`;
    rug.style.transform = `translate3d(${state.x}px, ${state.y}px, 0)`;
    geometryDirty = false;
  }
  if (iconsDirty) { positionIcons(); iconsDirty = false; }
  const motion = { lift: lift.value, dx: dragX.value, dy: dragY.value, ripple: ripple.value };
  renderer?.render(state, motion, now / 1000);
  const corner = sampleCloth(.97, .035, state.width, state.height, lift.value);
  grip.style.transform = `translate3d(${corner.x + corner.z * .13 - 8}px, ${corner.y - corner.z * .38 - 8}px, 0)`;
  if (!renderer || renderer.lost) rug.style.setProperty('--fallback-lift', String(lift.value));
  if (active) requestFrame(); else lastTime = 0;
}
function geometryChanged() { geometryDirty = true; iconsDirty = true; requestFrame(); }
function syncControls() {
  rugImage.src = `/assets/rug-${state.style}.png`;
  rug.setAttribute('aria-label', `${names[state.style]} carpet. Drag the body to move, pull the upper right corner to lift and release to settle. Arrow keys move, Shift and arrows resize. ${state.peek ? 'Corner held open.' : 'Corner down.'}`);
  peekButton.setAttribute('aria-pressed', String(state.peek));
  peekButton.innerHTML = `<span class="tool-icon" aria-hidden="true">◪</span> ${state.peek ? 'Lay it down' : 'Lift corner'}`;
  sweepButton.setAttribute('aria-pressed', String(state.gathered));
  sweepButton.innerHTML = `<span class="tool-icon" aria-hidden="true">${state.gathered ? '↖' : '↘'}</span> ${state.gathered ? 'Restore icons' : 'Sweep icons'}`;
  swatches.forEach(button => {
    const active = button.dataset.style === state.style;
    button.classList.toggle('active', active); button.setAttribute('aria-pressed', String(active));
  });
}
function positionIcons() {
  icons.forEach((icon, index) => {
    const original = area.icons[index];
    if (!original) return;
    const x = state.gathered ? state.x + state.width * (.25 + index % 3 * .22) - original.width / 2 - original.x : 0;
    const y = state.gathered ? state.y + state.height * (.31 + Math.floor(index / 3) * .32) - original.height / 2 - original.y : 0;
    icon.style.setProperty('--dx', `${x}px`); icon.style.setProperty('--dy', `${y}px`);
  });
}
function measure() {
  // All layout reads happen together, outside pointermove and animation frames.
  area.width = Math.max(1, screen.clientWidth); area.height = Math.max(1, screen.clientHeight);
  area.icons = icons.map(icon => ({
    width: icon.offsetWidth, height: icon.offsetHeight,
    x: area.width * parseFloat(icon.style.getPropertyValue('--ix')) / 100,
    y: area.height * parseFloat(icon.style.getPropertyValue('--iy')) / 100
  }));
  renderer?.resize(area.width, area.height);
}
function maxWidth() { return Math.max(1, Math.min(area.width - state.x, (area.height - state.y - 8) / .65)); }
function fit() {
  state.width = clamp(state.width, 1, Math.min(area.width, Math.max(1, (area.height - 8) / .65)));
  state.height = state.width * .65;
  state.x = clamp(state.x, 0, area.width - state.width);
  state.y = clamp(state.y, 0, area.height - state.height - 6);
}
function initialLayout() {
  state.width = Math.min(clamp(area.width * (area.width < 650 ? .54 : .48), 190, 570), area.width, Math.max(1, (area.height - 12) / .65));
  state.height = state.width * .65;
  state.x = area.width * (area.width < 650 ? .32 : .31);
  state.y = area.height * (area.width < 650 ? .37 : .27);
  fit(); geometryChanged();
}
function setStatus(message) { status.textContent = message; }
function cancelGesture() {
  if (!pointer) return;
  const id = pointer.id;
  pointer = null;
  if (rug.hasPointerCapture(id)) rug.releasePointerCapture(id);
  screen.classList.remove('is-dragging');
  dragX.target = dragY.target = ripple.target = 0;
  lift.target = state.peek ? .96 : 0;
  requestFrame();
}
function chooseStyle(style) {
  if (!names[style]) return;
  state.style = style; state.interacted = true;
  syncControls(); requestFrame(); setStatus(`${names[style]} design selected. Pull the upper right corner to feel the fabric.`);
}
function togglePeek() {
  cancelGesture(); state.peek = !state.peek; state.interacted = true;
  lift.target = state.peek ? .96 : 0;
  syncControls(); requestFrame();
  setStatus(state.peek ? 'Corner held open. Pull and release it to let the fabric settle.' : 'The fabric is settling back onto the desktop.');
}
function toggleGather() {
  state.gathered = !state.gathered; state.interacted = true;
  syncControls(); iconsDirty = true; requestFrame();
  setStatus(state.gathered ? 'Sample icons swept beneath the rug. Lift the upper right corner to peek.' : 'Sample icons restored to their original positions.');
}
function resetDemo() {
  cancelGesture(); state.style = 'persian'; state.peek = state.gathered = state.interacted = false;
  [lift, dragX, dragY, ripple].forEach(spring => spring.snap(0));
  initialLayout(); syncControls(); setStatus('Demo reset. Drag the rug, or pull its upper right corner.');
}
swatches.forEach(button => button.addEventListener('click', () => chooseStyle(button.dataset.style)));
galleryCards.forEach(card => card.addEventListener('click', () => {
  chooseStyle(card.dataset.galleryStyle);
  document.querySelector('#play').scrollIntoView({ behavior: reducedMotion.matches ? 'auto' : 'smooth' });
}));
peekButton.addEventListener('click', togglePeek);
sweepButton.addEventListener('click', toggleGather);
resetButton.addEventListener('click', resetDemo);

rug.addEventListener('pointerdown', event => {
  if (pointer || event.button !== 0 || event.isPrimary === false) return;
  const bounds = rug.getBoundingClientRect();
  const x = event.clientX - bounds.left, y = event.clientY - bounds.top;
  const nearRight = x > state.width - Math.min(75, state.width * .25);
  const mode = event.target === grip || nearRight && y < Math.min(75, state.height * .3) ? 'peek'
    : nearRight && y > state.height - Math.min(75, state.height * .3) ? 'resize' : 'move';
  pointer = { id: event.pointerId, mode, clientX: event.clientX, clientY: event.clientY,
    x: state.x, y: state.y, width: state.width, lift: lift.value, wasPeeking: state.peek, moved: false, lastX: event.clientX, lastY: event.clientY };
  rug.setPointerCapture(event.pointerId); rug.focus({ preventScroll: true });
  if (mode === 'peek') lift.target = Math.max(.12, lift.value);
  screen.classList.add('is-dragging'); requestFrame(); event.preventDefault();
});
rug.addEventListener('pointermove', event => {
  if (!pointer || pointer.id !== event.pointerId) return;
  const dx = event.clientX - pointer.clientX, dy = event.clientY - pointer.clientY;
  if (Math.abs(dx) + Math.abs(dy) > 4) pointer.moved = true;
  if (pointer.mode === 'move') {
    state.x = clamp(pointer.x + dx, 0, area.width - state.width);
    state.y = clamp(pointer.y + dy, 0, area.height - state.height - 6);
    dragX.target = clamp(event.clientX - pointer.lastX, -45, 45);
    dragY.target = clamp(event.clientY - pointer.lastY, -45, 45);
    geometryChanged();
  } else if (pointer.mode === 'resize') {
    state.width = clamp(pointer.width + dx + dy * .35, Math.min(160, maxWidth()), maxWidth());
    state.height = state.width * .65; geometryChanged();
  } else {
    const distance = Math.hypot(dx, dy);
    lift.target = clamp(pointer.lift + distance / Math.max(65, state.height * .67), .08, 1.06);
    requestFrame();
  }
  pointer.lastX = event.clientX; pointer.lastY = event.clientY;
  state.interacted = true;
});
function finishPointer(event) {
  if (!pointer || pointer.id !== event.pointerId) return;
  if (event.type !== 'pointerup') { cancelGesture(); return; }
  const ended = pointer;
  cancelGesture();
  if (ended.mode === 'peek') {
    state.peek = ended.moved ? false : !ended.wasPeeking;
    lift.target = state.peek ? .96 : 0;
    if (ended.moved && !reducedMotion.matches) { ripple.value = Math.min(1.8, lift.value * 2); ripple.target = 0; }
    setStatus(state.peek ? 'Corner held open. Click again to lay it down.' : 'Released. The fabric settles back into place.');
  } else if (ended.mode === 'resize') setStatus('Rug resized to fit this desktop.');
  else if (ended.moved) setStatus('Rug moved. Your desktop, your arrangement.');
  syncControls(); requestFrame();
}
for (const event of ['pointerup', 'pointercancel', 'lostpointercapture']) rug.addEventListener(event, finishPointer);
rug.addEventListener('keydown', event => {
  if (event.key === 'Escape') { cancelGesture(); state.peek = false; lift.target = 0; syncControls(); requestFrame(); return; }
  if (['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) {
    event.preventDefault(); cancelGesture();
    const step = event.altKey ? 2 : 14;
    const horizontal = event.key === 'ArrowLeft' ? -step : event.key === 'ArrowRight' ? step : 0;
    const vertical = event.key === 'ArrowUp' ? -step : event.key === 'ArrowDown' ? step : 0;
    if (event.shiftKey) {
      state.width = clamp(state.width + horizontal + vertical, Math.min(160, maxWidth()), maxWidth()); state.height = state.width * .65;
    } else {
      state.x = clamp(state.x + horizontal, 0, area.width - state.width);
      state.y = clamp(state.y + vertical, 0, area.height - state.height - 6);
    }
    state.interacted = true; geometryChanged();
  } else if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); togglePeek(); }
});
const resizeObserver = new ResizeObserver(() => {
  cancelGesture(); measure();
  if (!state.interacted) initialLayout(); else { fit(); geometryChanged(); }
});
resizeObserver.observe(screen);
measure(); initialLayout(); syncControls();
reducedMotion.addEventListener('change', requestFrame);
document.addEventListener('visibilitychange', () => {
  if (document.hidden) { cancelGesture(); if (frame) cancelAnimationFrame(frame); frame = 0; lastTime = 0; }
  else requestFrame();
});
window.addEventListener('blur', cancelGesture);
if ('IntersectionObserver' in window) {
  new IntersectionObserver(entries => {
    visible = entries[0].isIntersecting;
    if (visible) requestFrame(); else { if (frame) cancelAnimationFrame(frame); frame = 0; lastTime = 0; }
  }, { rootMargin: '100px' }).observe(screen);
}
const revealElements = document.querySelectorAll('.reveal');
if (reducedMotion.matches || !('IntersectionObserver' in window)) revealElements.forEach(element => element.classList.add('is-visible'));
else {
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) if (entry.isIntersecting) { entry.target.classList.add('is-visible'); observer.unobserve(entry.target); }
  }, { threshold: .12, rootMargin: '0px 0px 30px 0px' });
  revealElements.forEach(element => observer.observe(element));
}
