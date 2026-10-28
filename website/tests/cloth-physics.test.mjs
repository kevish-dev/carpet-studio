import assert from 'node:assert/strict';
import test from 'node:test';
import { Spring, sampleCloth, clamp } from '../dist/cloth-physics.mjs';

const near = (actual, expected, tolerance = 1e-8) =>
  assert.ok(Math.abs(actual - expected) <= tolerance, `${actual} ≉ ${expected} (±${tolerance})`);
const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);
const runSpring = (spring, seconds, fps) => {
  let active = true;
  for (let i = 0; i < seconds * fps; i++) {
    active = spring.step(1 / fps);
    assert.ok(Number.isFinite(spring.value) && Number.isFinite(spring.velocity));
    assert.ok(Math.abs(spring.value) < 1000, 'spring must not diverge');
  }
  return active;
};

test('resting cloth is an undeformed plane, including fringe coordinates', () => {
  for (const [width, height] of [[190, 123.5], [570, 370.5], [1600, 1040]]) {
    for (const u of [-.018, 0, .25, .5, .75, 1, 1.018]) {
      for (const v of [-.018, 0, .25, .5, .75, 1, 1.018]) {
        const p = sampleCloth(u, v, width, height, 0);
        near(p.x, u * width); near(p.y, v * height); near(p.z, 2);
        near(p.nx, 0); near(p.ny, 0); near(p.nz, 1);
      }
    }
  }
});

test('lift exposes the underside while leaving the opposite corner on the desktop', () => {
  const lifted = sampleCloth(1, 0, 600, 390, 1);
  assert.ok(lifted.z > 100);
  assert.ok(lifted.x < 600 && lifted.y > 0, 'free corner retreats across the desktop');
  assert.ok(lifted.nz < 0, 'the underside faces the viewer at full lift');
  assert.deepEqual(sampleCloth(0, 1, 600, 390, 1), sampleCloth(0, 1, 600, 390, 0));
});

test('curl seam has continuous position, tangent and normal', () => {
  const w = 600, h = 390, extent = h * .88;
  const v = .2;
  const hingeU = 1 + (v * h - extent * Math.SQRT2) / w;
  const epsilon = 1e-5;
  for (const lift of [.01, .2, .6, 1, 1.12]) {
    const before = sampleCloth(hingeU - epsilon, v, w, h, lift);
    const hinge = sampleCloth(hingeU, v, w, h, lift);
    const after = sampleCloth(hingeU + epsilon, v, w, h, lift);
    near(distance(before, hinge), w * epsilon, 1e-6);
    near(distance(hinge, after), w * epsilon, 1e-6);
    for (const key of ['x', 'y', 'z']) {
      near((hinge[key] - before[key]) / epsilon, (after[key] - hinge[key]) / epsilon, .03);
    }
    near(Math.hypot(before.nx - after.nx, before.ny - after.ny, before.nz - after.nz), 0, .0001);
  }
});

test('curvature preserves local fabric lengths instead of stretching the texture', () => {
  const width = 600, height = 390, step = 1e-5;
  for (const lift of [.2, .7, 1.12]) {
    for (const [u, v] of [[.8, .1], [.95, .04], [.5, .22], [.4, .5]]) {
      const p = sampleCloth(u, v, width, height, lift);
      near(distance(p, sampleCloth(u + step, v, width, height, lift)), width * step, 1e-7);
      near(distance(p, sampleCloth(u, v + step, width, height, lift)), height * step, 1e-7);
    }
  }
});

test('lift limits, tiny viewports and randomized motion remain finite', () => {
  let seed = 31825;
  const random = () => ((seed = (1664525 * seed + 1013904223) >>> 0) / 2 ** 32);
  for (let i = 0; i < 5000; i++) {
    const u = -.018 + random() * 1.036, v = -.018 + random() * 1.036;
    const w = random() * 1600, h = random() * 1040;
    const p = sampleCloth(u, v, w, h, random() * 3 - 1, random() * 200 - 100, random() * 200 - 100, random() * 8, random() * 100);
    for (const value of Object.values(p)) assert.ok(Number.isFinite(value));
    near(Math.hypot(p.nx, p.ny, p.nz), 1, 1e-10);
    assert.ok(p.z >= .4);
  }
  assert.deepEqual(sampleCloth(1, 0, 600, 390, -1), sampleCloth(1, 0, 600, 390, 0));
  assert.deepEqual(sampleCloth(1, 0, 600, 390, 100), sampleCloth(1, 0, 600, 390, 1.12));
  const tiny = sampleCloth(1, 0, 0, -10, 1);
  Object.values(tiny).forEach(value => assert.ok(Number.isFinite(value)));
  assert.equal(clamp(25, 0, -100), 0, 'inverted bounds cannot produce negative dimensions');
});

test('spring response agrees across 30, 60 and 120 Hz', () => {
  const snapshots = [30, 60, 120].map(fps => {
    const spring = new Spring();
    spring.target = 1;
    runSpring(spring, .2, fps);
    return spring.value;
  });
  near(snapshots[0], snapshots[1], 1e-8);
  near(snapshots[1], snapshots[2], 1e-8);
});

test('lifting and releasing settles exactly and returns inactive at each frame rate', () => {
  for (const fps of [30, 60, 120]) {
    const spring = new Spring();
    spring.target = 1.12;
    assert.equal(runSpring(spring, 5, fps), false);
    assert.equal(spring.value, 1.12); assert.equal(spring.velocity, 0);
    spring.target = 0;
    assert.equal(runSpring(spring, 5, fps), false);
    assert.equal(spring.value, 0); assert.equal(spring.velocity, 0);
    assert.equal(spring.step(1 / fps), false, 'resting loop can sleep');
  }
});

test('long or negative frame gaps stay stable; reduced motion and reset clear velocity', () => {
  const spring = new Spring();
  spring.target = 1;
  spring.step(.01);
  const before = {value: spring.value, velocity: spring.velocity};
  spring.step(-1);
  assert.equal(spring.value, before.value); assert.equal(spring.velocity, before.velocity);
  spring.step(120);
  assert.ok(Number.isFinite(spring.value) && Math.abs(spring.value) < 2);
  assert.equal(runSpring(spring, 5, 60), false);
  spring.target = -.4;
  assert.equal(spring.step(1 / 60, true), false);
  assert.equal(spring.value, -.4); assert.equal(spring.velocity, 0);
  spring.target = 10; spring.step(.02); spring.snap(2);
  assert.equal(spring.value, 2); assert.equal(spring.target, 2); assert.equal(spring.velocity, 0);
});
