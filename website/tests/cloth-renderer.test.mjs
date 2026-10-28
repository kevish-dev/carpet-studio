// CPU-side renderer lifecycle tests. GL calls are recorded, not executed by a GPU.
import assert from 'node:assert/strict';
import test from 'node:test';
import { ClothRenderer } from '../dist/cloth-renderer.mjs';

function fixture() {
  const calls = new Map();
  const shaderSources = [];
  let handle = 0, constant = 0;
  const gl = new Proxy({}, {
    get(target, key) {
      if (key in target) return target[key];
      if (key.toUpperCase() === key) return target[key] = ++constant;
      return target[key] = (...args) => {
        calls.set(key, (calls.get(key) ?? 0) + 1);
        if (key === 'shaderSource') shaderSources.push(args[1]);
        if (key === 'getShaderParameter' || key === 'getProgramParameter') return true;
        if (key === 'getAttribLocation') return {a_position:0,a_normal:1,a_uv:2}[args[1]];
        if (key === 'getUniformLocation') return args[1];
        if (key.startsWith('create')) return {id:++handle};
      };
    }
  });
  const listeners = {};
  const canvas = { getContext:() => gl, addEventListener:(name, fn) => listeners[name] = fn };
  globalThis.window = {devicePixelRatio:3};
  globalThis.document = {createElement:() => ({getContext:() => new Proxy({}, {get:() => () => {}})})};
  const availability = [];
  const renderer = new ClothRenderer(canvas, value => availability.push(value));
  renderer.resize(1000, 550);
  const state = {width:480,height:312,x:300,y:140,style:'persian'};
  const motion = {lift:.7,dx:10,dy:-5,ripple:.6};
  const count = key => calls.get(key) ?? 0;
  return {renderer,canvas,listeners,availability,state,motion,count,shaderSources};
}

test('shared WebGL1 uniforms have matching type and precision across shader stages', () => {
  const {shaderSources} = fixture();
  const uniforms = (source, vertex) => {
    const defaultFloat = /precision\s+(lowp|mediump|highp)\s+float\s*;/.exec(source)?.[1] ?? (vertex ? 'highp' : undefined);
    const values = new Map();
    for (const match of source.matchAll(/uniform\s+(?:(lowp|mediump|highp)\s+)?(float|vec[234]|mat[234])\s+(\w+)\s*;/g)) {
      values.set(match[3], {type:match[2], precision:match[1] ?? defaultFloat});
    }
    return values;
  };
  const vertex = uniforms(shaderSources[0],true), fragment = uniforms(shaderSources[1],false);
  for (const [name, declaration] of vertex) {
    if (fragment.has(name)) assert.deepEqual(fragment.get(name),declaration,`${name}: shared uniforms require identical precision for WebGL1 linking`);
  }
});

test('renderer caps backing resolution and reuses programs, buffers and design textures', () => {
  const f = fixture();
  assert.equal(f.canvas.width, 2000); assert.equal(f.canvas.height, 1100);
  f.renderer.render(f.state, f.motion, 0);
  const baseline = Object.fromEntries(['createProgram','compileShader','createBuffer','createTexture','texImage2D'].map(key => [key,f.count(key)]));
  for (let i = 1; i <= 50; i++) f.renderer.render(f.state, {...f.motion,lift:i / 50}, i / 60);
  for (const [key, value] of Object.entries(baseline)) assert.equal(f.count(key), value, `${key} must not run in unchanged-style frames`);
  f.renderer.render({...f.state,style:'kilim'}, f.motion, 1);
  assert.equal(f.count('texImage2D'), baseline.texImage2D + 1);
  f.renderer.render(f.state, f.motion, 1.1);
  assert.equal(f.count('texImage2D'), baseline.texImage2D + 1, 'returning to a cached design does not upload it again');
  assert.ok(f.renderer.data.every(Number.isFinite));
  assert.ok(f.renderer.edgeData.every(Number.isFinite));
});

test('lost context stops GL draws, exposes fallback, and recreates resources on restore', () => {
  const f = fixture();
  f.renderer.render(f.state, f.motion, 0);
  const draws = f.count('drawElements'), uploads = f.count('texImage2D');
  let prevented = false;
  f.listeners.webglcontextlost({preventDefault(){prevented = true;}});
  assert.equal(prevented, true); assert.deepEqual(f.availability, [false]);
  f.renderer.render(f.state, f.motion, 1);
  assert.equal(f.count('drawElements'), draws);
  f.listeners.webglcontextrestored();
  assert.deepEqual(f.availability, [false,true]);
  f.renderer.render(f.state, f.motion, 2);
  assert.ok(f.count('drawElements') > draws);
  assert.equal(f.count('texImage2D'), uploads + 1, 'restored context gets a new texture');
});

test('unavailable WebGL produces an explicit failure for the image fallback path', () => {
  assert.throws(() => new ClothRenderer({getContext:() => null}, () => {}), /WebGL unavailable/);
});
