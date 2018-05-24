{lstatSync, readdirSync, readlinkSync, readFileSync} = require 'fs'
{S_IFMT, S_IFREG, S_IFDIR, S_IFLNK} = require('fs').constants
errno = require './errno'
path = require 'path'
os = require 'os'

fs = exports

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
  getMode(resolve name) isnt undefined

fs.isFile = (name) ->
  getMode(resolve name) is S_IFREG

fs.isDir = (name) ->
  getMode(resolve name) is S_IFDIR

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

# Expose error codes.
do ->
  def = Object.defineProperty
  des = {value: 0}
  for why of errno
    des.value = errno[why]
    def fs, why, des
  return
