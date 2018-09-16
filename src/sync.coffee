{chmodSync, lstatSync, mkdirSync, readdirSync, readlinkSync, readFileSync, renameSync, rmdirSync, statSync, symlinkSync, unlinkSync, utimesSync, writeFileSync} = require 'fs'
{S_IFMT, S_IFREG, S_IFDIR, S_IFLNK} = require('fs').constants
errno = require './errno'
path = require 'path'
os = require 'os'

fs = exports

fs.stat = (name) ->
  statSync(resolve name)

fs.read = (name, enc) ->
  name = resolve name
  if !mode = getMode name
    uhoh "Path does not exist: '#{name}'", 'NOT_REAL'
  if mode is S_IFDIR
    uhoh "Path is not readable: '#{name}'", 'NOT_FILE'
  enc = "utf8" if enc is undefined
  readFileSync name, enc

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

fs.touch = (name) ->
  name = resolve name
  if getMode(name) is null
    return writeFileSync name, ''
  time = Date.now() / 1000
  return utimesSync name, time, time

fs.chmod = (name, mode) ->
  name = resolve name
  if !mode = getMode name
    uhoh "Path does not exist: '#{name}'", 'NOT_REAL'
  if mode is S_IFDIR
    uhoh "Path is a directory: '#{name}'", 'NOT_FILE'
  return chmodSync name, mode

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
  # no-op if the directory already exists
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
