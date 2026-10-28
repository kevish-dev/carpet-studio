export const clamp = (value, min, max) => Math.max(min, Math.min(value, Math.max(min, max)));

// Substepped damped spring: the same response on 60 Hz and ProMotion displays.
export class Spring {
  constructor(value = 0, frequency = 18, damping = .76) {
    this.value = this.target = value;
    this.velocity = 0;
    this.frequency = frequency;
    this.damping = damping;
  }
  snap(value) { this.value = this.target = value; this.velocity = 0; }
  step(dt, reduced = false) {
    if (reduced) { this.snap(this.target); return false; }
    const duration = clamp(dt, 0, .05);
    const steps = Math.max(1, Math.ceil(duration / (1 / 240)));
    const h = duration / steps;
    for (let i = 0; i < steps; i++) {
      this.velocity += ((this.target - this.value) * this.frequency ** 2 - 2 * this.damping * this.frequency * this.velocity) * h;
      this.value += this.velocity * h;
    }
    if (Math.abs(this.target - this.value) < .0005 && Math.abs(this.velocity) < .003) {
      this.snap(this.target);
      return false;
    }
    return true;
  }
}

// Arc-length-preserving cylindrical bend. The diagonal hinge has no crease:
// position and tangent are continuous as the flat fabric enters the curl.
export function sampleCloth(u, v, width, height, lift, dragX = 0, dragY = 0, ripple = 0, time = 0, out = {}) {
  const w = Math.max(1, width), h = Math.max(1, height);
  const amount = clamp(lift, 0, 1.12);
  const dx = Math.SQRT1_2, dy = -Math.SQRT1_2;
  let x = u * w, y = v * h, z = 2;
  let nx = 0, ny = 0, nz = 1;
  const extent = Math.min(w, h) * .88;
  const s = Math.max(0, (x - w) * dx + y * dy + extent);
  const k = 2.72 * amount / extent;
  if (s > 0 && k > .000001) {
    const theta = s * k;
    const setback = Math.sin(theta) / k - s;
    x += dx * setback;
    y += dy * setback;
    z += (1 - Math.cos(theta)) / k;
    nx = -dx * Math.sin(theta);
    ny = -dy * Math.sin(theta);
    nz = Math.cos(theta);
  }
  // A small travelling bow gives the free edge weight while the body is moved.
  const envelope = Math.sin(Math.PI * clamp(u, 0, 1)) * Math.sin(Math.PI * clamp(v, 0, 1));
  const bow = Math.min(9, Math.hypot(dragX, dragY) * .13);
  const wave = ripple * Math.sin(u * 8 + v * 6 - time * 13) * envelope;
  z += bow * envelope + wave;
  x += dragX * .025 * envelope;
  y += dragY * .025 * envelope;
  out.x = x; out.y = y; out.z = Math.max(.4, z);
  out.nx = nx; out.ny = ny; out.nz = nz;
  return out;
}
