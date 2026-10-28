// Source-level event simulation. This does not launch a browser or verify GPU output.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import { Spring, clamp, sampleCloth } from '../dist/cloth-physics.mjs';

const source = fs.readFileSync(new URL('../dist/app.js', import.meta.url), 'utf8').replace(/^import .*;\n/gm, '');

function fixture({fallback = false, reduced = false} = {}) {
  const metrics = {layout:0,styles:0,attributes:0,markup:0,src:0,renders:0};
  class Target {
    listeners = new Map();
    addEventListener(type, fn) { const list = this.listeners.get(type) ?? []; list.push(fn); this.listeners.set(type, list); }
    dispatch(type, properties = {}) {
      const event = {type,target:this,button:0,pointerId:1,isPrimary:true,preventDefault(){this.prevented = true;},...properties};
      for (const fn of this.listeners.get(type) ?? []) fn(event);
      return event;
    }
  }
  class Element extends Target {
    constructor(id = '') {
      super(); this.id = id; this.dataset = {}; this.attrs = {}; this.vars = {}; this.classes = new Set(); this.captures = new Set();
      this.width = 1000; this.height = 550;
      this.classList = {
        add:(...values) => values.forEach(value => this.classes.add(value)),
        remove:(...values) => values.forEach(value => this.classes.delete(value)),
        toggle:(value, active) => active ? this.classes.add(value) : this.classes.delete(value)
      };
      this.style = new Proxy({setProperty:(key,value) => {this.vars[key] = value; metrics.styles++;},getPropertyValue:key => this.vars[key] ?? ''},
        {set:(target,key,value) => {target[key] = value; metrics.styles++; return true;}});
    }
    setAttribute(key,value) { this.attrs[key] = value; metrics.attributes++; }
    set innerHTML(value) { this.markup = value; metrics.markup++; }
    set src(value) { this.imageURL = value; metrics.src++; }
    get clientWidth() { metrics.layout++; return this.width; }
    get clientHeight() { metrics.layout++; return this.height; }
    get offsetWidth() { metrics.layout++; return 60; }
    get offsetHeight() { metrics.layout++; return 70; }
    getBoundingClientRect() {
      metrics.layout++;
      const match = /translate3d\(([-.\d]+)px, ([-.\d]+)px/.exec(this.style.transform);
      return {left:match ? +match[1] : 0,top:match ? +match[2] : 0,width:parseFloat(this.style.width),height:parseFloat(this.style.height)};
    }
    insertBefore(child) { this.child = child; }
    setPointerCapture(id) { this.captures.add(id); }
    hasPointerCapture(id) { return this.captures.has(id); }
    releasePointerCapture(id) { this.captures.delete(id); this.dispatch('lostpointercapture',{pointerId:id}); }
    focus() { this.focused = true; }
    scrollIntoView(options) { this.scrollOptions = options; }
  }
  const nodes = new Map();
  const get = selector => nodes.get(selector) ?? (nodes.set(selector,new Element(selector)),nodes.get(selector));
  const designs = ['persian','kilim','woven-grid','midnight'];
  const swatches = designs.map(style => Object.assign(new Element(),{dataset:{style}}));
  const cards = designs.map(galleryStyle => Object.assign(new Element(),{dataset:{galleryStyle}}));
  const icons = Array.from({length:6},(_,i) => { const element = new Element(); element.vars = {'--ix':`${11+i*12}%`,'--iy':`${19+i*7}%`}; return element; });
  const document = Object.assign(new Target(),{
    hidden:false,querySelector:get,createElement:() => new Element(),
    querySelectorAll:selector => selector === '.style-swatch' ? swatches : selector === '[data-gallery-style]' ? cards : selector === '.desktop-icon' ? icons : []
  });
  const media = Object.assign(new Target(),{matches:reduced});
  const resizes = [], intersections = [], frames = new Map(), snapshots = [];
  let sequence = 0, time = 100;
  class ResizeObserver { constructor(callback){this.callback=callback;resizes.push(this);} observe(){} }
  class IntersectionObserver { constructor(callback){this.callback=callback;intersections.push(this);} observe(){} unobserve(){} }
  const window = Object.assign(new Target(),{IntersectionObserver});
  class ClothRenderer {
    constructor(canvas, available) {if(fallback) throw Error('WebGL unavailable'); this.available=available;}
    resize(width,height) {this.width=width;this.height=height;}
    render(state,motion,now) {metrics.renders++;snapshots.push({state:{...state},motion:{...motion},now});}
  }
  const context = vm.createContext({Spring,clamp,sampleCloth,ClothRenderer,document,window,ResizeObserver,IntersectionObserver,
    matchMedia:() => media,requestAnimationFrame:callback => {const id=++sequence;frames.set(id,callback);return id;},cancelAnimationFrame:id=>frames.delete(id)});
  vm.runInContext(source,context);
  const inspect = () => JSON.parse(vm.runInContext('JSON.stringify({state, pointer, lift:{value:lift.value,target:lift.target,velocity:lift.velocity}, frame, geometryDirty, iconsDirty})',context));
  const tick = () => {
    const next = [...frames.entries()];
    for (const [id,callback] of next) {frames.delete(id);callback(time);}
    time += 1000 / 60;
  };
  const settle = () => {let n=0;while(frames.size && n++ < 600)tick();assert.equal(frames.size,0,'animation must sleep after settling');return n;};
  const clearMetrics = () => Object.keys(metrics).forEach(key=>metrics[key]=0);
  const point = (u=.45,v=.5) => {const {state}=inspect();return {clientX:state.x+state.width*u,clientY:state.y+state.height*v};};
  const rug=get('#demo-rug'),screen=get('#desktop-screen'),grip=get('.rug-grip-peek');
  settle();clearMetrics();
  return {get,rug,screen,grip,swatches,cards,icons,document,window,media,resizes,intersections,frames,snapshots,metrics,inspect,tick,settle,point,clearMetrics};
}

test('pointer events coalesce into one frame without layout reads or control rewrites', () => {
  const f=fixture();
  f.get('#sweep-button').dispatch('click');f.settle();
  const start=f.point();f.rug.dispatch('pointerdown',start);f.clearMetrics();
  for(let i=1;i<=100;i++)f.rug.dispatch('pointermove',{clientX:start.clientX+i*.4,clientY:start.clientY+i*.2});
  assert.equal(f.frames.size,1);
  assert.deepEqual(f.metrics,{layout:0,styles:0,attributes:0,markup:0,src:0,renders:0});
  f.tick();assert.equal(f.metrics.renders,1);assert.equal(f.metrics.layout,0);
  f.rug.dispatch('pointerup',start);f.settle();
  assert.equal(f.frames.size,0);
});

test('second pointer and non-primary input cannot steal an active gesture', () => {
  const f=fixture(),start=f.point();
  f.rug.dispatch('pointerdown',{...start,pointerId:2,isPrimary:false});
  assert.equal(f.inspect().pointer,null);
  f.rug.dispatch('pointerdown',start);
  const original=f.inspect().state;
  f.rug.dispatch('pointerdown',{...start,pointerId:2});
  f.rug.dispatch('pointermove',{clientX:999,clientY:500,pointerId:2});
  f.rug.dispatch('pointerup',{pointerId:2});
  assert.equal(f.inspect().pointer.id,1);assert.deepEqual(f.inspect().state,original);
  f.rug.dispatch('pointercancel');f.settle();assert.equal(f.inspect().pointer,null);
});

test('cancel and lost capture clean up lift without converting cancellation to a click', () => {
  for(const event of ['pointercancel','lostpointercapture']) {
    const f=fixture();
    f.rug.dispatch('pointerdown',{...f.point(.97,.035),target:f.grip});
    assert.ok(f.inspect().lift.target>0);
    f.rug.dispatch(event);f.settle();
    assert.equal(f.inspect().state.peek,false);assert.equal(f.inspect().lift.value,0);
    assert.equal(f.rug.captures.size,0);assert.equal(f.screen.classes.has('is-dragging'),false);
  }
});

test('pull release settles; a stationary corner click holds and lowers the corner', () => {
  const f=fixture(),start=f.point(.97,.035);
  f.rug.dispatch('pointerdown',{...start,target:f.grip});
  f.rug.dispatch('pointermove',{clientX:start.clientX-80,clientY:start.clientY+80});
  for(let i=0;i<12;i++)f.tick();
  assert.ok(f.inspect().lift.value>.3);
  f.rug.dispatch('pointerup',start);f.settle();
  assert.equal(f.inspect().state.peek,false);assert.equal(f.inspect().lift.value,0);
  f.rug.dispatch('pointerdown',{...start,target:f.grip});f.rug.dispatch('pointerup',start);f.settle();
  assert.equal(f.inspect().state.peek,true);assert.equal(f.inspect().lift.value,.96);
  f.rug.dispatch('pointerdown',{...start,target:f.grip});f.rug.dispatch('pointerup',start);f.settle();
  assert.equal(f.inspect().state.peek,false);assert.equal(f.inspect().lift.value,0);
});

test('resize during drag cancels capture and clamps dimensions even for zero viewport', () => {
  const f=fixture(),start=f.point(.99,.99);
  f.rug.dispatch('pointerdown',start);f.rug.dispatch('pointermove',{clientX:5000,clientY:5000});
  const resized=f.inspect().state;
  assert.ok(resized.width>0 && resized.x+resized.width<=f.screen.width);
  assert.ok(resized.y+resized.height<=f.screen.height);
  f.screen.width=0;f.screen.height=0;f.resizes[0].callback();f.settle();
  const tiny=f.inspect();assert.equal(tiny.pointer,null);assert.equal(f.rug.captures.size,0);
  for(const key of ['x','y','width','height'])assert.ok(Number.isFinite(tiny.state[key])&&tiny.state[key]>=0);
  assert.ok(tiny.state.width>=1);
});

test('reset clears an active gesture, motion, design, held corner and gathered icons', () => {
  const f=fixture();
  f.swatches[1].dispatch('click');f.get('#sweep-button').dispatch('click');f.get('#peek-button').dispatch('click');f.settle();
  const start=f.point();f.rug.dispatch('pointerdown',start);f.rug.dispatch('pointermove',{clientX:start.clientX+40,clientY:start.clientY+20});
  f.get('#reset-button').dispatch('click');f.settle();
  const result=f.inspect();assert.equal(result.pointer,null);assert.equal(result.state.style,'persian');assert.equal(result.state.peek,false);assert.equal(result.state.gathered,false);
  assert.equal(result.lift.value,0);assert.equal(result.lift.velocity,0);assert.equal(f.rug.captures.size,0);
  f.icons.forEach(icon=>{assert.equal(icon.vars['--dx'],'0px');assert.equal(icon.vars['--dy'],'0px');});
});

test('keyboard motion, resize, lift, Escape, and design gallery remain functional', () => {
  const f=fixture(),before=f.inspect().state;
  f.rug.dispatch('keydown',{key:'ArrowRight'});f.settle();assert.equal(f.inspect().state.x,before.x+14);
  f.rug.dispatch('keydown',{key:'ArrowRight',altKey:true});f.settle();assert.equal(f.inspect().state.x,before.x+16);
  f.rug.dispatch('keydown',{key:'ArrowRight',shiftKey:true});f.settle();assert.equal(f.inspect().state.width,before.width+14);
  f.rug.dispatch('keydown',{key:' '});f.settle();assert.equal(f.inspect().state.peek,true);
  f.rug.dispatch('keydown',{key:'Escape'});f.settle();assert.equal(f.inspect().state.peek,false);
  f.cards[3].dispatch('click');f.settle();assert.equal(f.inspect().state.style,'midnight');assert.equal(f.get('#play').scrollOptions.behavior,'smooth');
});

test('hidden/offscreen pause stops scheduled frames and visibility resumes cleanly', () => {
  const f=fixture();
  f.get('#peek-button').dispatch('click');assert.equal(f.frames.size,1);
  f.document.hidden=true;f.document.dispatch('visibilitychange');assert.equal(f.frames.size,0);
  f.document.hidden=false;f.document.dispatch('visibilitychange');assert.equal(f.frames.size,1);f.settle();
  assert.equal(f.inspect().lift.value,.96);
  f.intersections[0].callback([{isIntersecting:false}]);f.get('#peek-button').dispatch('click');assert.equal(f.frames.size,0);
  f.intersections[0].callback([{isIntersecting:true}]);assert.equal(f.frames.size,1);f.settle();assert.equal(f.inspect().lift.value,0);
});

test('reduced motion snaps in one frame and fallback preserves interactive controls', () => {
  const f=fixture({fallback:true,reduced:true});
  assert.equal(f.screen.classes.has('has-cloth-renderer'),false);
  f.get('#peek-button').dispatch('click');assert.equal(f.settle(),1);
  assert.equal(f.rug.vars['--fallback-lift'],'0.96');assert.equal(f.inspect().lift.value,.96);
  f.cards[2].dispatch('click');f.settle();assert.equal(f.inspect().state.style,'woven-grid');assert.equal(f.get('#play').scrollOptions.behavior,'auto');
  f.get('#sweep-button').dispatch('click');f.settle();assert.equal(f.inspect().state.gathered,true);
  f.rug.dispatch('keydown',{key:'Escape'});f.settle();assert.equal(f.rug.vars['--fallback-lift'],'0');
});
