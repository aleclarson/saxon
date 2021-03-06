{lstat, mkdir, readdir, readlink, readFile, ReadStream, stat, writeFile, WriteStream} = require 'graceful-fs'
{S_IFMT, S_IFREG, S_IFDIR, S_IFLNK} = require('fs').constants
errno = require './errno'
path = require 'path'
os = require 'os'

fs = exports

fs.stat = (name) ->
  defer stat, resolve(name)

fs.read = (name, enc) ->
  name = resolve name
  if !mode = await getMode name
    uhoh "Path does not exist: '#{name}'", 'NOT_REAL'
  if mode is S_IFDIR
    uhoh "Path is not readable: '#{name}'", 'NOT_FILE'
  enc = "utf8" if enc is undefined
  defer readFile, name, enc

fs.readJson = (name) ->
  JSON.parse await fs.read name

fs.list = (name) ->
  name = resolve name
  if !mode = await getMode name
    uhoh "Path does not exist: '#{name}'", 'NOT_REAL'
  if mode isnt S_IFDIR
    uhoh "Path is not a directory: '#{name}'", 'NOT_DIR'
  defer readdir, name

fs.follow = (name, recursive) ->
  name = resolve name
  if !mode = await getMode name
    uhoh "Path does not exist: '#{name}'", 'NOT_REAL'
  if mode is S_IFLNK
    follow name, recursive
  else Promise.resolve name

fs.exists = (name) ->
  (await getMode resolve name) isnt null

fs.isFile = (name) ->
  (await getMode resolve name) is S_IFREG

fs.isDir = (name) ->
  (await getMode resolve name) is S_IFDIR

fs.write = (name, content) ->
  name = resolve name
  if (await getMode name) isnt S_IFDIR
    return defer writeFile, name, content
  uhoh "Path is a directory: '#{name}'", 'NOT_FILE'

fs.mkdir = (name) ->
  name = resolve name
  if !mode = await getMode name
    await fs.mkdir path.dirname(name)
    return defer mkdir, name
  # no-op if the directory already exists
  if mode isnt S_IFDIR
    uhoh "Path already exists: '#{name}'", 'PATH_EXISTS'

fs.reader = (name, opts) ->
  stream ReadStream, name, opts

fs.writer = (name, opts) ->
  stream WriteStream, name, opts

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
  try (await defer lstat, name).mode & S_IFMT
  catch e then null

defer = (callee, $1, $2) ->
  n = arguments.length - 1
  new Promise (resolve, reject) ->
    done = (err, data) ->
      if err then reject err
      else resolve data
    switch n
      when 0 then callee done
      when 1 then callee $1, done
      when 2 then callee $1, $2, done

# Recursive symlink resolution
follow = (link, recursive) ->
  new Promise (resolve, reject) ->
    prev = link; reads = 1
    if typeof recursive is 'function'
      validate = recursive
      recursive = true
    readlink link, next = (err, name) ->
      return reject err if err
      if !path.isAbsolute name
        name = path.resolve path.dirname(prev), name
      if validate and !(await validate name)
        resolve prev
      else if !recursive
        resolve name
      else if !mode = await getMode name
        err = Error "Symlink leads nowhere: '#{link}'"
        err.code = errno.NOT_REAL
        reject err
      else if mode isnt S_IFLNK
        resolve name
      else if reads isnt 10
        prev = name; reads++
        readlink name, next
      else
        err = Error "Too many symlinks: '#{link}'"
        err.code = errno.LINK_LIMIT
        reject err

stream = (ctr, name, opts) ->
  if typeof name is 'number'
    opts and opts.fd = name
    new ctr null, opts or fd: name
  else new ctr resolve(name), opts

# Expose error codes.
do ->
  def = Object.defineProperty
  des = {value: 0}
  for why of errno
    des.value = errno[why]
    def fs, why, des
  return
