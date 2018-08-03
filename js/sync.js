// Generated by CoffeeScript 2.3.0
var S_IFDIR, S_IFLNK, S_IFMT, S_IFREG, errno, follow, fs, getMode, lstatSync, mkdirSync, os, path, readFileSync, readdirSync, readlinkSync, removeTree, renameSync, resolve, rmdirSync, statSync, symlinkSync, uhoh, unlinkSync, writeFileSync;

({lstatSync, mkdirSync, readdirSync, readlinkSync, readFileSync, renameSync, rmdirSync, statSync, symlinkSync, unlinkSync, writeFileSync} = require('fs'));

({S_IFMT, S_IFREG, S_IFDIR, S_IFLNK} = require('fs').constants);

errno = require('./errno');

path = require('path');

os = require('os');

fs = exports;

fs.stat = function(name) {
  return statSync(resolve(name));
};

fs.read = function(name, enc) {
  var mode;
  name = resolve(name);
  if (!(mode = getMode(name))) {
    uhoh(`Path does not exist: '${name}'`, 'NOT_REAL');
  }
  if (mode === S_IFDIR) {
    uhoh(`Path is not readable: '${name}'`, 'NOT_FILE');
  }
  if (enc === void 0) {
    enc = "utf8";
  }
  return readFileSync(name, enc);
};

fs.list = function(name) {
  var mode;
  name = resolve(name);
  if (!(mode = getMode(name))) {
    uhoh(`Path does not exist: '${name}'`, 'NOT_REAL');
  }
  if (mode !== S_IFDIR) {
    uhoh(`Path is not a directory: '${name}'`, 'NOT_DIR');
  }
  return readdirSync(name);
};

fs.follow = function(name, recursive) {
  var mode;
  name = resolve(name);
  if (!(mode = getMode(name))) {
    uhoh(`Path does not exist: '${name}'`, 'NOT_REAL');
  }
  if (mode === S_IFLNK) {
    return follow(name, recursive);
  } else {
    return name;
  }
};

fs.exists = function(name) {
  return getMode(resolve(name)) !== null;
};

fs.isFile = function(name) {
  return getMode(resolve(name)) === S_IFREG;
};

fs.isDir = function(name) {
  return getMode(resolve(name)) === S_IFDIR;
};

fs.rename = function(src, dest) {
  var mode;
  src = resolve(src);
  if (!(mode = getMode(src))) {
    uhoh(`Path does not exist: '${src}'`, 'NOT_REAL');
  }
  dest = resolve(dest);
  if (getMode(dest)) {
    uhoh(`Path already exists: '${dest}'`, 'PATH_EXISTS');
  }
  fs.mkdir(path.dirname(dest));
  return renameSync(src, dest);
};

fs.link = function(name, target) {
  name = resolve(name);
  if (getMode(name) === null) {
    return symlinkSync(name, target);
  }
  return uhoh(`Path already exists: '${name}'`, 'PATH_EXISTS');
};

fs.write = function(name, content) {
  name = resolve(name);
  if (getMode(name) !== S_IFDIR) {
    return writeFileSync(name, content);
  }
  return uhoh(`Path is a directory: '${name}'`, 'NOT_FILE');
};

fs.mkdir = function(name) {
  var mode;
  name = resolve(name);
  if (!(mode = getMode(name))) {
    fs.mkdir(path.dirname(name));
    return mkdirSync(name);
  }
  // no-op if the directory already exists
  if (mode !== S_IFDIR) {
    return uhoh(`Path already exists: '${name}'`, 'PATH_EXISTS');
  }
};

fs.remove = function(name, recursive) {
  var mode;
  name = resolve(name);
  if (mode = getMode(name)) {
    if (mode === S_IFDIR) {
      if (recursive) {
        return removeTree(name);
      } else {
        return rmdirSync(name);
      }
    } else {
      return unlinkSync(name);
    }
  }
};


// Internal

uhoh = function(msg, why) {
  var err;
  err = Error(msg);
  err.code = errno[why] || 0;
  Error.captureStackTrace(err, uhoh);
  throw err;
};

resolve = function(name) {
  if (name[0] === '~') {
    return os.homedir() + name.slice(1);
  } else {
    return path.resolve(name);
  }
};

getMode = function(name) {
  var e;
  try {
    return lstatSync(name).mode & S_IFMT;
  } catch (error) {
    e = error;
    return null;
  }
};

// Recursive symlink resolution
follow = function(link, recursive) {
  var mode, name, prev, reads, validate;
  name = link;
  reads = 0;
  if (typeof recursive === 'function') {
    validate = recursive;
    recursive = true;
  }
  while (++reads) {
    prev = name;
    name = readlinkSync(prev);
    if (!path.isAbsolute(name)) {
      name = path.resolve(path.dirname(prev), name);
    }
    if (validate && !validate(name)) {
      return prev;
    }
    if (!recursive) {
      return name;
    }
    if (!(mode = getMode(name))) {
      uhoh(`Symlink leads nowhere: '${link}'`, 'NOT_REAL');
    }
    if (mode !== S_IFLNK) {
      return name;
    }
    if (reads === 10) {
      uhoh(`Too many symlinks: '${link}'`, 'LINK_LIMIT');
    }
  }
};

// Recursive tree deletion.
removeTree = function(name) {
  var child, i, len, ref;
  ref = readdirSync(name);
  for (i = 0, len = ref.length; i < len; i++) {
    child = ref[i];
    child = path.join(name, child);
    if (getMode(child) === S_IFDIR) {
      removeTree(child);
    } else {
      unlinkSync(child);
    }
  }
  return rmdirSync(name);
};

(function() {  // Expose error codes.
  var def, des, why;
  def = Object.defineProperty;
  des = {
    value: 0
  };
  for (why in errno) {
    des.value = errno[why];
    def(fs, why, des);
  }
})();
