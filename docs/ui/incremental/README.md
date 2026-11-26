# 新功能 UI 验收证据

这些图片由 `test/new_features_ui_test.dart` 渲染实际 Flutter 页面/对话框生成，
**是 Widget 渲染证据，不是真机或原生应用截图**。截图模式加载 SDK Roboto，
并使用本机 Arial Unicode 作为 CJK 回退字体；没有重新绘制或模拟界面。

覆盖宽度 320、360、411、720、1024；中英文；跟随系统的明亮/深色；
自定义黄色/紫色强调色；1.0/1.6 文字缩放。检查页面无 RenderFlex 溢出，
危险操作有明确确认与红色动作；取消确认不发出删除请求。

| 场景 | 可核对图片 |
|---|---|
| 320px 中文 1.6 倍字号、亮色、自定义强调色 | [词库页](library-320-zh.png) |
| 360px 英文 1.6 倍字号、选择合并学习进度 | [学习包导入](learning-package-merge-option-360-en.png) |
| 360px 英文 1.6 倍字号、深色、保留项和删除数 | [清理确认](cleanup-confirm-360-en.png) |
| 360px 英文放大文字，下载失败后保留错误及重试入口 | [下载失败](dictionary-download-failure-360-en.png) |

检查还覆盖考试词书预览、单条删除确认、键盘 Tab 焦点和切换进度开关时的范围提示。
没有借此声称 Android/iOS/macOS 真机、原生文件选择器授权或真实用户云服务已验收。
完整离线包在移动设备上的内存峰值、系统 TTS 和真实网络权限矩阵仍待真机验证。

生成可读图片的本机命令（macOS，需系统 Arial Unicode 字体）：

```sh
CAPTURE_UI=1 flutter test test/new_features_ui_test.dart
```

正常 CI 同样加载 SDK Roboto，运行真实控件的布局/交互检查，不依赖 macOS 字体文件。
