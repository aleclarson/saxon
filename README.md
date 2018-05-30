# saxon v0.1.1

Modern filesystem library.

- Paths are relative to the working directory (if not absolute)
- Paths starting with `~/` are resolved relative to `os.homedir()`
- Error codes are exposed to the user (eg: `fs.NOT_REAL`)
- Functions available in both APIs behave identically

🚧 *Under construction*

```js
const fs = require('saxon');
```

- `read(name, enc)` Read an entire file into memory
- `follow(name, recursive)` Resolve a symlink
- `isFile(name)`
- `isDir(name)`
- `mkdir(name)` Create a directory
- `writer(name, opts)` Create a writable stream

The `read` function takes a path or file descriptor as its first argument.
The data encoding defaults to `"utf8"`.
Pass a string as the second argument to customize the encoding.
For a buffer object, you must pass `null` as the encoding.

The `follow` function does *not* throw when the given path is not a symlink.
Pass `true` as the second argument to automatically follow a chain of symlinks until a file or directory is found.
Pass a function as the second argument to be called for every resolved path. Your function must return a boolean, where `false` forces the result to be the previous path.
It throws a `LINK_LIMIT` error if the real path cannot be resolved within 10 reads.
It throws a `NOT_REAL` error if a resolved path does not exist.

The `mkdir` function recursively creates any missing parent directories.
It throws a `PATH_EXISTS` error if the path (or one of its parents) already exists and isn't a directory.

The `writer` function creates a `WriteStream` object.
Pass a number as the first argument to use a file descriptor.

## Blocking API

```js
const fs = require('saxon/sync');
```

- `read(name, enc)` Read an entire file into memory
- `list(name)` Get the array of paths in a directory
- `follow(name, recursive)` Resolve a symlink
- `exists(name)`
- `isFile(name)`
- `isDir(name)`
- `write(name, content)` Create or update a file
- `mkdir(name)` Create a directory
- `remove(name, recursive)` Destroy a path

The `list` function throws a `NOT_REAL` error if the given path does not exist.
It throws a `NOT_DIR` error if the given path is not a directory.

The `remove` function unlinks a file, symlink, or empty directory.
Pass `true` as the second argument to unlink non-empty directories.
