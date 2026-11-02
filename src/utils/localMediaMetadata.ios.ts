/**
 * iOS 本地音乐元数据实现。
 *
 * 背景：Android 版依赖 react-native-local-media-metadata（lyswhut fork），
 * 该依赖**没有 iOS 源码**，直接调用会在运行期抛 undefined。
 *
 * iOS 侧由原生模块 LxMediaMetadata（AVFoundation）提供同名能力：
 *   - readMetadata：读时长 / 标题 / 艺术家 / 专辑 / 码率
 *   - readPic：把封面导出到缓存目录并返回路径
 *   - readLyric：优先读同名 .lrc，其次读内嵌歌词
 *   - writeMetadata / writePic：iOS 暂不支持写回标签，会 reject
 *   - writeLyric：写同名 .lrc 文件
 */
import { NativeModules } from 'react-native'
import { temporaryDirectoryPath, readDir, unlink, extname } from '@/utils/fs'

export type {
  MusicMetadata,
  MusicMetadataFull,
} from 'react-native-local-media-metadata'

const { LocalMediaModule } = NativeModules

if (LocalMediaModule == null) {
  console.warn('[iOS] LocalMediaModule 未注册，本地音乐元数据将不可用')
}

export const readMetadata = async(filePath: string): Promise<any> => {
  if (LocalMediaModule?.readMetadata == null) return null
  return LocalMediaModule.readMetadata(filePath).catch(() => null)
}

export const writeMetadata = async(filePath: string, metadata: any, isOverwrite?: boolean): Promise<void> => {
  if (LocalMediaModule?.writeMetadata == null) throw new Error('[iOS] writeMetadata 不可用')
  return LocalMediaModule.writeMetadata(filePath, metadata, isOverwrite ?? true)
}

let cleared = false
const picCachePath = temporaryDirectoryPath + '/local-media-metadata'

const clearPicCache = async() => {
  await unlink(picCachePath)
  cleared = true
}

export const readPic = async(filePath: string): Promise<string> => {
  if (LocalMediaModule?.readPic == null) return ''
  if (!cleared) await clearPicCache()
  // 原生返回绝对路径，JS 侧统一补 file:// 前缀（与 Android 行为一致）
  const path = await LocalMediaModule.readPic(filePath, picCachePath).catch(() => '')
  if (!path) return ''
  return path.startsWith('/') ? `file://${path}` : path
}

export const writePic = async(filePath: string, picPath: string): Promise<void> => {
  if (LocalMediaModule?.writePic == null) throw new Error('[iOS] writePic 不可用')
  return LocalMediaModule.writePic(filePath, picPath)
}

export const readLyric = async(filePath: string, isReadLrcFile: boolean = true): Promise<string> => {
  if (LocalMediaModule?.readLyric == null) return ''
  return LocalMediaModule.readLyric(filePath, isReadLrcFile).catch(() => '')
}

export const writeLyric = async(filePath: string, lyric: string): Promise<void> => {
  if (LocalMediaModule?.writeLyric == null) throw new Error('[iOS] writeLyric 不可用')
  return LocalMediaModule.writeLyric(filePath, lyric)
}

export const scanAudioFiles = async(dirPath: string) => {
  const files = await readDir(dirPath)
  return files.filter(file => {
    if (file.mimeType?.startsWith('audio/')) return true
    if (extname(file?.name ?? '') === 'ogg') return true
    return false
  }).map(file => file)
}
