Pod::Spec.new do |s|
  s.name         = 'LxModules'
  s.version      = '1.0.0'
  s.summary      = 'LX Music 的 iOS 原生模块（替代 Android 侧同名 Java 模块）'
  s.description  = <<-DESC
    提供 UtilsModule / CryptoModule / CacheModule / UserApiModule 四个原生模块，
    接口与 android/app/src/main/java/cn/toside/music/mobile 下的同名 Java 实现保持一致，
    使 src/ 下的共享 JS 代码无需平台分支即可运行。

    其中 UserApiModule 用系统自带 JavaScriptCore 承载自定义源脚本，
    并复用 android/.../assets/script/user-api-preload.js（纯 JS，平台无关）。
  DESC
  s.homepage     = 'https://github.com/lyswhut/lx-music-mobile'
  s.license      = { :type => 'Apache-2.0' }
  s.author       = { 'LX Music' => 'noreply' }
  s.platforms    = { :ios => '13.4' }

  # 作为本地开发 pod 使用（Podfile 中以 :path 引入），source 字段不会被实际拉取，
  # 但 CocoaPods 要求它存在且是受支持的下载策略，故保留 git 形式占位
  s.source       = { :git => 'https://github.com/lyswhut/lx-music-mobile.git', :tag => s.version.to_s }

  s.source_files = 'ios/**/*.{h,m}'

  # 以独立资源包打包，避免与其他 pod 的同名文件冲突
  s.resource_bundles = {
    'LxModules' => ['Resources/*.js'],
  }

  s.frameworks   = 'UIKit', 'Security', 'UserNotifications', 'JavaScriptCore', 'AVFoundation'

  s.dependency 'React-Core'
end
