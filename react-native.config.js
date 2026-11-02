/**
 * react-native 自动链接配置。
 *
 * react-native-file-system 与 react-native-local-media-metadata 是 lyswhut 的 fork，
 * 其仓库只包含 android/ 源码（podspec 里写的 ios/**\/*.{h,m,mm} 为空 glob，不会报错）。
 * 在 iOS 上链接它们是无效的，且会掩盖"编译通过、运行崩溃"的问题，故显式关闭 iOS 平台。
 *
 * iOS 侧对应能力由以下文件接管：
 *   src/utils/fs.ios.ts
 *   src/utils/localMediaMetadata.ios.ts
 */
module.exports = {
  dependencies: {
    'react-native-file-system': {
      platforms: {
        ios: null,
      },
    },
    'react-native-local-media-metadata': {
      platforms: {
        ios: null,
      },
    },
  },
}
