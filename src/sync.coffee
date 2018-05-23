{S_IFMT, S_IFREG, S_IFDIR, S_IFLNK} = require('fs').constants
{lstatSync, readdirSync} = require 'fs'
errno = require './errno'
path = require 'path'
os = require 'os'

fs = exports

fs.list = (name) ->
  name = resolve name
  if !mode = getMode name
    uhoh "Path does not exist: '#{name}'", 'NOT_REAL'
  if mode isnt S_IFDIR
    uhoh "Path is not a directory: '#{name}'", 'NOT_DIR'
  readdirSync name

fs.isFile = (name) ->
  getMode(resolve(name)) is S_IFREG

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

# Expose error codes.
do ->
  def = Object.defineProperty
  des = {value: 0}
  for why of errno
    des.value = errno[why]
    def fs, why, des
  return
