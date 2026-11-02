import { memo } from 'react'
import { Platform } from 'react-native'

import Theme from '../Theme'
import Section from '../../components/Section'
import Source from './Source'
import SourceName from './SourceName'
import Language from './Language'
import FontSize from './FontSize'
import ShareType from './ShareType'
import IsStartupAutoPlay from './IsStartupAutoPlay'
import IsStartupPushPlayDetailScreen from './IsStartupPushPlayDetailScreen'
import IsAutoHidePlayBar from './IsAutoHidePlayBar'
import IsHomePageScroll from './IsHomePageScroll'
import IsAllowProgressBarSeek from './IsAllowProgressBarSeek'
import IsUseSystemFileSelector from './IsUseSystemFileSelector'
import IsAlwaysKeepStatusbarHeight from './IsAlwaysKeepStatusbarHeight'
import IsShowBackBtn from './IsShowBackBtn'
import IsShowExitBtn from './IsShowExitBtn'
import DrawerLayoutPosition from './DrawerLayoutPosition'
import { useI18n } from '@/lang/i18n'

const isIOS = Platform.OS === 'ios'

export default memo(() => {
  const t = useI18n()


  return (
    <Section title={t('setting_basic')}>
      <IsStartupAutoPlay />
      <IsStartupPushPlayDetailScreen />
      <IsShowBackBtn />
      {/* iOS 不允许 App 主动退出，该开关无意义 */}
      {!isIOS && <IsShowExitBtn />}
      <IsAutoHidePlayBar />
      <IsHomePageScroll />
      <IsAllowProgressBarSeek />
      {/* 「使用系统文件选择器」对应 Android 的 SAF，iOS 始终走系统文档选择器 */}
      {!isIOS && <IsUseSystemFileSelector />}
      <IsAlwaysKeepStatusbarHeight />
      <Theme />
      <DrawerLayoutPosition />
      <Language />
      <FontSize />
      <ShareType />
      <Source />
      <SourceName />
    </Section>
  )
})
