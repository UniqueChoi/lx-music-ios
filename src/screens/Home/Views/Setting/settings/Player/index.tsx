import { memo } from 'react'
import { Platform } from 'react-native'

import Section from '../../components/Section'
import IsSavePlayTime from './IsSavePlayTime'
import PlayHighQuality from './PlayHighQuality'
import IsHandleAudioFocus from './IsHandleAudioFocus'
import IsEnableAudioOffload from './IsEnableAudioOffload'
import IsAutoCleanPlayedList from './IsAutoCleanPlayedList'
import IsShowBluetoothLyric from './IsShowBluetoothLyric'
import IsShowBluetoothFullLyric from './IsShowBluetoothFullLyric'
import IsShowNotificationImage from './IsShowNotificationImage'
import IsShowLyricTranslation from './IsShowLyricTranslation'
import IsShowLyricRoma from './IsShowLyricRoma'
import IsS2T from './IsS2T'
import MaxCache from './MaxCache'
import { useI18n } from '@/lang'


// iOS 上隐藏的设置项，原因都写在对应注释里
const isIOS = Platform.OS === 'ios'

export default memo(() => {
  const t = useI18n()

  return (
    <Section title={t('setting_player')}>
      <IsSavePlayTime />
      <IsAutoCleanPlayedList />
      {/* 音频焦点由 iOS 的 AVAudioSession 自动处理，无对应开关 */}
      {!isIOS && <IsHandleAudioFocus />}
      {/* audioOffload 是 Android ExoPlayer 的省电特性 */}
      {!isIOS && <IsEnableAudioOffload />}
      {/* 蓝牙歌词依赖 Android 的蓝牙 AVRCP 广播，iOS 无对应能力 */}
      {!isIOS && <IsShowBluetoothLyric />}
      {!isIOS && <IsShowBluetoothFullLyric />}
      <IsShowNotificationImage />
      <IsShowLyricTranslation />
      <IsShowLyricRoma />
      <IsS2T />
      {/* 播放缓存大小是 ExoPlayer 专有概念，iOS 由系统 NSURLCache 管理 */}
      {!isIOS && <MaxCache />}
      <PlayHighQuality />
    </Section>
  )
})
