import * as fs from 'fs'
import { ErrorCode } from './errno'

export type ReaderOptions = {
  flags?: string;
  encoding?: string;
  fd?: number;
  mode?: number;
  autoClose?: boolean;
  start?: number;
  end?: number;
  highWaterMark?: number;
}

export type WriterOptions = {
  flags?: string;
  encoding?: string;
  fd?: number;
  mode?: number;
  autoClose?: boolean;
  start?: number;
}

export type ReadStream = fs.ReadStream & { path: string }

export type WriteStream = fs.WriteStream & { path: string }

declare const saxon: {
  stat(name: string): Promise<fs.Stats>
  read(name: string, enc?: 'utf8'): Promise<string>
  read(name: string, enc: null): Promise<Buffer>
  read(name: string, enc: string): Promise<any>
  readJson<T = any>(name: string): Promise<T>
  list(name: string): Promise<string[]>
  reader(name: string, opts?: ReaderOptions): ReadStream
  follow(name: string, recursive?: boolean): Promise<string>
  exists(name: string): Promise<boolean>
  isFile(name: string): Promise<boolean>
  isDir(name: string): Promise<boolean>
  mkdir(name: string): Promise<void>
  write(name: string, content: string|Buffer): Promise<void>
  writer(name: string, opts?: WriterOptions): WriteStream
} & ErrorCode

export default saxon
