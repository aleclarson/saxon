{chmodSync, lstatSync, mkdirSync, readdirSync, readlinkSync, readFileSync, renameSync, rmdirSync, statSync, symlinkSync, unlinkSync, utimesSync, writeFileSync} = require 'fs'
{S_IFMT, S_IFREG, S_IFDIR, S_IFLNK} = require('fs').constants
errno = require './errno'
path = require 'path'
os = require 'os'

fs = exports

fs.stat = (name) ->
  statSync(resolve name)

fs.lstat = (name) ->
  lstatSync(resolve name)

fs.read = (name, enc) ->
  name = resolve name
  if !mode = getMode name
    uhoh "Path does not exist: '#{name}'", 'NOT_REAL'
  if mode is S_IFDIR
    uhoh "Path is not readable: '#{name}'", 'NOT_FILE'
  enc = "utf8" if enc is undefined
  readFileSync name, enc

fs.readJson = (name) ->
  JSON.parse fs.read name

fs.list = (name) ->
  name = resolve name
  if !mode = getMode name
    uhoh "Path does not exist: '#{name}'", 'NOT_REAL'
  if mode isnt S_IFDIR
    uhoh "Path is not a directory: '#{name}'", 'NOT_DIR'
  readdirSync name

fs.follow = (name, recursive) ->
  name = resolve name
  if !mode = getMode name
    uhoh "Path does not exist: '#{name}'", 'NOT_REAL'
  if mode is S_IFLNK
    follow name, recursive
  else name

fs.exists = (name) ->
  getMode(resolve name) isnt null

fs.isFile = (name) ->
  getMode(resolve name) is S_IFREG

fs.isDir = (name) ->
  getMode(resolve name) is S_IFDIR

fs.isLink = (name) ->
  getMode(resolve name) is S_IFLNK

fs.readPerms = (name) ->
  '0' + (fs.stat(name).mode & parseInt('777', 8)).toString(8)

fs.touch = (name) ->
  name = resolve name
  if getMode(name) is null
    return writeFileSync name, ''
  time = Date.now() / 1000
  return utimesSync name, time, time

fs.chmod = (name, value) ->
  name = resolve name
  if !mode = getMode name
    uhoh "Path does not exist: '#{name}'", 'NOT_REAL'
  if mode is S_IFDIR
    uhoh "Path is a directory: '#{name}'", 'NOT_FILE'
  return chmodSync name, value

fs.link = (name, target) ->
  name = resolve name
  if getMode(name) is null
    return symlinkSync target, name
  uhoh "Path already exists: '#{name}'", 'PATH_EXISTS'

fs.write = (name, content) ->
  name = resolve name
  if getMode(name) isnt S_IFDIR
    return writeFileSync name, content
  uhoh "Path is a directory: '#{name}'", 'NOT_FILE'

fs.mkdir = (name) ->
  name = resolve name

  if !mode = getMode name
    fs.mkdir path.dirname name
    return mkdirSync name

  if mode is S_IFLNK
    mode = getMode follow name, true

  if mode isnt S_IFDIR
    uhoh "Path already exists: '#{name}'", 'PATH_EXISTS'

fs.rename = (src, dest) ->
  src = resolve src
  if !mode = getMode src
    uhoh "Path does not exist: '#{src}'", 'NOT_REAL'

  dest = resolve dest
  if getMode dest
    uhoh "Path already exists: '#{dest}'", 'PATH_EXISTS'

  fs.mkdir path.dirname dest
  renameSync src, dest

fs.remove = (name, recursive) ->
  name = resolve name
  if mode = getMode name
    if mode is S_IFDIR
      if recursive
        removeTree name
      else rmdirSync name
    else unlinkSync name

fs.copy = (srcPath, destPath) ->
  srcPath = resolve srcPath
  destPath = resolve destPath

  unless mode = getMode srcPath
    uhoh "Cannot `copy` non-existent path: '#{srcPath}'", 'NOT_REAL'

  if mode is S_IFDIR
    return copyTree srcPath, destPath

  destMode = getMode destPath

  if destMode is S_IFDIR
    destPath = path.join destPath, path.basename srcPath
    destMode = getMode destPath

  if destMode
    if destMode is S_IFDIR
    then uhoh "Cannot overwrite directory path: '#{destPath}'", 'PATH_EXISTS'
    else unlinkSync destPath

  copyFile srcPath, destPath

#
# Internal
#

uhoh = (msg, why) ->
  err = Error msg
  err.code = errno[why] or 0
  Error.captureStackTrace err, uhoh
  throw err

resolve = (name) ->
  if name[0] is '~'
    os.homedir() + name.slice(1)
  else path.resolve name

getMode = (name) ->
  try lstatSync(name).mode & S_IFMT
  catch e then null

# Recursive symlink resolution
follow = (link, recursive) ->
  name = link
  reads = 0

  if typeof recursive is 'function'
    validate = recursive
    recursive = true

  while ++reads
    prev = name
    name = readlinkSync prev

    if !path.isAbsolute name
      name = path.resolve path.dirname(prev), name

    if validate and !validate name
      return prev

    if !recursive
      return name

    if !mode = getMode name
      uhoh "Symlink leads nowhere: '#{link}'", 'NOT_REAL'

    if mode isnt S_IFLNK
      return name

    if reads is 10
      uhoh "Too many symlinks: '#{link}'", 'LINK_LIMIT'

copyFile = (srcPath, destPath) ->
  fs.mkdir path.dirname destPath
  if mode is S_IFLNK
    return symlinkSync readlinkSync(srcPath), destPath
  writeFileSync destPath, readFileSync srcPath
  chmodSync destPath, fs.readPerms srcPath

# Recursive tree copies.
copyTree = (srcDir, destDir) ->
  destMode = getMode destDir

  # Remove the file under our new path, if needed.
  if destMode and destMode isnt S_IFDIR
    unlinkSync destDir

  # Create the directory, if needed.
  if destMode isnt S_IFDIR
    fs.mkdir destDir

  readdirSync(srcDir).forEach (file) ->
    srcPath = path.join srcDir, file
    destPath = path.join destDir, file

    if getMode(srcPath) is S_IFDIR
      return copyTree srcPath, destPath

    if destMode = getMode destPath
      if destMode is S_IFDIR
      then removeTree destPath
      else unlinkSync destPath

    copyFile srcPath, destPath

# Recursive tree deletion.
removeTree = (name) ->
  for child in readdirSync name
    child = path.join name, child
    if getMode(child) is S_IFDIR
      removeTree child
    else unlinkSync child
  rmdirSync name

# Expose error codes.
do ->
  def = Object.defineProperty
  des = {value: 0}
  for why of errno
    des.value = errno[why]
    def fs, why, des
  return
