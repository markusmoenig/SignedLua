// cuon-matrix.js (c) 2012 kanda and matsuda
/**
 * This is a class treating 4x4 matrix.
 * This class contains the function that is equivalent to OpenGL matrix stack.
 * The matrix after conversion is calculated by multiplying a conversion matrix from the right.
 * The matrix is replaced by the calculated result.
 */

/**
 * Contains Math related classes used by Carthage (originally written for Visual Graphics).
 * @namespace
 */

SI.Math = {};

/**
 * Constructor of Matrix4
 * If opt_src is specified, new matrix is initialized by opt_src.
 * Otherwise, new matrix is initialized by identity matrix.
 * @param opt_src source matrix(option)
 * @constructor
 */
SI.Math.Matrix4 = function(opt_src) {
    if (!(this instanceof SI.Math.Matrix4)) return new SI.Math.Matrix4(opt_src);

  var i, s, d;
  if (opt_src && typeof opt_src === 'object' && opt_src.hasOwnProperty('elements')) {
    s = opt_src.elements;
    d = new Float32Array(16);
    for (i = 0; i < 16; ++i) {
      d[i] = s[i];
    }
    this.elements = d;
  } else {
    this.elements = new Float32Array([1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]);
  }
};

/**
 * Set the identity matrix.
 * @return this
 */
SI.Math.Matrix4.prototype.setIdentity = function() {
  var e = this.elements;
  e[0] = 1;   e[4] = 0;   e[8]  = 0;   e[12] = 0;
  e[1] = 0;   e[5] = 1;   e[9]  = 0;   e[13] = 0;
  e[2] = 0;   e[6] = 0;   e[10] = 1;   e[14] = 0;
  e[3] = 0;   e[7] = 0;   e[11] = 0;   e[15] = 1;
  return this;
};

/**
 * Copy matrix.
 * @param src source matrix
 * @return this
 */
SI.Math.Matrix4.prototype.set = function(src) {
  var i, s, d;

  s = src.elements;
  d = this.elements;

  if (s === d) {
    return;
  }

  for (i = 0; i < 16; ++i) {
    d[i] = s[i];
  }

  return this;
};

/**
 * Multiply the matrix from the right.
 * @param other The multiply matrix
 * @return this
 */
SI.Math.Matrix4.prototype.concat = function(other) {
  var i, e, a, b, ai0, ai1, ai2, ai3;

  // Calculate e = a * b
  e = this.elements;
  a = this.elements;
  b = other.elements;

  // If e equals b, copy b to temporary matrix.
  if (e === b) {
    b = new Float32Array(16);
    for (i = 0; i < 16; ++i) {
      b[i] = e[i];
    }
  }
  for (i = 0; i < 4; i++) {
    ai0=a[i];  ai1=a[i+4];  ai2=a[i+8];  ai3=a[i+12];
    e[i]    = ai0 * b[0]  + ai1 * b[1]  + ai2 * b[2]  + ai3 * b[3];
    e[i+4]  = ai0 * b[4]  + ai1 * b[5]  + ai2 * b[6]  + ai3 * b[7];
    e[i+8]  = ai0 * b[8]  + ai1 * b[9]  + ai2 * b[10] + ai3 * b[11];
    e[i+12] = ai0 * b[12] + ai1 * b[13] + ai2 * b[14] + ai3 * b[15];
  }
  return this;
};
SI.Math.Matrix4.prototype.multiply = SI.Math.Matrix4.prototype.concat;

/**
 * Returns the forward facing vector of the matrix which are elements, 8, 9, 10.
 * Convenience function.
 * @return {SI.Math.Vector3} The forward facing vector.
 */
SI.Math.Matrix4.prototype.forwardVector = function() {
    var e = this.elements;
    return new SI.Math.Vector3(-e[8], -e[9], -e[10]);
};

/**
 * Multiply the three-dimensional vector.
 * This assume the vector is direction (NOT position).
 * @param pos {SI.Math.Vector3} The multiply vector
 * @return {SI.Math.Vector3} The result of multiplication
 */
SI.Math.Matrix4.prototype.multiplyVector3 = function(pos) {
    var e = this.elements;
    var p = [pos.x, pos.y, pos.z];
    var v = new SI.Math.Vector3();

    v.x = p[0] * e[0] + p[1] * e[4] + p[2] * e[ 8] + e[12]; // was: e[11];
    v.y = p[0] * e[1] + p[1] * e[5] + p[2] * e[ 9] + e[13]; // was: e[12];
    v.z = p[0] * e[2] + p[1] * e[6] + p[2] * e[10] + e[14]; // was: e[13];
    return v;
};

SI.Math.Matrix4.prototype.multiplyDirection = function (dir) {
  /**
   * transform a direction vector with this matrix.
   * @param dir {SI.Math.Vector3} direction
   * @return {SI.Math.Vector3} the transformed direction.
   */
    return this.multiplyVector3(dir);
};

SI.Math.Matrix4.prototype.multiplyPosition = function(pos) {
  /**
   * transform a position vector with this matrix.
   * @param pos {SI.Math.Vector3} position
   * @return {SI.Math.Matrix3} the transformed position.
   */
    var out = this.multiplyDirection(pos);
    var e = this.elements;
    var w = pos.x * e[3] + pos.y * e[7] + pos.z * e[11] + e[15];
    out.mul(1/w);
    return out;
};

/**
 * Transpose the matrix.
 * @return this
 */
SI.Math.Matrix4.prototype.transpose = function() {
  var e, t;

  e = this.elements;

  t = e[ 1];  e[ 1] = e[ 4];  e[ 4] = t;
  t = e[ 2];  e[ 2] = e[ 8];  e[ 8] = t;
  t = e[ 3];  e[ 3] = e[12];  e[12] = t;
  t = e[ 6];  e[ 6] = e[ 9];  e[ 9] = t;
  t = e[ 7];  e[ 7] = e[13];  e[13] = t;
  t = e[11];  e[11] = e[14];  e[14] = t;

  return this;
};

/**
 * Calculate the inverse matrix of specified matrix, and set to this.
 * @param other The source matrix
 * @return this
 */
SI.Math.Matrix4.prototype.setInverseOf = function(other) {
  var i, s, d, inv, det;

  s = other.elements;
  d = this.elements;
  inv = new Float32Array(16);

  inv[0]  =   s[5]*s[10]*s[15] - s[5] *s[11]*s[14] - s[9] *s[6]*s[15] + s[9]*s[7] *s[14] + s[13]*s[6] *s[11] - s[13]*s[7]*s[10];
  inv[4]  = - s[4]*s[10]*s[15] + s[4] *s[11]*s[14] + s[8] *s[6]*s[15] - s[8]*s[7] *s[14] - s[12]*s[6] *s[11] + s[12]*s[7]*s[10];
  inv[8]  =   s[4]*s[9] *s[15] - s[4] *s[11]*s[13] - s[8] *s[5]*s[15] + s[8]*s[7] *s[13] + s[12]*s[5] *s[11] - s[12]*s[7]*s[9];
  inv[12] = - s[4]*s[9] *s[14] + s[4] *s[10]*s[13] + s[8] *s[5]*s[14] - s[8]*s[6] *s[13] - s[12]*s[5] *s[10] + s[12]*s[6]*s[9];

  inv[1]  = - s[1]*s[10]*s[15] + s[1] *s[11]*s[14] + s[9] *s[2]*s[15] - s[9]*s[3] *s[14] - s[13]*s[2] *s[11] + s[13]*s[3]*s[10];
  inv[5]  =   s[0]*s[10]*s[15] - s[0] *s[11]*s[14] - s[8] *s[2]*s[15] + s[8]*s[3] *s[14] + s[12]*s[2] *s[11] - s[12]*s[3]*s[10];
  inv[9]  = - s[0]*s[9] *s[15] + s[0] *s[11]*s[13] + s[8] *s[1]*s[15] - s[8]*s[3] *s[13] - s[12]*s[1] *s[11] + s[12]*s[3]*s[9];
  inv[13] =   s[0]*s[9] *s[14] - s[0] *s[10]*s[13] - s[8] *s[1]*s[14] + s[8]*s[2] *s[13] + s[12]*s[1] *s[10] - s[12]*s[2]*s[9];

  inv[2]  =   s[1]*s[6]*s[15] - s[1] *s[7]*s[14] - s[5] *s[2]*s[15] + s[5]*s[3]*s[14] + s[13]*s[2]*s[7]  - s[13]*s[3]*s[6];
  inv[6]  = - s[0]*s[6]*s[15] + s[0] *s[7]*s[14] + s[4] *s[2]*s[15] - s[4]*s[3]*s[14] - s[12]*s[2]*s[7]  + s[12]*s[3]*s[6];
  inv[10] =   s[0]*s[5]*s[15] - s[0] *s[7]*s[13] - s[4] *s[1]*s[15] + s[4]*s[3]*s[13] + s[12]*s[1]*s[7]  - s[12]*s[3]*s[5];
  inv[14] = - s[0]*s[5]*s[14] + s[0] *s[6]*s[13] + s[4] *s[1]*s[14] - s[4]*s[2]*s[13] - s[12]*s[1]*s[6]  + s[12]*s[2]*s[5];

  inv[3]  = - s[1]*s[6]*s[11] + s[1]*s[7]*s[10] + s[5]*s[2]*s[11] - s[5]*s[3]*s[10] - s[9]*s[2]*s[7]  + s[9]*s[3]*s[6];
  inv[7]  =   s[0]*s[6]*s[11] - s[0]*s[7]*s[10] - s[4]*s[2]*s[11] + s[4]*s[3]*s[10] + s[8]*s[2]*s[7]  - s[8]*s[3]*s[6];
  inv[11] = - s[0]*s[5]*s[11] + s[0]*s[7]*s[9]  + s[4]*s[1]*s[11] - s[4]*s[3]*s[9]  - s[8]*s[1]*s[7]  + s[8]*s[3]*s[5];
  inv[15] =   s[0]*s[5]*s[10] - s[0]*s[6]*s[9]  - s[4]*s[1]*s[10] + s[4]*s[2]*s[9]  + s[8]*s[1]*s[6]  - s[8]*s[2]*s[5];

  det = s[0]*inv[0] + s[1]*inv[4] + s[2]*inv[8] + s[3]*inv[12];
  if (det === 0) {
    return this;
  }

  det = 1 / det;
  for (i = 0; i < 16; i++) {
    d[i] = inv[i] * det;
  }

  return this;
};

/**
 * Calculate the inverse matrix of this, and set to this.
 * @return this
 */
SI.Math.Matrix4.prototype.invert = function() {
  return this.setInverseOf(this);
};

/**
 * Set the orthographic projection matrix.
 * @param left The coordinate of the left of clipping plane.
 * @param right The coordinate of the right of clipping plane.
 * @param bottom The coordinate of the bottom of clipping plane.
 * @param top The coordinate of the top top clipping plane.
 * @param near The distances to the nearer depth clipping plane. This value is minus if the plane is to be behind the viewer.
 * @param far The distances to the farther depth clipping plane. This value is minus if the plane is to be behind the viewer.
 * @return this
 */
SI.Math.Matrix4.prototype.setOrtho = function(left, right, bottom, top, near, far) {
  var e, rw, rh, rd;

  if (left === right || bottom === top || near === far) {
    throw 'null frustum';
  }

  rw = 1 / (right - left);
  rh = 1 / (top - bottom);
  rd = 1 / (far - near);

  e = this.elements;

  e[0]  = 2 * rw;
  e[1]  = 0;
  e[2]  = 0;
  e[3]  = 0;

  e[4]  = 0;
  e[5]  = 2 * rh;
  e[6]  = 0;
  e[7]  = 0;

  e[8]  = 0;
  e[9]  = 0;
  e[10] = -2 * rd;
  e[11] = 0;

  e[12] = -(right + left) * rw;
  e[13] = -(top + bottom) * rh;
  e[14] = -(far + near) * rd;
  e[15] = 1;

  return this;
};

/**
 * Multiply the orthographic projection matrix from the right.
 * @param left The coordinate of the left of clipping plane.
 * @param right The coordinate of the right of clipping plane.
 * @param bottom The coordinate of the bottom of clipping plane.
 * @param top The coordinate of the top top clipping plane.
 * @param near The distances to the nearer depth clipping plane. This value is minus if the plane is to be behind the viewer.
 * @param far The distances to the farther depth clipping plane. This value is minus if the plane is to be behind the viewer.
 * @return this
 */
SI.Math.Matrix4.prototype.ortho = function(left, right, bottom, top, near, far) {
  return this.concat(new Matrix4().setOrtho(left, right, bottom, top, near, far));
};

/**
 * Set the perspective projection matrix.
 * @param left The coordinate of the left of clipping plane.
 * @param right The coordinate of the right of clipping plane.
 * @param bottom The coordinate of the bottom of clipping plane.
 * @param top The coordinate of the top top clipping plane.
 * @param near The distances to the nearer depth clipping plane. This value must be plus value.
 * @param far The distances to the farther depth clipping plane. This value must be plus value.
 * @return this
 */
SI.Math.Matrix4.prototype.setFrustum = function(left, right, bottom, top, near, far) {
  var e, rw, rh, rd;

  if (left === right || top === bottom || near === far) {
    throw 'null frustum';
  }
  if (near <= 0) {
    throw 'near <= 0';
  }
  if (far <= 0) {
    throw 'far <= 0';
  }

  rw = 1 / (right - left);
  rh = 1 / (top - bottom);
  rd = 1 / (far - near);

  e = this.elements;

  e[ 0] = 2 * near * rw;
  e[ 1] = 0;
  e[ 2] = 0;
  e[ 3] = 0;

  e[ 4] = 0;
  e[ 5] = 2 * near * rh;
  e[ 6] = 0;
  e[ 7] = 0;

  e[ 8] = (right + left) * rw;
  e[ 9] = (top + bottom) * rh;
  e[10] = -(far + near) * rd;
  e[11] = -1;

  e[12] = 0;
  e[13] = 0;
  e[14] = -2 * near * far * rd;
  e[15] = 0;

  return this;
};

/**
 * Multiply the perspective projection matrix from the right.
 * @param left The coordinate of the left of clipping plane.
 * @param right The coordinate of the right of clipping plane.
 * @param bottom The coordinate of the bottom of clipping plane.
 * @param top The coordinate of the top top clipping plane.
 * @param near The distances to the nearer depth clipping plane. This value must be plus value.
 * @param far The distances to the farther depth clipping plane. This value must be plus value.
 * @return this
 */
SI.Math.Matrix4.prototype.frustum = function(left, right, bottom, top, near, far) {
  return this.concat(new Matrix4().setFrustum(left, right, bottom, top, near, far));
};

/**
 * Set the perspective projection matrix by fovy and aspect.
 * @param fovy The angle between the upper and lower sides of the frustum.
 * @param aspect The aspect ratio of the frustum. (width/height)
 * @param near The distances to the nearer depth clipping plane. This value must be plus value.
 * @param far The distances to the farther depth clipping plane. This value must be plus value.
 * @return this
 */
SI.Math.Matrix4.prototype.setPerspective = function(fovy, aspect, near, far) {
  var e, rd, s, ct;

  if (near === far || aspect === 0) {
    throw 'null frustum';
  }
  if (near <= 0) {
    throw 'near <= 0';
  }
  if (far <= 0) {
    throw 'far <= 0';
  }

  fovy = Math.PI * fovy / 180 / 2;
  s = Math.sin(fovy);
  if (s === 0) {
    throw 'null frustum';
  }

  rd = 1 / (far - near);
  ct = Math.cos(fovy) / s;

  e = this.elements;

  e[0]  = ct / aspect;
  e[1]  = 0;
  e[2]  = 0;
  e[3]  = 0;

  e[4]  = 0;
  e[5]  = ct;
  e[6]  = 0;
  e[7]  = 0;

  e[8]  = 0;
  e[9]  = 0;
  e[10] = -(far + near) * rd;
  e[11] = -1;

  e[12] = 0;
  e[13] = 0;
  e[14] = -2 * near * far * rd;
  e[15] = 0;

  return this;
};

/**
 * Multiply the perspective projection matrix from the right.
 * @param fovy The angle between the upper and lower sides of the frustum.
 * @param aspect The aspect ratio of the frustum. (width/height)
 * @param near The distances to the nearer depth clipping plane. This value must be plus value.
 * @param far The distances to the farther depth clipping plane. This value must be plus value.
 * @return this
 */
SI.Math.Matrix4.prototype.perspective = function(fovy, aspect, near, far) {
  return this.concat(new Matrix4().setPerspective(fovy, aspect, near, far));
};

/**
 * Set the matrix for scaling.
 * @param x The scale factor along the X axis
 * @param y The scale factor along the Y axis
 * @param z The scale factor along the Z axis
 * @return this
 */
SI.Math.Matrix4.prototype.setScale = function(x, y, z) {
  var e = this.elements;
  e[0] = x;  e[4] = 0;  e[8]  = 0;  e[12] = 0;
  e[1] = 0;  e[5] = y;  e[9]  = 0;  e[13] = 0;
  e[2] = 0;  e[6] = 0;  e[10] = z;  e[14] = 0;
  e[3] = 0;  e[7] = 0;  e[11] = 0;  e[15] = 1;
  return this;
};

/**
 * Multiply the matrix for scaling from the right.
 * @param x The scale factor along the X axis
 * @param y The scale factor along the Y axis
 * @param z The scale factor along the Z axis
 * @return this
 */
SI.Math.Matrix4.prototype.scale = function(x, y, z) {
  var e = this.elements;
  e[0] *= x;  e[4] *= y;  e[8]  *= z;
  e[1] *= x;  e[5] *= y;  e[9]  *= z;
  e[2] *= x;  e[6] *= y;  e[10] *= z;
  e[3] *= x;  e[7] *= y;  e[11] *= z;
  return this;
};

/**
 * Set the matrix for translation.
 * @param x The X value of a translation.
 * @param y The Y value of a translation.
 * @param z The Z value of a translation.
 * @return this
 */
SI.Math.Matrix4.prototype.setTranslate = function(x, y, z) {
  var e = this.elements;
  e[0] = 1;  e[4] = 0;  e[8]  = 0;  e[12] = x;
  e[1] = 0;  e[5] = 1;  e[9]  = 0;  e[13] = y;
  e[2] = 0;  e[6] = 0;  e[10] = 1;  e[14] = z;
  e[3] = 0;  e[7] = 0;  e[11] = 0;  e[15] = 1;
  return this;
};

/**
 * Multiply the matrix for translation from the right.
 * @param x The X value of a translation.
 * @param y The Y value of a translation.
 * @param z The Z value of a translation.
 * @return this
 */
SI.Math.Matrix4.prototype.translate = function(x, y, z) {
  var e = this.elements;
  e[12] += e[0] * x + e[4] * y + e[8]  * z;
  e[13] += e[1] * x + e[5] * y + e[9]  * z;
  e[14] += e[2] * x + e[6] * y + e[10] * z;
  e[15] += e[3] * x + e[7] * y + e[11] * z;
  return this;
};

/**
 * Set the matrix for rotation.
 * The vector of rotation axis may not be normalized.
 * @param angle The angle of rotation (degrees)
 * @param x The X coordinate of vector of rotation axis.
 * @param y The Y coordinate of vector of rotation axis.
 * @param z The Z coordinate of vector of rotation axis.
 * @return this
 */
SI.Math.Matrix4.prototype.setRotate = function(angle, x, y, z) {
  var e, s, c, len, rlen, nc, xy, yz, zx, xs, ys, zs;

  angle = Math.PI * angle / 180;
  e = this.elements;

  s = Math.sin(angle);
  c = Math.cos(angle);

  if (0 !== x && 0 === y && 0 === z) {
    // Rotation around X axis
    if (x < 0) {
      s = -s;
    }
    e[0] = 1;  e[4] = 0;  e[ 8] = 0;  e[12] = 0;
    e[1] = 0;  e[5] = c;  e[ 9] =-s;  e[13] = 0;
    e[2] = 0;  e[6] = s;  e[10] = c;  e[14] = 0;
    e[3] = 0;  e[7] = 0;  e[11] = 0;  e[15] = 1;
  } else if (0 === x && 0 !== y && 0 === z) {
    // Rotation around Y axis
    if (y < 0) {
      s = -s;
    }
    e[0] = c;  e[4] = 0;  e[ 8] = s;  e[12] = 0;
    e[1] = 0;  e[5] = 1;  e[ 9] = 0;  e[13] = 0;
    e[2] =-s;  e[6] = 0;  e[10] = c;  e[14] = 0;
    e[3] = 0;  e[7] = 0;  e[11] = 0;  e[15] = 1;
  } else if (0 === x && 0 === y && 0 !== z) {
    // Rotation around Z axis
    if (z < 0) {
      s = -s;
    }
    e[0] = c;  e[4] =-s;  e[ 8] = 0;  e[12] = 0;
    e[1] = s;  e[5] = c;  e[ 9] = 0;  e[13] = 0;
    e[2] = 0;  e[6] = 0;  e[10] = 1;  e[14] = 0;
    e[3] = 0;  e[7] = 0;  e[11] = 0;  e[15] = 1;
  } else {
    // Rotation around another axis
    len = Math.sqrt(x*x + y*y + z*z);
    if (len !== 1) {
      rlen = 1 / len;
      x *= rlen;
      y *= rlen;
      z *= rlen;
    }
    nc = 1 - c;
    xy = x * y;
    yz = y * z;
    zx = z * x;
    xs = x * s;
    ys = y * s;
    zs = z * s;

    e[ 0] = x*x*nc +  c;
    e[ 1] = xy *nc + zs;
    e[ 2] = zx *nc - ys;
    e[ 3] = 0;

    e[ 4] = xy *nc - zs;
    e[ 5] = y*y*nc +  c;
    e[ 6] = yz *nc + xs;
    e[ 7] = 0;

    e[ 8] = zx *nc + ys;
    e[ 9] = yz *nc - xs;
    e[10] = z*z*nc +  c;
    e[11] = 0;

    e[12] = 0;
    e[13] = 0;
    e[14] = 0;
    e[15] = 1;
  }

  return this;
};

/**
 * Multiply the matrix for rotation from the right.
 * The vector of rotation axis may not be normalized.
 * @param angle The angle of rotation (degrees)
 * @param x The X coordinate of vector of rotation axis.
 * @param y The Y coordinate of vector of rotation axis.
 * @param z The Z coordinate of vector of rotation axis.
 * @return this
 */
SI.Math.Matrix4.prototype.rotate = function(angle, x, y, z) {
  return this.concat(new SI.Math.Matrix4().setRotate(angle, x, y, z));
};

/**
 * Return a new rotation matrix, with rotation angle specified by theta
 * according to taitBryan angles.
 * I.e rotate(x).rotate(y).rotate(z)
 */
SI.Math.Matrix4.taitBryan = (theta0, theta1, theta2) => {
  theta0 = theta0 * Math.PI / 180;
  theta1 = theta1 * Math.PI / 180;
  theta2 = theta2 * Math.PI / 180;
  let c = {
    x: Math.cos(theta0),
    y: Math.cos(theta1),
    z: Math.cos(theta2)
  };
  let s = {
      x: Math.sin(theta0),
      y: Math.sin(theta1),
      z: Math.sin(theta2)
  };
  let m = new SI.Math.Matrix4();
  let e = m.elements;
  e[0] = c.y*c.z;
  e[1] = c.x*s.z + c.z*s.x*s.y;
  e[2] = s.x*s.z-c.x*c.z*s.y;
  e[3] = 0.0;
  e[4] = -c.y*s.z;
  e[5] = c.x*c.z-s.x*s.y*s.z;
  e[6] = c.z*s.x + c.x*s.y*s.z;
  e[7] = 0.0;
  e[8] = s.y;
  e[9] = -c.y*s.x;
  e[10] = c.x*c.y;
  e[11] = 0.0;
  return m;
};

/**
 * Set the viewing matrix.
 * @param eyeX, eyeY, eyeZ The position of the eye point.
 * @param centerX, centerY, centerZ The position of the reference point.
 * @param upX, upY, upZ The direction of the up vector.
 * @return this
 */
SI.Math.Matrix4.prototype.setLookAt = function(eyeX, eyeY, eyeZ, centerX, centerY, centerZ, upX, upY, upZ) {
  var e, fx, fy, fz, rlf, sx, sy, sz, rls, ux, uy, uz;

  fx = centerX - eyeX;
  fy = centerY - eyeY;
  fz = centerZ - eyeZ;

  // Normalize f.
  rlf = 1 / Math.sqrt(fx*fx + fy*fy + fz*fz);
  fx *= rlf;
  fy *= rlf;
  fz *= rlf;

  // Calculate cross product of f and up.
  sx = fy * upZ - fz * upY;
  sy = fz * upX - fx * upZ;
  sz = fx * upY - fy * upX;

  // Normalize s.
  rls = 1 / Math.sqrt(sx*sx + sy*sy + sz*sz);
  sx *= rls;
  sy *= rls;
  sz *= rls;

  // Calculate cross product of s and f.
  ux = sy * fz - sz * fy;
  uy = sz * fx - sx * fz;
  uz = sx * fy - sy * fx;

  // Set to this.
  e = this.elements;
  e[0] = sx;
  e[1] = ux;
  e[2] = -fx;
  e[3] = 0;

  e[4] = sy;
  e[5] = uy;
  e[6] = -fy;
  e[7] = 0;

  e[8] = sz;
  e[9] = uz;
  e[10] = -fz;
  e[11] = 0;

  e[12] = 0;
  e[13] = 0;
  e[14] = 0;
  e[15] = 1;

  // Translate.
  return this.translate(-eyeX, -eyeY, -eyeZ);
};

/**
 * Multiply the viewing matrix from the right.
 * @param eyeX, eyeY, eyeZ The position of the eye point.
 * @param centerX, centerY, centerZ The position of the reference point.
 * @param upX, upY, upZ The direction of the up vector.
 * @return this
 */
SI.Math.Matrix4.prototype.lookAt = function(eyeX, eyeY, eyeZ, centerX, centerY, centerZ, upX, upY, upZ) {
  return this.concat(new SI.Math.Matrix4().setLookAt(eyeX, eyeY, eyeZ, centerX, centerY, centerZ, upX, upY, upZ));
};

/**
 * Multiply the matrix for project vertex to plane from the right.
 * @param plane The array[A, B, C, D] of the equation of plane "Ax + By + Cz + D = 0".
 * @param light The array which stored coordinates of the light. if light[3]=0, treated as parallel light.
 * @return this
 */
SI.Math.Matrix4.prototype.dropShadow = function(plane, light) {
  var mat = new Matrix4();
  var e = mat.elements;

  var dot = plane[0] * light[0] + plane[1] * light[1] + plane[2] * light[2] + plane[3] * light[3];

  e[ 0] = dot - light[0] * plane[0];
  e[ 1] =     - light[1] * plane[0];
  e[ 2] =     - light[2] * plane[0];
  e[ 3] =     - light[3] * plane[0];

  e[ 4] =     - light[0] * plane[1];
  e[ 5] = dot - light[1] * plane[1];
  e[ 6] =     - light[2] * plane[1];
  e[ 7] =     - light[3] * plane[1];

  e[ 8] =     - light[0] * plane[2];
  e[ 9] =     - light[1] * plane[2];
  e[10] = dot - light[2] * plane[2];
  e[11] =     - light[3] * plane[2];

  e[12] =     - light[0] * plane[3];
  e[13] =     - light[1] * plane[3];
  e[14] =     - light[2] * plane[3];
  e[15] = dot - light[3] * plane[3];

  return this.concat(mat);
};

/**
 * Multiply the matrix for project vertex to plane from the right.(Projected by parallel light.)
 * @param normX, normY, normZ The normal vector of the plane.(Not necessary to be normalized.)
 * @param planeX, planeY, planeZ The coordinate of arbitrary points on a plane.
 * @param lightX, lightY, lightZ The vector of the direction of light.(Not necessary to be normalized.)
 * @return this
 */
SI.Math.Matrix4.prototype.dropShadowDirectionally = function(normX, normY, normZ, planeX, planeY, planeZ, lightX, lightY, lightZ) {
  var a = planeX * normX + planeY * normY + planeZ * normZ;
  return this.dropShadow([normX, normY, normZ, -a], [lightX, lightY, lightZ, 0]);
};


//FROM HERE CT'S CODE

/*
 * Copyright (c) 2014-2016 Markus Moenig <markusm@visualgraphics.tv> and Contributors
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */


//TODO implement own Matrix4

/**
 * Transform a single vector 3 or 4 array
 * @param {Array} p - The vector array
 * @param {Bool} normal - Determines if the vector is a normal, must be 3 element long
 */

SI.Math.Matrix4.prototype.transformVectorArray=function(p, normal)
{
    var e = this.elements;

    var x = 0.0;
    var y = 0.0;
    var z = 0.0;
    var w = 0.0;

    if (p.length == 3)
    {
        if (normal)
        {
            x = p[0] * e[0] + p[1] * e[4] + p[2] * e[ 8];
            y = p[0] * e[1] + p[1] * e[5] + p[2] * e[ 9];
            z = p[0] * e[2] + p[1] * e[6] + p[2] * e[10];
        }
        else
        {
            x = p[0] * e[0] + p[1] * e[4] + p[2] * e[ 8] + e[12];
            y = p[0] * e[1] + p[1] * e[5] + p[2] * e[ 9] + e[13];
            z = p[0] * e[2] + p[1] * e[6] + p[2] * e[10] + e[14];
        }

    }
    else
    if (p.length == 4)
    {

        x = p[0] * e[0] + p[1] * e[4] + p[2] * e[ 8] + p[3] * e[12];
        y = p[0] * e[1] + p[1] * e[5] + p[2] * e[ 9] + p[3] * e[13];
        z = p[0] * e[2] + p[1] * e[6] + p[2] * e[10] + p[3] * e[14];
        w = p[0] * e[3] + p[1] * e[7] + p[2] * e[11] + p[3] * e[15];
    }

    p[0] = x;
    p[1] = y;
    p[2] = z;
    if (p[3])
        p[3] = w;
};

/** Multiplies against
 *  @paramn {SI.Math.Matrix4} other - The other matrix
 *  @return this
 */

SI.Math.Matrix4.prototype.mul=function(other)
{
    return this.concat(other);
};

/** Sets this matrix rotation from a quaternion
 *  @param {SI.Math.Quat} q - The quaternion
 *  @return this */

SI.Math.Matrix4.prototype.setQuatRotation=function(q)
{
    var te = this.elements;

    var x = q.x;
    var y = q.y;
    var z = q.z;
    var w = q.w;

    var x2 = x + x;
    var y2 = y + y;
    var z2 = z + z;

    var xx = x * x2;
    var xy = x * y2;
    var xz = x * z2;

    var yy = y * y2;
    var yz = y * z2;
    var zz = z * z2;
    var wx = w * x2;
    var wy = w * y2;
    var wz = w * z2;

    te[0] = 1 - (yy + zz);
    te[4] = xy - wz;
    te[8] = xz + wy;

    te[1] = xy + wz;
    te[5] = 1 - (xx + zz);
    te[9] = yz - wx;

    te[2]  = xz - wy;
    te[6]  = yz + wx;
    te[10] = 1 - (xx + yy);

    te[3]  = 0;
    te[7]  = 0;
    te[11] = 0;

    te[12] = 0;
    te[13] = 0;
    te[14] = 0;
    te[15] = 1;

    return this;
};

/** Converts degrees to radians
 * @param {Number} deg - The degree value to convert
 */

SI.Math.rad=function(deg)
{
    return deg * (Math.PI / 180.0);
};

/** Converts radians to degrees
 *  @param {Number} rad - The radian value to convert
 */

SI.Math.deg=function(rad)
{
    return rad * (180.0 / Math.PI);
};

/** Float linear interpolation
 *  @param {Number} a - The value from
 *  @param {Number} b - The value to
 *  @param {Number} d - The alpha / time */

SI.Math.lerp=function(a, b, d)
{
    return a + (d * (b - a));
};

/** Clamps val between min and max.
 *  @param {Number} val - The value to clamp
 *  @param {Number} min - The minimum border
 *  @param {Number} max - The maximum border */

SI.Math.clamp=function(val, min, max)
{
    return Math.min(Math.max(val, min), max);
};

//TODO upgrade to use Vector2
SI.Math.testLine=function(vT, v0, v1)
{
    /** Tests if the given lines intersects */
    var x0 = vT.x - v0.x;
    var y0 = vT.y - v0.y;

    var x1 = v1.x - v0.x;
    var y1 = v1.y - v0.y;
    var x0y1 = x0 * y1;
    var x1y0 = x1 * y0;
    var det = x0y1 - x1y0;

    var zero = 0.0;
    return ( det > zero ? 1 : (det < zero ? -1 : 0) );
};

//TODO upgrade to use Vector2
SI.Math.testTri=function(ts, v0, v1, v2)
{
    /** Test if the given triangles intersects */
    var sign0 = SI.Math.testLine(ts, v1, v2);
    if (sign0 > 0) return 1;

    var sign1 = SI.Math.testLine(ts, v0, v2);
    if (sign1 < 0) return 1;

    var sign2 = SI.Math.testLine(ts, v0, v1);
    if (sign2 > 0) return 1;

    return (sign0 && sign1 && sign2) ? -1 : 0;
};

SI.Math.bezierCubic=function(t, p0, p1, p2, p3)
{
    function Bp0(t, p) { var k = 1 - t; return k * k * k * p; }
    function Bp1(t, p) { var k = 1 - t; return 3 * k * k * t * p; }
    function Bp2(t, p) { var k = 1 - t; return 3 * k * t * t * p; }

    function Bp3(t, p) { return t * t * t * p; }

    return Bp0(t, p0) + Bp1(t, p1) + Bp2(t, p2) + Bp3(t, p3);
};

SI.Math.bezier=function(t, p0, p1, p2)
{
    function Bp0(t, p) { var k = 1 - t; return k * k * p; }
    function Bp1(t, p) { return 2 * (1 - t) * t * p; }
    function Bp2(t, p) { return t * t * p; }

    return Bp0(t, p0) + Bp1(t, p1) + Bp2(t, p2);
};


/** Two-dimensional vector class
 *  @constructor
 *  @param {number} x
 *  @param {number} y
 */


SI.Math.Vector2=function(x, y)
{
    if (!(this instanceof SI.Math.Vector2)) return new SI.Math.Vector2(x, y);

    this.x = x ? x : 0.0;
    this.y = y ? y : 0.0;
};

/** Sets the vector from individual components
 *  @param {Number} x - The x component
 *  @param {Number} y - The y component
 */

SI.Math.Vector2.prototype.set=function(x, y)
{
    this.x = x;
    this.y = y;
};

/** Copies the vector
 *  @param {SI.Math.Vector2} other - The vector to copy from
 *  @returns this */

SI.Math.Vector2.prototype.copy=function(other)
{
    this.x = other.x;
    this.y = other.y;

    return this;
};

/** Returns a copy of this vector
 *  @returns SI.Math.Vector2 */

SI.Math.Vector2.prototype.clone=function()
{
    return new SI.Math.Vector2(this.x, this.y);
};

/** Adds the provided value into this vector
 *  @param {SI.Math.Vector2 | number} v - The value to add
 *  @returns this */

SI.Math.Vector2.prototype.add=function(v)
{
    if (v instanceof SI.Math.Vector2)
    {
        this.x += v.x;
        this.y += v.y;
    }
    else
    {
        this.x += v;
        this.y += v;
    }

    return this;
};

/** Substracts the provided value from this vector
 *  @param {SI.Math.Vector2 | number} v - The value to substract
 *  @returns this */

SI.Math.Vector2.prototype.sub=function(v)
{
    if (v instanceof SI.Math.Vector2)
    {
        this.x -= v.x;
        this.y -= v.y;
    }
    else
    {
        this.x -= v;
        this.y -= v;
    }

    return this;
};

/** Multiplies this vector by the provided value
 *  @param {SI.Math.Vector2 | number} v - The multiplier
 *  @returns this */

SI.Math.Vector2.prototype.mul=function(v)
{
    if (v instanceof SI.Math.Vector2)
    {
        this.x *= v.x;
        this.y *= v.y;
    }
    else
    {
        this.x *= v;
        this.y *= v;
    }

    return this;
};

/** Divides this vector by the provided value
 *  @param {SI.Math.Vector2 | number} v - The divisor
 *  @returns this */

SI.Math.Vector2.prototype.div=function(v)
{
    if (v instanceof SI.Math.Vector2)
    {
        this.x /= v.x;
        this.y /= v.y;
    }
    else
    {
        this.x /= v;
        this.y /= v;
    }

    return this;
};

/** Negates into a new vector
 *  @returns SI.Math.Vector2 */

SI.Math.Vector2.prototype.neg=function()
{
    return new SI.Vector2(-this.x, -this.y);
};

/** Dot product
 *  @param {SI.Math.Vector2} v - The other vector
 *  @returns number */

SI.Math.Vector2.prototype.dot=function(v)
{
    return this.x * v.x + this.y * v.y;
};

/** Vector length
 *  @returns number */

SI.Math.Vector2.prototype.length=function()
{
    return Math.sqrt(this.x * this.x + this.y * this.y);
};

/** Vector square length
 *  @returns number */

SI.Math.Vector2.prototype.lengthSq=function()
{
    return this.x * this.x + this.y * this.y;
};

/** Normalizes the vector, returns the inverse scalar
 *  @returns number */

SI.Math.Vector2.prototype.normalize=function()
{
    var invScal = 1 / this.length();

    this.mul(invScal);

    return invScal;
};

/** Returns a normalized copy of this vector
 *  @returns SI.Math.Vector2 */

SI.Math.Vector2.prototype.normalized=function()
{
    var v = this.clone();
    v.normalize();

    return v;
};

/** Returns the distance to the provided vector
 *  @param {SI.Math.Vector2} v - The other vector
 *  @returns number */

SI.Math.Vector2.prototype.dist=function(v)
{
    return Math.sqrt(this.distSq(v));
};

/** Returns the squared distance to the provided vector
 *  @param {SI.Math.Vector2} v - The other vector
 *  @returns number */

SI.Math.Vector2.prototype.distSq=function(v)
{
    var dx = this.x - v.x;
    var dy = this.y - v.y;

    return dx * dx + dy * dy;
};

/** Returns the quadratic angle in radians
 *  @params {SI.Math.Vector2} v - The other vector */

SI.Math.Vector2.prototype.angleTo=function(v)
{
    return Math.atan2(v.x - this.x, v.y - this.y);
};

SI.Math.Vector2.prototype.dirFromAngle=function(a)
{
    /** Returns the a normalized direction from a quadratic angle in radians
     *  @params {number} a - The angle in radians */

    this.y = Math.cos(a);
    this.x = Math.sin(a);

    return this;
};

/** Linearly interpolates to the provided vector
 *  @param {SI.Math.Vector2} v - The other vector
 *  @param {number} delta - The interpolation delta
 *  @returns this */

SI.Math.Vector2.prototype.lerp=function(v, delta)
{
    this.x += (v.x - this.x) * alpha;
    this.y += (v.y - this.y) * alpha;

    return this;
};

/** Applies floor function to this vector */

SI.Math.Vector2.prototype.floor=function()
{
    this.x = Math.floor(this.x);
    this.y = Math.floor(this.y);

    return this;
};

/** Applies ceil function to this vector */

SI.Math.Vector2.prototype.ceil=function()
{
    this.x = Math.ceil(this.x);
    this.y = Math.ceil(this.y);

    return this;
};

/** Applies round function to this vector */

SI.Math.Vector2.prototype.round=function()
{
    this.x = Math.round(this.x);
    this.y = Math.round(this.y);

    return this;
};

/** Sets this vector (direction) to its perpendicular form */

SI.Math.Vector2.prototype.setPerpendicular=function()
{
    var invX = -this.y;
    var invY = this.x;

    var length = this.length();

    this.x = invX / length;
    this.y = invY / length;
};

SI.Math.Vector2.Zero = new SI.Math.Vector2(0, 0);
SI.Math.Vector2.Up = new SI.Math.Vector2(1, 0);






/** Three-dimensional vector class
 *  @constructor
 *  @param {number} x
 *  @param {number} y
 *  @param {number} z
 */

SI.Math.Vector3=function(x, y, z)
{
    if (!(this instanceof SI.Math.Vector3)) return new SI.Math.Vector3(x, y, z);

    this.x = x ? x : 0.0;
    this.y = y ? y : 0.0;
    this.z = z ? z : 0.0;
};

/** Sets the vector values directly
 *  @param {number} x
 *  @param {number} y
 *  @param {number} z
 */

SI.Math.Vector3.prototype.set=function(x, y, z)
{
    this.x = x;
    this.y = y;
    this.z = z;

    return this;
};

/** Copies the vector
 *  @param {SI.Math.Vector3} other - The vector to copy from
 *  @returns this */

SI.Math.Vector3.prototype.copy=function(other)
{
    this.x = other.x;
    this.y = other.y;
    this.z = other.z;

    return this;
};

/**
 * Returns array of all components.
 *  @returns [x, y, z] */

SI.Math.Vector3.prototype.toArray = function()
{
    return [this.x, this.y, this.z];
};

/** set array of all components.
 *  @param [x, y, z] array - array to set
 */

SI.Math.Vector3.prototype.getArray = function(array)
{
  array[0] = this.x;
    array[1] = this.y;
    array[2] = this.z;
};

/** Returns a copy of this vector
 *  @returns SI.Math.Vector3 */

SI.Math.Vector3.prototype.clone=function()
{
    return new SI.Math.Vector3(this.x, this.y, this.z);
};

/** Adds the provided value into this vector
 *  @param {SI.Math.Vector3 | number} v - The value to add
 *  @returns this */

SI.Math.Vector3.prototype.add=function(v)
{
    if (v instanceof SI.Math.Vector3)
    {
        this.x += v.x;
        this.y += v.y;
        this.z += v.z;
    }
    else
    {
        this.x += v;
        this.y += v;
        this.z += v;
    }

    return this;
};

/** Adds the given vector multiplied
 *  @param {SI.Math.Vector3} v - The value to add
 *  @param {Number} m - The multiplier as vector3 * m
 *  @returns this */

SI.Math.Vector3.prototype.addMul=function(v, m)
{
    this.x += v.x * m;
    this.y += v.y * m;
    this.z += v.z * m;

    return this;
};

/** Substracts the provided value from this vector
 *  @param {SI.Math.Vector3 | number} v - The value to substract
 *  @returns this */

SI.Math.Vector3.prototype.sub=function(v)
{
    if (v instanceof SI.Math.Vector3)
    {
        this.x -= v.x;
        this.y -= v.y;
        this.z -= v.z;
    }
    else
    {
        this.x -= v;
        this.y -= v;
        this.z -= v;
    }

    return this;
};

/** Multiplies this vector by the provided value
 *  @param {SI.Math.Vector3 | number} v - The multiplier
 *  @returns this */

SI.Math.Vector3.prototype.mul=function(v)
{
    if (v instanceof SI.Math.Vector3)
    {
        this.x *= v.x;
        this.y *= v.y;
        this.z *= v.z;
    }
    else
    {
        this.x *= v;
        this.y *= v;
        this.z *= v;
    }

    return this;
};

/** Divides this vector by the provided value
 *  @param {SI.Math.Vector3 | number} v - The divisor
 *  @returns this */

SI.Math.Vector3.prototype.div=function(v)
{
    if (v instanceof SI.Math.Vector3)
    {
        this.x /= v.x;
        this.y /= v.y;
        this.z /= v.z;
    }
    else
    {
        this.x /= v;
        this.y /= v;
        this.z /= v;
    }

    return this;
};

/** Negates this vector */

SI.Math.Vector3.prototype.negate=function()
{
    this.x = -this.x;
    this.y = -this.y;
    this.z = -this.z;

    return this;
};

/** Negates into a new vector
 *  @returns SI.Math.Vector3 */

SI.Math.Vector3.prototype.negated=function()
{
    return this.clone().negate();
};

/** Dot product
 *  @param {SI.Math.Vector3} v - The other vector
 *  @returns number */

SI.Math.Vector3.prototype.dot=function(v)
{
    return this.x * v.x + this.y * v.y + this.z * v.z;
};

/** Vector length
 *  @returns number */

SI.Math.Vector3.prototype.length=function()
{
    return Math.sqrt(this.x * this.x + this.y * this.y + this.z * this.z);
};

/** Vector square length
 *  @returns number */

SI.Math.Vector3.prototype.lengthSq=function()
{
    return this.x * this.x + this.y * this.y + this.z * this.z;
};

/** Normalizes the vector, returns the inverse scalar
 *  @returns number */

SI.Math.Vector3.prototype.normalize=function()
{
    var invScal = 1 / this.length();

    this.mul(invScal);

    return invScal;
};

/** Sets the min value per component
 *  @param {SI.Math.Vector3} v - The vector
 *  @returns this */

SI.Math.Vector3.prototype.min=function(v)
{
    if (this.x > v.x) this.x = v.x;
    if (this.y > v.y) this.y = v.y;
    if (this.z > v.z) this.z = v.z;

    return this;
};

/** Sets the max value per component
 *  @param {SI.Math.Vector3} v - The vector
 *  @returns this */

SI.Math.Vector3.prototype.max=function(v)
{
    if (this.x < v.x) this.x = v.x;
    if (this.y < v.y) this.y = v.y;
    if (this.z < v.z) this.z = v.z;

    return this;
};

/** Returns a normalized copy of this vector
 *  @returns SI.Math.Vector3 */

SI.Math.Vector3.prototype.normalized=function()
{
    var v = this.clone();
    v.normalize();

    return v;
};

/** Returns the distance to the provided vector
 *  @param {SI.Math.Vector3} v - The other vector
 *  @returns number */

SI.Math.Vector3.prototype.dist=function(v)
{
    return Math.sqrt(this.distSq(v));
};

/** Returns the squared distance to the provided vector
 *  @param {SI.Math.Vector3} v - The other vector
 *  @returns number */

SI.Math.Vector3.prototype.distSq=function(v)
{
    var dx = this.x - v.x;
    var dy = this.y - v.y;
    var dz = this.z - v.z;

    return dx * dx + dy * dy + dz * dz;
};

/** Linearly interpolates to the provided vector
 *  @param {SI.Math.Vector3} v - The other vector
 *  @param {number} alpha - The interpolation alpha
 *  @returns this */

SI.Math.Vector3.prototype.lerp=function(v, alpha)
{
    this.x += (v.x - this.x) * alpha;
    this.y += (v.y - this.y) * alpha;
    this.z += (v.z - this.z) * alpha;

    return this;
};

/** Applies round function to this vector */

SI.Math.Vector3.prototype.round=function()
{
    this.x = Math.round(this.x);
    this.y = Math.round(this.y);
    this.z = Math.round(this.z);

    return this;
};

/* Computes the surface normal of the given three-dimmensional triangle
 * result is set into this vector.
 *
 * @param {SI.Math.Vector3} p1 - Point in a triangle
 * @param {SI.Math.Vector3} p2 - Point in a triangle
 * @param {SI.Math.Vector3} p2 - Point in a triangle */

SI.Math.Vector3.prototype.computeNormal=function(p1, p2, p3)
{
    var u = p2.clone().sub(p1);
    var v = p3.clone().sub(p1);

    this.x = (u.y * v.z) - (u.z * v.y);
    this.y = (u.z * v.x) - (u.x * v.z);
    this.z = (u.x * v.y) - (u.y * v.x);

    return this;
};

/**
 * Compute cross product from vectors, this cross B.
 * @param {SI.Math.Vector3} B - a vector
 */

SI.Math.Vector3.prototype.cross=function(B)
{
    var A = this;
    return new SI.Math.Vector3(
        A.y * B.z - A.z * B.y,
        A.z * B.x - A.x * B.z,
        A.x * B.y - A.y * B.x
    );
};

/** Transforms this vector by a matrix4
 *  @param {SI.Math.Matrix4}
 *  @returns this */

SI.Math.Vector3.prototype.transform=function(m, byVector)
{
    var p = [this.x, this.y, this.z];

    m.transformVectorArray(p, byVector);

    this.x = p[0];
    this.y = p[1];
    this.z = p[2];

    return this;
};

SI.Math.Vector3.Zero = new SI.Math.Vector3(0, 0, 0);
SI.Math.Vector3.Up = new SI.Math.Vector3(0, 1, 0);
SI.Math.Vector3.Right = new SI.Math.Vector3(1, 0, 0);
SI.Math.Vector3.Front = new SI.Math.Vector3(0, 0, -1);







/** Four-dimmensional vector (mostly used for matrix transform)
 *  @constructor
 *  @param {Number} x - The x component
 *  @param {Number} y - The x component
 *  @param {Number} z - The x component
 *  @param {Number} w - The x component */

SI.Math.Vector4=function(x, y, z, w)
{
    if (!(this instanceof SI.Math.Vector4)) return new SI.Math.Vector4(x, y, z, w);

    this.set(x, y, z, w);
};

/** Sets the vector
 *  @param {Number} x - The x component
 *  @param {Number} y - The x component
 *  @param {Number} z - The x component
 *  @param {Number} w - The x component */

SI.Math.Vector4.prototype.set=function(x, y, z, w)
{
    this.x = x;
    this.y = y;
    this.z = z;
    this.w = w;
};

/** Copies the vector
 *  @param {SI.Math.Vector4} other - The vector to copy from
 *  @returns this */

SI.Math.Vector4.prototype.copy=function(other)
{
    this.x = other.x;
    this.y = other.y;
    this.z = other.z;
    this.w = other.w;

    return this;
};

/** Transforms this vector by a matrix4
 *  @param {SI.Math.Matrix4}
 *  @returns this */

SI.Math.Vector4.prototype.transform=function(m)
{
    var p = [this.x, this.y, this.z, this.w];

    m.transformVectorArray(p);

    this.x = p[0];
    this.y = p[1];
    this.z = p[2];
    this.w = p[3];

    return this;
};

/** Returns array of all components.
 *  @returns [x, y, z, w] */

SI.Math.Vector4.prototype.toArray = function()
{
    return [this.x, this.y, this.z, this.w];
};

/** set array of all components.
 *  @param [x, y, z, w] array - array to set*/

SI.Math.Vector4.prototype.getArray = function(array)
{
    array[0] = this.x;
    array[1] = this.y;
    array[2] = this.z;
    array[3] = this.w;
};


/** Axis aligned bounding box
 *  @constructor */

SI.Math.Aabb=function()
{
    /** Minimum bounds vector
     *  @member {SI.Math.Vector3} */
    this.min = new SI.Math.Vector3();

    /** Minimum bounds vector
     *  @member {SI.Math.Vector3} */
    this.max = new SI.Math.Vector3();

    this.setEmpty();
};

/** Copies the given aabb into this
 *  @param {SI.Math.Aabb} other - The aabb to copy from
 *  @returns this */

SI.Math.Aabb.prototype.copy=function(other)
{
    this.min.copy(other.min);
    this.max.copy(other.max);

    return this;
};

/** Checks the validity of the bounds
 *  @return {Bool} */


SI.Math.Aabb.prototype.isValid=function()
{
    return this.min.length() > 0 || this.max.length() > 0;
};

/** Expands by the given value (Vector or another Aabb)
 *  @param {SI.Math.Vector3 | SI.Math.Vector4 | SI.Math.Aabb} v - The value */

SI.Math.Aabb.prototype.expand=function(v)
{
    if (v instanceof SI.Math.Vector3)
    {
        this.min.min(v);
        this.max.max(v);
    }
    else
    if (v instanceof SI.Math.Vector4)
    {
        var v3 = SI.Math.Aabb.__cacheV3;

        v3.copy(v);

        this.min.min(v3);
        this.max.max(v3);
    }
    else
    if (v instanceof SI.Math.Aabb)
    {
    }
    else
    {
        throw "Value not recognized or undefined";
    }
};

/** Sets the bounds from a half extent vector
 * @param {SI.Math.Vector3} halfExtent - The half extent vector */

SI.Math.Aabb.prototype.setFromHalfExtent=function(halfExtent)
{
    this.min.copy(halfExtent).negate();
    this.max.copy(halfExtent);
};

/** Sets the bounds from a center vector and a radius
 * @param {SI.Math.Vector3} center - Center vector */

SI.Math.Aabb.prototype.setFromCenterRadius=function(center, radius)
{
    var hE = radius;

    this.setHalfExtent(new SI.Math.Vector3(hE, hE, hE));

    this.min.add(center);
    this.max.add(center);
};

SI.Math.Aabb.__cacheV3 = new SI.Math.Vector3();

SI.Math.Aabb.__cacheV4Array = [
    new SI.Math.Vector4(),
    new SI.Math.Vector4(),
    new SI.Math.Vector4(),
    new SI.Math.Vector4(),
    new SI.Math.Vector4(),
    new SI.Math.Vector4(),
    new SI.Math.Vector4(),
    new SI.Math.Vector4()
];

/** Sets the bounds as empty/null
 *  @returns this */


SI.Math.Aabb.prototype.setEmpty=function()
{
    this.min.x = Infinity;
    this.min.y = Infinity;
    this.min.z = Infinity;

    this.max.x = -Infinity;
    this.max.y = -Infinity;
    this.max.z = -Infinity;

    return this;
};

/** Tests if the given Aabb overlaps with this bounds
 *  @param {SI.Math.Aabb} other - The other aabb
 *  @returns {Bool}*/

SI.Math.Aabb.prototype.overlaps=function(other)
{
    if (other.max.x < this.min.x || other.min.x > this.max.x ||
        other.max.y < this.min.y || other.min.y > this.max.y ||
        other.max.z < this.min.z || other.min.z > this.max.z)
    {
        return false;
    }

    return true;
};

/** Transforms the aabb by the given matrix
 *  @param {SI.Math.Matrix4} m - The matrix
 *  @returns this */

SI.Math.Aabb.prototype.transform=function(m)
{
    var p = SI.Math.Aabb.__cacheV4Array;

    p[0].set(this.min.x, this.min.y, this.min.z, 1.0);
    p[1].set(this.min.x, this.min.y, this.max.z, 1.0);
    p[2].set(this.min.x, this.max.y, this.min.z, 1.0);
    p[3].set(this.min.x, this.max.y, this.max.z, 1.0);
    p[4].set(this.max.x, this.min.y, this.min.z, 1.0);
    p[5].set(this.max.x, this.min.y, this.max.z, 1.0);
    p[6].set(this.max.x, this.max.y, this.min.z, 1.0);
    p[7].set(this.max.x, this.max.y, this.max.z, 1.0);

    this.setEmpty();

    for (var i = 0; i < p.length; i++)
    {
        this.expand(p[i].transform(m));
    }

    return this;
};

SI.Math.Aabb.prototype.sample=function()
{
    var svec=new SI.Math.Vector3();

    svec.x=this.min.x + (this.max.x - this.min.x) * Math.random();
    svec.y=this.min.y + (this.max.y - this.min.y) * Math.random();
    svec.z=this.min.z + (this.max.z - this.min.z) * Math.random();

    //SI.log( this.min.x, this.min.y, this.min.z, this.max.x, this.max.y, this.max.z );

    return svec;
};

/** Quaternion
 *
 *  @constructor
 *  @param {SI.Math.Quat} q - A quaternion to copy from
 *
 *  @constructor
 *  @param {Number} x - The x component
 *  @param {Number} y - The y component
 *  @param {Number} z - The z component
 *  @param {Number} w - The w component
 *
 *  @constructor
 *  @param {Number} yaw - Yaw in radians
 *  @param {Number} pitch - Pitch in radians
 *  @param {Number} roll - Roll in radians */

SI.Math.Quat=function()
{
    this.x = 0.0;
    this.y = 0.0;
    this.z = 0.0;
    this.w = 0.0;

    if (arguments.length == 1 && arguments[0] instanceof SI.Math.Quat)
    {
        this.copy(arguments[0]);
    }
    else
    if (arguments.length == 3)
    {
        this.setEuler(arguments[0], arguments[1], arguments[2]);
    }
    else
    if (arguments.length == 4)
    {
        this.x = arguments[0];
        this.y = arguments[1];
        this.z = arguments[2];
        this.w = arguments[3];
    }
    else
    {
        this.setIdentity();
    }
};

/** Clones this quaternion
 *  @return {SI.Math.Quat} */

SI.Math.Quat.prototype.clone=function()
{
    return new SI.Math.Quat(this);
};

/** Copies the provided quaternion into this one
 *  @param {SI.Math.Quat} other - The other quaternion
 *  @return this */

SI.Math.Quat.prototype.copy=function(other)
{
    this.x = other.x;
    this.y = other.y;
    this.z = other.z;
    this.w = other.w;

    return this;
};

/** Sets this quaternion angle axis
 *  @param {Number} angle - The angle in radians
 *  @param {SI.Math.Vector3} axis - The axis vector, normalized
 *  @return this */

SI.Math.Quat.prototype.setAxis=function(angle, axis)
{
    var hAngle = angle * 0.5;
    var s0 = Math.sin(hAngle);

    this.x = axis.x * s0;
    this.y = axis.y * s0;
    this.z = axis.z * s0;
    this.w = Math.cos(hAngle);

    return this;
};

/** Sets this quaternion from euler angles in radians
 *  @param {Number} yaw - Yaw in radians
 *  @param {Number} pitch - Pitch in radians
 *  @param {Number} roll- Roll in radians
 *  @return this */

SI.Math.Quat.prototype.setEuler=function(yaw, pitch, roll)
{
    //order hack
    var x = pitch;
    var y = yaw;
    var z = roll;

    var c1 = Math.cos(x * 0.5);
    var c2 = Math.cos(y * 0.5);
    var c3 = Math.cos(z * 0.5);

    var s1 = Math.sin(x * 0.5);
    var s2 = Math.sin(y * 0.5);
    var s3 = Math.sin(z * 0.5);

    this.x = s1 * c2 * c3 + c1 * s2 * s3;
    this.y = c1 * s2 * c3 - s1 * c2 * s3;
    this.z = c1 * c2 * s3 + s1 * s2 * c3;
    this.w = c1 * c2 * c3 - s1 * s2 * s3;

    return this;
};

/** Returns the length squared of this quaternion
 *  @return {Number} */

SI.Math.Quat.prototype.lengthSq=function()
{
    return this.x * this.x + this.y * this.y + this.z * this.z + this.w * this.w;
};

/** Returns the length of this quaternion
 *  @return {Number} */

SI.Math.Quat.prototype.length=function()
{
    return Math.sqrt(this.lengthSq());
};

/** Inverses this quaternion in place
 *  @return this */

SI.Math.Quat.prototype.inverse=function()
{
    this.conj();
    this.normalize();

    return this;
};

/** Sets this quaternion as identity (0, 0, 0, 1) */

SI.Math.Quat.prototype.setIdentity=function()
{
    this.x = 0.0;
    this.y = 0.0;
    this.z = 0.0;
    this.w = 1.0;
};

/** Returns the dot product
 *  @param {SI.Math.Quat} other - The other quaternion
 *  @return {Number} */

SI.Math.Quat.prototype.dot=function(other)
{
    return this.x * other.x + this.y * other.y + this.z * other.z + this.w * other.w;
};

/** Normalizes this quaternion
 *  @return this */

SI.Math.Quat.prototype.normalize=function()
{
    var len = this.length();

    if (len === 0)
    {
        this.setIdentity();
    }
    else
    {
        this.x = this.x * len;
        this.y = this.y * len;
        this.z = this.z * len;
        this.w = this.w * len;
    }

    return this;
};

/** Multiplies two quaternions and sets the result into this quaternion
 *  @param {SI.Math.Quat} a = The A quaternion
 *  @param {SI.Math.Quat} b = The B quaternion
 *  @return this */

SI.Math.Quat.prototype.setMul=function(a, b)
{

    var ax = a.x;
    var ay = a.y;
    var az = a.z;
    var aw = a.w;

    var bx = b.x;
    var by = b.y;
    var bz = b.z;
    var bw = b.w;

    this.x = ax * bw + aw * bx + ay * bz - az * by;
    this.y = ay * bw + aw * by + az * bx - ax * bz;
    this.z = az * bw + aw * bz + ax * by - ay * bx;
    this.w = aw * bw - ax * bx - ay * by - az * bz;

    return this;
};

/** Multiplies against the provided quaternion
 *  @param {SI.Math.Quat} other - The other quaternion
 *  @return this */

SI.Math.Quat.prototype.mul=function(other)
{
    this.setMul(this, other);

    return this;
};

/** Multiplies against the provided quaternion in inverse order
 *  @param {SI.Math.Quat} other - The other quaternion
 *  @return this */

SI.Math.Quat.prototype.mulInv=function(other)
{
    this.setMul(other, this);

    return this;
};

/** Conjugates this quaternion
 *  @return this */

SI.Math.Quat.prototype.conj=function()
{

    this.x = this.x * -1.0;
    this.y = this.y * -1.0;
    this.z = this.z * -1.0;

    return this;
};

/** Rotates a vector
 *  @param {SI.Math.Vector3} vin - The vector to rotate
 *  @param {SI.Math.Vector3} [null] vout - If not null/undefined then vin is left untouched */

SI.Math.Quat.prototype.rotateVector=function(vin, vout)
{
    var vx = vin.x;
    var vy = vin.y;
    var vz = vin.z;

    var qx = this.x;
    var qy = this.y;
    var qz = this.z;
    var qw = this.w;

    var rx = qw * vx + qy * vz - qz * vy;
    var ry = qw * vy + qz * vx - qx * vz;
    var rz = qw * vz + qx * vy - qy * vx;
    var rw = -qx * vx - qy * vy - qz * vz;

    if (!vout)
    {
        vout = vin;
    }

    vout.x = rx * qw + rw * -qx + ry * -qz - rz * -qy;
    vout.y = ry * qw + rw * -qy + rz * -qx - rx * -qz;
    vout.z = rz * qw + rw * -qz + rx * -qy - ry * -qx;
};

/** Sphere-interpolates this quaternion against
 *  @param {SI.Math.Quat} qb - The other quaternion
 *  @param {Number} t - The alpha
 *  @return this */

SI.Math.Quat.prototype.slerp=function(qb, a)
{
    if (a === 0) return this;
    if (a === 1) return this.copy(qb);

    var x = this.x;
    var y = this.y;
    var z = this.z;
    var w = this.w;

    var chTheta = w * qb.w + x * qb.x + y * qb.y + z * qb.z;

    if (chTheta < 0)
    {
        this.x = -qb.x;
        this.y = -qb.y;
        this.z = -qb.z;
        this.w = -qb.w;

        chTheta = -chTheta;
    }
    else
    {
        this.copy(qb);
    }

    if (chTheta >= 1.0)
    {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;

        return this;
    }

    var hTheta = Math.acos(chTheta);
    var shTheta = Math.sqrt(1.0 - chTheta * chTheta);

    if (Math.abs(shTheta) < 0.001)
    {
        this.x = 0.5 * (x + this.x);
        this.y = 0.5 * (y + this.y);
        this.z = 0.5 * (z + this.z);
        this.w = 0.5 * (w + this.w);
    }

    var rA = Math.sin((1.0 - a) * hTheta) / shTheta;
    var rB = Math.sin(a * hTheta) / shTheta;

    this.x = x * rA + this.x * rB;
    this.y = y * rA + this.y * rB;
    this.z = z * rA + this.z * rB;
    this.w = w * rA + this.w * rB;

    return this;
};


