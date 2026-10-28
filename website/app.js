const screen = document.querySelector('#desktop-screen');
const rug = document.querySelector('#demo-rug');
const rugImage = document.querySelector('#rug-image');
const status = document.querySelector('#demo-status');
const peekButton = document.querySelector('#peek-button');
const sweepButton = document.querySelector('#sweep-button');
const resetButton = document.querySelector('#reset-button');
const swatches = [...document.querySelectorAll('.style-swatch')];
const galleryCards = [...document.querySelectorAll('[data-gallery-style]')];
const icons = [...document.querySelectorAll('.desktop-icon')];

const names = {
  persian: 'Persian',
  kilim: 'Kilim',
  'woven-grid': 'Woven Grid',
  midnight: 'Midnight'
};

const state = { x: 0, y: 0, width: 0, height: 0, style: 'persian', peek: false, gathered: false, interacted: false };
let pointer = null;

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function makeInitialLayout() {
  const areaWidth = screen.clientWidth;
  const areaHeight = screen.clientHeight;
  const width = clamp(areaWidth * (areaWidth < 650 ? .54 : .48), 190, 570);
  const height = width * .65;
  state.width = width;
  state.height = height;
  state.x = clamp(areaWidth * (areaWidth < 650 ? .32 : .31), 5, areaWidth - width - 5);
  state.y = clamp(areaHeight * (areaWidth < 650 ? .37 : .27), 12, areaHeight - height - 26);
  render();
}

function render() {
  rug.style.width = `${state.width}px`;
  rug.style.height = `${state.height}px`;
  rug.style.transform = `translate3d(${state.x}px, ${state.y}px, 0)`;
  rug.style.setProperty('--fold', `${state.peek ? Math.min(state.width, state.height) * .46 : 0}px`);
  rug.classList.toggle('is-peeking', state.peek);
  rugImage.src = `/assets/rug-${state.style}.png`;
  rug.setAttribute('aria-label', `${names[state.style]} carpet. Drag to move. Arrow keys move, Shift and arrow keys resize. ${state.peek ? 'Corner is lifted.' : 'Corner is down.'}`);
  peekButton.setAttribute('aria-pressed', String(state.peek));
  peekButton.innerHTML = `<span class="tool-icon" aria-hidden="true">◪</span> ${state.peek ? 'Lay it down' : 'Lift corner'}`;
  sweepButton.setAttribute('aria-pressed', String(state.gathered));
  sweepButton.innerHTML = `<span class="tool-icon" aria-hidden="true">${state.gathered ? '↖' : '↘'}</span> ${state.gathered ? 'Restore icons' : 'Sweep icons'}`;
  swatches.forEach(button => {
    const active = button.dataset.style === state.style;
    button.classList.toggle('active', active);
    button.setAttribute('aria-pressed', String(active));
  });
  positionIcons();
}

function positionIcons() {
  const areaWidth = screen.clientWidth;
  const areaHeight = screen.clientHeight;
  icons.forEach((icon, index) => {
    if (!state.gathered) {
      icon.style.setProperty('--dx', '0px');
      icon.style.setProperty('--dy', '0px');
      return;
    }
    const originalX = areaWidth * parseFloat(icon.style.getPropertyValue('--ix')) / 100;
    const originalY = areaHeight * parseFloat(icon.style.getPropertyValue('--iy')) / 100;
    const column = index % 3;
    const row = Math.floor(index / 3);
    const targetX = state.x + state.width * (.25 + column * .22) - icon.offsetWidth / 2;
    const targetY = state.y + state.height * (.31 + row * .32) - icon.offsetHeight / 2;
    icon.style.setProperty('--dx', `${targetX - originalX}px`);
    icon.style.setProperty('--dy', `${targetY - originalY}px`);
  });
}

function setStatus(message) {
  status.textContent = message;
}

function chooseStyle(style, announce = true) {
  if (!names[style]) return;
  state.style = style;
  state.interacted = true;
  render();
  if (announce) setStatus(`${names[style]} design selected. Try dragging the carpet.`);
}

function togglePeek() {
  state.peek = !state.peek;
  state.interacted = true;
  render();
  setStatus(state.peek ? 'Corner lifted. The sample desktop is visible beneath it.' : 'Corner laid flat. The sample icons are covered again.');
}

function toggleGather() {
  state.gathered = !state.gathered;
  state.interacted = true;
  render();
  setStatus(state.gathered ? 'Sample icons swept beneath the carpet. Lift a corner to peek.' : 'Sample icons returned to their original positions.');
}

function resetDemo() {
  state.style = 'persian';
  state.peek = false;
  state.gathered = false;
  state.interacted = false;
  makeInitialLayout();
  setStatus('Demo reset. Drag the rug to make the desktop yours.');
}

swatches.forEach(button => button.addEventListener('click', () => chooseStyle(button.dataset.style)));
galleryCards.forEach(card => card.addEventListener('click', () => {
  chooseStyle(card.dataset.galleryStyle);
  document.querySelector('#play').scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' });
}));
peekButton.addEventListener('click', togglePeek);
sweepButton.addEventListener('click', toggleGather);
resetButton.addEventListener('click', resetDemo);

rug.addEventListener('pointerdown', event => {
  if (event.button !== 0) return;
  const bounds = rug.getBoundingClientRect();
  const localX = event.clientX - bounds.left;
  const localY = event.clientY - bounds.top;
  const nearRight = localX > bounds.width - Math.min(75, bounds.width * .25);
  const mode = nearRight && localY < Math.min(75, bounds.height * .3) ? 'peek'
    : nearRight && localY > bounds.height - Math.min(75, bounds.height * .3) ? 'resize'
      : 'move';
  pointer = {
    id: event.pointerId,
    mode,
    clientX: event.clientX,
    clientY: event.clientY,
    x: state.x,
    y: state.y,
    width: state.width,
    height: state.height,
    wasPeeking: state.peek,
    moved: false
  };
  rug.setPointerCapture(event.pointerId);
  event.preventDefault();
});

rug.addEventListener('pointermove', event => {
  if (!pointer || pointer.id !== event.pointerId) return;
  const dx = event.clientX - pointer.clientX;
  const dy = event.clientY - pointer.clientY;
  if (Math.abs(dx) + Math.abs(dy) > 4) pointer.moved = true;
  if (pointer.mode === 'move') {
    state.x = clamp(pointer.x + dx, 0, screen.clientWidth - state.width);
    state.y = clamp(pointer.y + dy, 0, screen.clientHeight - state.height - 6);
  } else if (pointer.mode === 'resize') {
    const maxWidth = Math.min(screen.clientWidth - state.x, (screen.clientHeight - state.y - 8) / .65);
    state.width = clamp(pointer.width + dx + dy * .35, Math.min(160, maxWidth), maxWidth);
    state.height = state.width * .65;
  } else if (pointer.mode === 'peek') {
    state.peek = Math.abs(dx) + Math.abs(dy) > 12 ? true : pointer.wasPeeking;
  }
  state.interacted = true;
  render();
});

function finishPointer(event) {
  if (!pointer || pointer.id !== event.pointerId) return;
  if (pointer.mode === 'peek' && !pointer.moved) state.peek = !pointer.wasPeeking;
  if (pointer.mode === 'peek') setStatus(state.peek ? 'Corner lifted. Take a look underneath.' : 'Corner laid flat again.');
  else if (pointer.mode === 'resize') setStatus('Carpet resized. A better fit for this desktop.');
  else if (pointer.moved) setStatus('Carpet moved. Your desktop, your arrangement.');
  pointer = null;
  render();
}
rug.addEventListener('pointerup', finishPointer);
rug.addEventListener('pointercancel', finishPointer);

rug.addEventListener('keydown', event => {
  const step = event.altKey ? 2 : 14;
  if (['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) {
    event.preventDefault();
    const horizontal = event.key === 'ArrowLeft' ? -step : event.key === 'ArrowRight' ? step : 0;
    const vertical = event.key === 'ArrowUp' ? -step : event.key === 'ArrowDown' ? step : 0;
    if (event.shiftKey) {
      const widthChange = horizontal + vertical;
      const maxWidth = Math.min(screen.clientWidth - state.x, (screen.clientHeight - state.y - 8) / .65);
      state.width = clamp(state.width + widthChange, Math.min(160, maxWidth), maxWidth);
      state.height = state.width * .65;
    } else {
      state.x = clamp(state.x + horizontal, 0, screen.clientWidth - state.width);
      state.y = clamp(state.y + vertical, 0, screen.clientHeight - state.height - 6);
    }
    state.interacted = true;
    render();
  } else if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault();
    togglePeek();
  }
});

const resizeObserver = new ResizeObserver(() => {
  if (!state.interacted) {
    makeInitialLayout();
    return;
  }
  const maxWidth = Math.min(screen.clientWidth - 4, (screen.clientHeight - 10) / .65);
  state.width = Math.min(state.width, maxWidth);
  state.height = state.width * .65;
  state.x = clamp(state.x, 0, screen.clientWidth - state.width);
  state.y = clamp(state.y, 0, screen.clientHeight - state.height - 6);
  render();
});
resizeObserver.observe(screen);
makeInitialLayout();

const revealElements = document.querySelectorAll('.reveal');
if (matchMedia('(prefers-reduced-motion: reduce)').matches || !('IntersectionObserver' in window)) {
  revealElements.forEach(element => element.classList.add('is-visible'));
} else {
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        observer.unobserve(entry.target);
      }
    }
  }, { threshold: .12, rootMargin: '0px 0px 30px 0px' });
  revealElements.forEach(element => observer.observe(element));
}
