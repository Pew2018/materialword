# Classic Material 交互规范

- 保持 Material Design 2、useMaterial3=false。
- Android 页面使用官方 FadeUpwardsPageTransitionsBuilder；Apple 平台保留 Cupertino 转场。
- Manifest 关闭应用预测性返回回调预览。Android 系统边缘/回桌面反馈仍受系统控制；正常返回、IME、Dialog 和 AppBar 返回必须经真机测试。
- 底栏五等宽项、高 56dp；每项完整 InkWell 触控范围；16dp 圆角 Material 裁切和 customBorder；InkRipple 从实际触点扩散。
- 图标与标签颜色以 210ms easeInOut 插值；固定字号、图标尺寸、文字字重，避免布局跳动。选中不加常驻药丸背景。
- 主要按钮 12dp、普通按钮 10dp、Dialog/卡片/菜单 6dp，FAB 使用官方圆形。形状按场景分类。
- Primary 与 Secondary 使用同一强调色；深色使用同一色相的亮度变体。作答保留认识/模糊/不认识语义与文字标签。
- AppBar 1dp、底栏 3dp、普通卡片 0dp；菜单保留经典层级。
- 滚动保留平台自身 physics 和 scrollbar，移除装饰性 overscroll，不向所有平台强制同一物理规则。
- 桌面使用固定/紧凑侧栏，短窗侧栏可滚动；双栏依据父容器的实际宽度。
- 输入 Dialog 的 controller 由 Dialog State 持有并随退出动画完成后销毁。

视觉真机验收和完整控件清单仍在进行，不能以 Widget 结构测试代替。
