import { getPlayInfo } from '@/utils/data'
import { getListMusics } from '@/core/list'
import { playList, play } from '@/core/player/player'
import { Platform } from 'react-native'


export default async(setting: LX.AppSetting) => {
  // iOS 上跳过「恢复上次播放」：
  // 该逻辑只在第二次及以后的启动才有数据（第一次启动 AsyncStorage 为空），
  // 而 iOS 端在恢复时通过 playList -> TrackPlayer.add 触发原生层异常
  // （-[__NSArrayM objectAtIndexedSubscript:]: index 3 beyond bounds [0 .. 2]），
  // 导致 App 第二次启动即崩溃且无法进入。
  // 跳过恢复不影响播放功能，只是每次启动后从空播放列表开始。
  if (Platform.OS === 'ios') {
    global.lx.restorePlayInfo = null
    return
  }

  const info = await getPlayInfo()
  global.lx.restorePlayInfo = null
  if (!info?.listId || info.index < 0) return

  const list = await getListMusics(info.listId)
  if (!list[info.index]) return
  global.lx.restorePlayInfo = info

  await playList(info.listId, info.index)

  if (setting['player.startupAutoPlay']) setTimeout(play)


  // if (!info.list || !info.list[info.index]) {
  //   const info2 = { ...info }
  //   if (info2.list) {
  //     info2.music = info2.list[info2.index]?.name
  //     info2.list = info2.list.length
  //   }
  //   toast('恢复播放数据失败，请去错误日志查看', 'long')
  //   log.warn('Restore Play Info failed: ', JSON.stringify(info2, null, 2))

  //   return
  // }

  // let setting = store.getState().common.setting
  // global.restorePlayInfo = {
  //   info,
  //   startupAutoPlay: setting.startupAutoPlay,
  // }

  // store.dispatch(playerAction.setList({
  //   list: {
  //     list: info.list,
  //     id: info.listId,
  //   },
  //   index: info.index,
  // }))
}
