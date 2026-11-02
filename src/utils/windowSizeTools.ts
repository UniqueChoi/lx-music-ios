import { Dimensions, StatusBar } from 'react-native'
import { getWindowSize as getWindowSizeRaw } from './nativeModules/utils'
// import { log } from './log'

export type SizeHandler = (size: { width: number, height: number }) => void
export const getWindowSize = async() => {
  return getWindowSizeRaw().then((size) => {
    const scale = Dimensions.get('window').scale
    size.width = size.width / scale
    size.height = size.height / scale
    return size
  })
}

export const windowSizeTools = {
  size: {
    width: 0,
    height: 0,
  },
  listeners: [] as SizeHandler[],
  getSize() {
    return this.size
  },
  onSizeChanged(handler: SizeHandler) {
    this.listeners.push(handler)

    return () => {
      this.listeners.splice(this.listeners.indexOf(handler), 1)
    }
  },
  async init() {
    // Dimensions.addEventListener('change', () => {
    //   void getWindowSize().then((size) => {
    //     if (!size.width) return
    //     const scale = Dimensions.get('screen').scale
    //     size.width = Math.round(size.width / scale)
    //     size.height = Math.round(size.height / scale) + (StatusBar.currentHeight ?? 0)
    //     this.size = size
    //     for (const handler of this.listeners) handler(size)
    //   })
    // })
    let size: { width: number, height: number } | null = null
    try {
      size = await getWindowSize()
    } catch {
      size = null
    }

    // 原生返回的值不可用时（0、NaN、负数）一律回退到 Dimensions。
    // 之前只判断 size.width，若原生返回 0 高或异常宽高比，
    // 会让 isHorizontalMode 误判成横屏，导致竖屏下也渲染出左侧导航栏。
    const isValid = size != null &&
      Number.isFinite(size.width) && Number.isFinite(size.height) &&
      size.width > 0 && size.height > 0

    if (isValid) {
      this.size = size!
    } else {
      const window = Dimensions.get('window')
      this.size = {
        width: Math.round(window.width),
        height: Math.round(window.height) + (StatusBar.currentHeight ?? 0),
      }
    }
    // console.log('init windowSizeTools')
    return this.size
  },
  setWindowSize(width: number, height: number) {
    this.size = {
      width: Math.round(width),
      height: Math.round(height),
    }
    for (const handler of this.listeners) handler(this.size)
  },
}
