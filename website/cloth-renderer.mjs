import { sampleCloth } from './cloth-physics.mjs';

const VERTEX = `
attribute vec3 a_position;
attribute vec3 a_normal;
attribute vec2 a_uv;
uniform vec2 u_viewport;
uniform vec2 u_origin;
uniform vec2 u_shadowOffset;
uniform mediump float u_layer;
uniform mediump float u_shadow;
varying mediump vec2 v_uv;
varying mediump vec3 v_normal;
varying mediump float v_height;
void main() {
  vec3 p = a_position + a_normal * u_layer;
  vec2 projected = p.xy + vec2(p.z * .13, -p.z * .38);
  if (u_shadow > .5) projected = p.xy + vec2(p.z * .25, p.z * .28) + u_shadowOffset;
  vec2 xy = (projected + u_origin) / u_viewport;
  gl_Position = vec4(xy.x * 2. - 1., 1. - xy.y * 2., u_shadow > .5 ? .8 : .3 - p.z / 1000., 1.);
  v_uv = a_uv;
  v_normal = a_normal;
  v_height = p.z;
}`;

const FRAGMENT = `
precision mediump float;
uniform sampler2D u_texture;
uniform mediump float u_shadow;
uniform mediump float u_layer;
uniform float u_edge;
uniform float u_weaveScale;
varying mediump vec2 v_uv;
varying mediump vec3 v_normal;
varying mediump float v_height;
void main() {
  bool fringe = v_uv.y < 0. || v_uv.y > 1.;
  if (fringe && fract(v_uv.x * 155.) > .48) discard;
  if (u_shadow > .5) {
    gl_FragColor = vec4(.10, .12, .10, .042 * (1. - min(v_height / 700., .5)));
    return;
  }
  vec3 normal = normalize(v_normal) * (u_layer < 0. ? -1. : 1.);
  float warp = sin(v_uv.x * 1800. * u_weaveScale);
  float weft = sin(v_uv.y * 1170. * u_weaveScale);
  float weave = warp * weft;
  normal = normalize(normal + vec3(warp * .085, weft * .06, 0.));
  float diffuse = max(0., dot(normal, normalize(vec3(-.35, -.45, .82))));
  vec3 color = texture2D(u_texture, clamp(v_uv, 0., 1.)).rgb;
  if (u_layer < 0.) color = mix(color, vec3(.66, .56, .41), .88);
  if (fringe) color = vec3(.86, .80, .65);
  if (u_edge > .5) color = mix(color, vec3(.29, .21, .16), .6);
  float edge = min(min(v_uv.x, 1. - v_uv.x), min(v_uv.y, 1. - v_uv.y));
  float binding = smoothstep(0., .009, edge);
  float sheen = pow(max(0., dot(normal, normalize(vec3(-.25, -.35, 1.)))), 18.) * .065;
  color *= (.48 + .54 * diffuse) * (.97 + .045 * weave) * (.87 + .13 * binding);
  color += vec3(sheen);
  gl_FragColor = vec4(color, 1.);
}`;

function createPattern(style) {
  const canvas = document.createElement('canvas');
  canvas.width = 1024; canvas.height = 668;
  const ctx = canvas.getContext('2d');
  const colors = { persian: '#923239', kilim: '#b36640', 'woven-grid': '#3e7063', midnight: '#23344b' };
  ctx.fillStyle = colors[style]; ctx.fillRect(0, 0, 1024, 668);
  ctx.strokeStyle = '#d9bb83'; ctx.lineWidth = 5;
  ctx.strokeRect(19, 19, 986, 630);
  ctx.lineWidth = 2; ctx.strokeRect(33, 33, 958, 602);
  const diamond = (x, y, rx, ry) => {
    ctx.beginPath(); ctx.moveTo(x, y - ry); ctx.lineTo(x + rx, y);
    ctx.lineTo(x, y + ry); ctx.lineTo(x - rx, y); ctx.closePath(); ctx.stroke();
  };
  if (style === 'persian') {
    [.35, .25, .14].forEach(scale => diamond(512, 334, 1024 * scale, 668 * scale));
    for (let x = 64; x < 1000; x += 76) for (let y = 61; y < 640; y += 76) {
      if (Math.abs(x - 512) / 1024 + Math.abs(y - 334) / 668 > .44) diamond(x, y, 14, 19);
    }
  } else if (style === 'kilim') {
    for (let x = 52; x < 1024; x += 92) for (let y = 48; y < 668; y += 92) {
      diamond(x, y, 33, 43); diamond(x, y, 13, 18);
    }
  } else if (style === 'woven-grid') {
    ctx.strokeStyle = '#b7c0a0'; ctx.lineWidth = 1.5;
    ctx.beginPath();
    for (let x = 48; x < 985; x += 29) { ctx.moveTo(x, 42); ctx.lineTo(x, 626); }
    for (let y = 48; y < 630; y += 29) { ctx.moveTo(42, y); ctx.lineTo(982, y); }
    ctx.stroke();
  } else {
    ctx.fillStyle = '#d9bb83';
    for (let x = 62; x < 1000; x += 106) for (let y = 58; y < 640; y += 99) {
      ctx.beginPath(); ctx.arc(x, y, 6, 0, Math.PI * 2); ctx.fill();
    }
  }
  // Woven warp and weft are baked once; dynamic pile lighting stays on the GPU.
  ctx.lineWidth = 1;
  ctx.strokeStyle = 'rgba(255,239,212,.055)'; ctx.beginPath();
  for (let x = 0; x < 1024; x += 3) { ctx.moveTo(x, 0); ctx.lineTo(x, 668); }
  ctx.stroke(); ctx.strokeStyle = 'rgba(15,10,6,.065)'; ctx.beginPath();
  for (let y = 0; y < 668; y += 3) { ctx.moveTo(0, y); ctx.lineTo(1024, y); }
  ctx.stroke();
  return canvas;
}

export class ClothRenderer {
  constructor(canvas, onAvailability) {
    this.canvas = canvas;
    this.onAvailability = onAvailability;
    this.gl = canvas.getContext('webgl', { alpha: true, antialias: true, premultipliedAlpha: false, powerPreference: 'low-power' });
    if (!this.gl) throw new Error('WebGL unavailable');
    this.columns = 52; this.rows = 36;
    this.data = new Float32Array((this.columns + 1) * (this.rows + 1) * 8);
    this.edgeData = new Float32Array((this.columns * 2 + this.rows * 2) * 6 * 8);
    this.point = {};
    this.textures = new Map();
    this.initialize();
    canvas.addEventListener('webglcontextlost', event => { event.preventDefault(); this.lost = true; onAvailability(false); });
    canvas.addEventListener('webglcontextrestored', () => {
      try { this.textures.clear(); this.initialize(); this.lost = false; onAvailability(true); }
      catch { this.lost = true; onAvailability(false); }
    });
  }
  initialize() {
    const gl = this.gl;
    const shader = (type, source) => {
      const s = gl.createShader(type); gl.shaderSource(s, source); gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
      return s;
    };
    const vs = shader(gl.VERTEX_SHADER, VERTEX), fs = shader(gl.FRAGMENT_SHADER, FRAGMENT);
    this.program = gl.createProgram(); gl.attachShader(this.program, vs); gl.attachShader(this.program, fs); gl.linkProgram(this.program);
    gl.deleteShader(vs); gl.deleteShader(fs);
    if (!gl.getProgramParameter(this.program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(this.program));
    gl.useProgram(this.program);
    this.uniform = {};
    for (const key of ['viewport', 'origin', 'shadowOffset', 'layer', 'shadow', 'edge', 'texture', 'weaveScale']) this.uniform[key] = gl.getUniformLocation(this.program, `u_${key}`);
    this.attributes = ['position', 'normal', 'uv'].map(key => gl.getAttribLocation(this.program, `a_${key}`));
    this.vertexBuffer = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, this.vertexBuffer); gl.bufferData(gl.ARRAY_BUFFER, this.data.byteLength, gl.DYNAMIC_DRAW);
    this.edgeBuffer = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, this.edgeBuffer); gl.bufferData(gl.ARRAY_BUFFER, this.edgeData.byteLength, gl.DYNAMIC_DRAW);
    const indices = [];
    for (let j = 0; j < this.rows; j++) for (let i = 0; i < this.columns; i++) {
      const a = j * (this.columns + 1) + i, b = a + 1, c = a + this.columns + 1, d = c + 1;
      indices.push(a, b, c, b, d, c);
    }
    this.indexCount = indices.length;
    this.indexBuffer = gl.createBuffer(); gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(indices), gl.STATIC_DRAW);
    gl.frontFace(gl.CW); gl.enable(gl.BLEND); gl.blendFuncSeparate(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA, gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
    gl.clearColor(0, 0, 0, 0);
  }
  resize(width, height) {
    this.width = Math.max(1, width); this.height = Math.max(1, height);
    const scale = Math.min(window.devicePixelRatio || 1, 2);
    this.canvas.width = Math.round(this.width * scale); this.canvas.height = Math.round(this.height * scale);
  }
  texture(style) {
    if (this.textures.has(style)) return this.textures.get(style);
    const gl = this.gl, texture = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, createPattern(style));
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    this.textures.set(style, texture); return texture;
  }
  bind(buffer) {
    const gl = this.gl; gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    this.attributes.forEach((location, i) => { gl.enableVertexAttribArray(location); gl.vertexAttribPointer(location, i === 2 ? 2 : 3, gl.FLOAT, false, 32, [0, 12, 24][i]); });
  }
  render(state, motion, time) {
    if (this.lost || !this.width) return;
    const { width, height } = state;
    let offset = 0;
    for (let j = 0; j <= this.rows; j++) for (let i = 0; i <= this.columns; i++) {
      const u = i / this.columns, v = j / this.rows * 1.036 - .018;
      const p = sampleCloth(u, v, width, height, motion.lift, motion.dx, motion.dy, motion.ripple, time, this.point);
      this.data[offset++] = p.x; this.data[offset++] = p.y; this.data[offset++] = p.z;
      this.data[offset++] = p.nx; this.data[offset++] = p.ny; this.data[offset++] = p.nz;
      this.data[offset++] = u; this.data[offset++] = v;
    }
    // The sewn edge is real geometry connecting the face and backing.
    let edgeOffset = 0;
    const edge = (a, b) => {
      for (let vertex = 0; vertex < 6; vertex++) {
        const index = vertex === 0 || vertex === 2 || vertex === 5 ? a : b;
        const side = vertex === 0 || vertex === 1 || vertex === 3 ? 1 : -1;
        const k = index * 8;
        this.edgeData[edgeOffset++] = this.data[k] + this.data[k+3] * side;
        this.edgeData[edgeOffset++] = this.data[k+1] + this.data[k+4] * side;
        this.edgeData[edgeOffset++] = this.data[k+2] + this.data[k+5] * side;
        for (let c = 3; c < 8; c++) this.edgeData[edgeOffset++] = this.data[k+c];
      }
    };
    for (let i = 0; i < this.columns; i++) { edge(i, i+1); const k=this.rows*(this.columns+1)+i; edge(k,k+1); }
    for (let j = 0; j < this.rows; j++) { const k=j*(this.columns+1); edge(k,k+this.columns+1); edge(k+this.columns,k+2*this.columns+1); }
    const gl = this.gl, u = this.uniform;
    gl.viewport(0,0,this.canvas.width,this.canvas.height); gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.useProgram(this.program); gl.uniform1f(u.weaveScale, Math.min(1, width * Math.min(window.devicePixelRatio || 1, 2) * .0014)); gl.uniform2f(u.viewport,this.width,this.height); gl.uniform2f(u.origin,state.x,state.y);
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D,this.texture(state.style)); gl.uniform1i(u.texture,0);
    this.bind(this.vertexBuffer); gl.bufferSubData(gl.ARRAY_BUFFER,0,this.data); gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,this.indexBuffer);
    gl.disable(gl.DEPTH_TEST); gl.disable(gl.CULL_FACE); gl.uniform1f(u.edge,0); gl.uniform1f(u.shadow,1); gl.uniform1f(u.layer,0);
    // Several inexpensive projected silhouettes make a soft contact shadow.
    for (let i = 0; i < 9; i++) {
      const angle = i / 8 * Math.PI * 2, spread = i === 8 ? 0 : 3.5 + motion.lift * 4;
      gl.uniform2f(u.shadowOffset,Math.cos(angle)*spread+2,Math.sin(angle)*spread+5);
      gl.drawElements(gl.TRIANGLES,this.indexCount,gl.UNSIGNED_SHORT,0);
    }
    gl.enable(gl.DEPTH_TEST); gl.depthFunc(gl.LEQUAL); gl.enable(gl.CULL_FACE); gl.uniform1f(u.shadow,0);
    gl.cullFace(gl.BACK); gl.uniform1f(u.layer,1); gl.drawElements(gl.TRIANGLES,this.indexCount,gl.UNSIGNED_SHORT,0);
    gl.cullFace(gl.FRONT); gl.uniform1f(u.layer,-1); gl.drawElements(gl.TRIANGLES,this.indexCount,gl.UNSIGNED_SHORT,0);
    gl.disable(gl.CULL_FACE); gl.uniform1f(u.layer,0); gl.uniform1f(u.edge,1);
    this.bind(this.edgeBuffer); gl.bufferSubData(gl.ARRAY_BUFFER,0,this.edgeData); gl.drawArrays(gl.TRIANGLES,0,edgeOffset/8);
  }
}
