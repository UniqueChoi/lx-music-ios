import { forwardRef, useImperativeHandle, useMemo, useState } from 'react'
import { Platform } from 'react-native'

import Basic from './settings/Basic'
import Player from './settings/Player'
import LyricDesktop from './settings/LyricDesktop'
import Search from './settings/Search'
import List from './settings/List'
import Sync from './settings/Sync'
import Backup from './settings/Backup'
import Other from './settings/Other'
import Version from './settings/Version'
import About from './settings/About'

const ALL_SETTING_SCREENS = [
  'basic',
  'player',
  'lyric_desktop',
  'search',
  'list',
  'sync',
  'backup',
  'other',
  'version',
  'about',
] as const

export type SettingScreenIds = typeof ALL_SETTING_SCREENS[number]

// iOS 不支持第三方 App 创建全局悬浮窗，桌面歌词无法实现，
// 因此在 iOS 上直接隐藏该项，而不是给一个点了没反应的开关。
const HIDDEN_ON_IOS: SettingScreenIds[] = ['lyric_desktop']

export const SETTING_SCREENS: SettingScreenIds[] = Platform.OS === 'ios'
  ? ALL_SETTING_SCREENS.filter(id => !HIDDEN_ON_IOS.includes(id))
  : [...ALL_SETTING_SCREENS]

// interface MainProps {
//   onUpdateActiveId: (id: string) => void
// }
export interface MainType {
  setActiveId: (id: SettingScreenIds) => void
}

const Main = forwardRef<MainType, {}>((props, ref) => {
  const [id, setId] = useState(global.lx.settingActiveId)

  useImperativeHandle(ref, () => ({
    setActiveId(id) {
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          setId(id)
        })
      })
    },
  }))

  const component = useMemo(() => {
    // 兜底：若历史数据把 activeId 记为当前平台不支持的项（例如从 Android 迁移），
    // 则回落到「基本设置」，避免渲染出一个无法使用的页面。
    const activeId = (SETTING_SCREENS as string[]).includes(id) ? id : 'basic'
    switch (activeId) {
      case 'player': return <Player />
      case 'lyric_desktop': return <LyricDesktop />
      case 'search': return <Search />
      case 'list': return <List />
      case 'sync': return <Sync />
      case 'backup': return <Backup />
      case 'other': return <Other />
      case 'version': return <Version />
      case 'about': return <About />
      case 'basic':
      default: return <Basic />
    }
  }, [id])

  return component
})


export default Main

