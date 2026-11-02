/**
 * iOS 文件系统实现。
 *
 * 背景：Android 版依赖 react-native-file-system（lyswhut fork），该依赖**没有 iOS 源码**。
 * 本文件在 iOS 上用 react-native-fs + pako 复刻同名 API，保证上层 20+ 处调用无需改动。
 *
 * 平台差异：
 *  - iOS 无外置存储/SD 卡概念，externalStorageDirectoryPath 退化为沙盒 Documents
 *  - 无 SAF（Android Scoped Storage），选目录/选文件相关 API 需降级（P3 用 UIDocumentPicker 实现）
 */
import RNFS from 'react-native-fs'
import pako from 'pako'
import { Buffer } from '@craftzdog/react-native-buffer'
import type { Encoding, HashAlgorithm, OpenDocumentOptions } from 'react-native-file-system'

export type { FileType } from 'react-native-file-system'

export const extname = (name: string) => name.lastIndexOf('.') > 0 ? name.substring(name.lastIndexOf('.') + 1) : ''

// iOS 沙盒：缓存目录可被系统清理，Documents 目录会随 iCloud 备份
export const temporaryDirectoryPath = RNFS.CachesDirectoryPath
export const privateStorageDirectoryPath = RNFS.DocumentDirectoryPath
export const externalStorageDirectoryPath = RNFS.DocumentDirectoryPath

// iOS 没有可枚举的外置存储，返回空数组即可让「选择存储位置」UI 自然降级
export const getExternalStoragePaths = async(_isRemovable?: boolean): Promise<Array<{ path: string, isRemovable: boolean, isExternal: boolean }>> => []

// ---- Android SAF 对应能力：iOS 上不可用，调用时给出明确错误而不是静默失败 ----
const notSupported = (name: string): never => {
  throw new Error(`[iOS] ${name} 在 iOS 上不可用（Android Scoped Storage API），请改用 Files App 导入`)
}

export const selectManagedFolder = async(_isPersist: boolean = false): Promise<string> => notSupported('selectManagedFolder')
export const selectFile = async(_options?: OpenDocumentOptions): Promise<string> => notSupported('selectFile')
export const removeManagedFolder = async(_path: string): Promise<void> => notSupported('removeManagedFolder')
export const getManagedFolders = async(): Promise<Array<{ path: string, name: string }>> => []
export const getPersistedUriList = async(): Promise<string[]> => []

// ---- 基础文件操作 ----
export const readDir = async(path: string) => RNFS.readDir(path)

export const unlink = async(path: string) => {
  if (await RNFS.exists(path)) await RNFS.unlink(path)
}

export const mkdir = async(path: string) => RNFS.mkdir(path)

export const stat = async(path: string) => RNFS.stat(path)

export const hash = async(path: string, algorithm: HashAlgorithm) => RNFS.hash(path, algorithm)

export const readFile = async(path: string, encoding: Encoding = 'utf8') => RNFS.readFile(path, encoding as 'utf8')

export const moveFile = async(fromPath: string, toPath: string) => RNFS.moveFile(fromPath, toPath)

export const existsFile = async(path: string) => RNFS.exists(path)

export const rename = async(path: string, name: string) => RNFS.moveFile(path, `${path.substring(0, path.lastIndexOf('/'))}/${name}`)

export const writeFile = async(path: string, data: string, encoding: Encoding = 'utf8') => RNFS.writeFile(path, data, encoding as 'utf8')

export const appendFile = async(path: string, data: string, encoding: Encoding = 'utf8') => RNFS.appendFile(path, data, encoding as 'utf8')

// ---- gzip：Android 走原生 zlib，iOS 用 pako（纯 JS，已在依赖中）----
// 注：pako 2.x 的 gzip/ungzip 直接返回 Uint8Array，不再支持 1.x 的 { to: 'base64' } 选项，
// 因此这里统一用 Buffer 做 base64 编解码，避免依赖 pako 的类型版本差异。
const toBase64 = (data: Uint8Array): string => Buffer.from(data).toString('base64')
const fromBase64 = (data: string): Uint8Array => new Uint8Array(Buffer.from(data, 'base64'))

export const gzipString = async(data: string, _encoding?: Encoding): Promise<string> => {
  return toBase64(pako.gzip(data))
}

export const unGzipString = async(data: string, _encoding?: Encoding): Promise<string> => {
  return Buffer.from(pako.ungzip(fromBase64(data))).toString('utf8')
}

export const gzipFile = async(fromPath: string, toPath: string): Promise<void> => {
  const raw = fromBase64(await RNFS.readFile(fromPath, 'base64'))
  await RNFS.writeFile(toPath, toBase64(pako.gzip(raw)), 'base64')
}

export const unGzipFile = async(fromPath: string, toPath: string): Promise<void> => {
  const compressed = fromBase64(await RNFS.readFile(fromPath, 'base64'))
  await RNFS.writeFile(toPath, toBase64(pako.ungzip(compressed)), 'base64')
}

// ---- 下载：react-native-fs 原生支持 iOS ----
export const downloadFile = (url: string, path: string, options: Omit<RNFS.DownloadFileOptions, 'fromUrl' | 'toFile'> = {}) => {
  if (!options.headers) {
    options.headers = {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    }
  }
  return RNFS.downloadFile({
    fromUrl: url,
    toFile: path,
    ...options,
  })
}

export const stopDownload = (jobId: number) => {
  RNFS.stopDownload(jobId)
}
