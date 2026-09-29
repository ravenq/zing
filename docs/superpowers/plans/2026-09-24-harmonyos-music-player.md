# 鸿蒙本地音乐播放器实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 构建一个模仿 QQ 音乐的鸿蒙本地音乐播放器，支持本地音乐扫描/导入、播放控制、歌词显示、歌单管理、收藏、分类浏览。

**Architecture:** 分层架构（模型/数据/服务/UI），PlayerService 单例由 EntryAbility 持有，AppStorage 作为状态桥梁。

**Tech Stack:** HarmonyOS NEXT API 26, ArkTS, ArkUI 声明式 UI, @ohos.multimedia.media (AVPlayer), @ohos.filemanagement.userFileManager, @ohos.data.preferences, @ohos.data.relationalStore

---

## Task 1: 模型层与公共常量

**Files:**
- Create: `entry/src/main/ets/models/index.ets`
- Create: `entry/src/main/ets/common/Constants.ets`
- Create: `entry/src/main/ets/common/Theme.ets`

- [ ] **Step 1**: 创建 `models/index.ets`，定义 Song、Artist、Album、Playlist、LyricLine、PlayMode 接口与枚举
- [ ] **Step 2**: 创建 `common/Constants.ets`，定义全局常量（AppStorage keys、存储名、默认值）
- [ ] **Step 3**: 创建 `common/Theme.ets`，定义颜色和尺寸工具函数
- [ ] **Step 4**: 提交

## Task 2: 数据层 - Repository 实现

**Files:**
- Create: `entry/src/main/ets/data/MusicRepository.ets`
- Create: `entry/src/main/ets/data/FavoriteRepository.ets`
- Create: `entry/src/main/ets/data/HistoryRepository.ets`
- Create: `entry/src/main/ets/data/PlaylistRepository.ets`

- [ ] **Step 1**: 实现 `FavoriteRepository`（preferences 存储收藏歌曲ID集合）
- [ ] **Step 2**: 实现 `HistoryRepository`（preferences 存储最近播放记录，上限100条）
- [ ] **Step 3**: 实现 `PlaylistRepository`（preferences 存储歌单列表，JSON序列化）
- [ ] **Step 4**: 实现 `MusicRepository`（userFileManager 扫描 + 文件选择器导入 + 搜索 + 分组）
- [ ] **Step 5**: 提交

## Task 3: 服务层 - PlayerService / LrcParser / MusicScanner

**Files:**
- Create: `entry/src/main/ets/services/LrcParser.ets`
- Create: `entry/src/main/ets/services/PlayerService.ets`
- Create: `entry/src/main/ets/services/MusicScanner.ets`

- [ ] **Step 1**: 实现 `LrcParser`（LRC 文本解析为 LyricLine[]，match(time) 返回当前行）
- [ ] **Step 2**: 实现 `MusicScanner`（封装 userFileManager 音频查询，提取元数据）
- [ ] **Step 3**: 实现 `PlayerService`（AVPlayer 封装，队列管理，播放模式，进度回调，AppStorage 同步）
- [ ] **Step 4**: 提交

## Task 4: 资源配置 - 颜色/字符串/权限/路由

**Files:**
- Modify: `entry/src/main/resources/base/element/color.json`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `entry/src/main/resources/base/element/float.json`
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Modify: `entry/src/main/module.json5`
- Modify: `entry/src/main/resources/base/profile/main_pages.json`

- [ ] **Step 1**: 更新 `color.json` 添加 QQ 音乐绿色主题色
- [ ] **Step 2**: 更新 `string.json` 添加应用名称和页面标题
- [ ] **Step 3**: 更新 `float.json` 添加字号和间距
- [ ] **Step 4**: 更新 `module.json5` 添加权限声明（READ_AUDIO）
- [ ] **Step 5**: 更新 `main_pages.json` 注册所有页面路由
- [ ] **Step 6**: 更新 `EntryAbility.ets` 初始化 PlayerService 单例
- [ ] **Step 7**: 提交

## Task 5: UI 层 - 公共组件

**Files:**
- Create: `entry/src/main/ets/components/SongItem.ets`
- Create: `entry/src/main/ets/components/PlaylistCard.ets`
- Create: `entry/src/main/ets/components/MiniPlayerBar.ets`
- Create: `entry/src/main/ets/components/PlayerControls.ets`
- Create: `entry/src/main/ets/components/LyricView.ets`

- [ ] **Step 1**: 实现 `SongItem`（歌曲列表项组件：封面+标题+歌手+时长+更多按钮）
- [ ] **Step 2**: 实现 `PlaylistCard`（歌单卡片组件）
- [ ] **Step 3**: 实现 `MiniPlayerBar`（全局迷你播放条，读取 AppStorage 状态）
- [ ] **Step 4**: 实现 `PlayerControls`（播放控制区：模式/上一首/播放暂停/下一首/列表）
- [ ] **Step 5**: 实现 `LyricView`（歌词滚动视图，高亮当前行）
- [ ] **Step 6**: 提交

## Task 6: UI 层 - 主框架与 Tab 页

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets`
- Create: `entry/src/main/ets/pages/MyMusicPage.ets`
- Create: `entry/src/main/ets/pages/PlaylistPage.ets`
- Create: `entry/src/main/ets/pages/CategoryPage.ets`
- Create: `entry/src/main/ets/pages/SettingsPage.ets`

- [ ] **Step 1**: 重写 `Index.ets` 为 Tabs 容器 + Navigation + MiniPlayerBar
- [ ] **Step 2**: 实现 `MyMusicPage`（快捷入口 + 本地歌曲预览 + 我的歌单）
- [ ] **Step 3**: 实现 `PlaylistPage`（歌单网格 + 新建）
- [ ] **Step 4**: 实现 `CategoryPage`（歌手/专辑 Tab + 列表）
- [ ] **Step 5**: 实现 `SettingsPage`（分组设置列表）
- [ ] **Step 6**: 提交

## Task 7: UI 层 - 二级页面

**Files:**
- Create: `entry/src/main/ets/pages/SongListPage.ets`
- Create: `entry/src/main/ets/pages/ArtistDetailPage.ets`
- Create: `entry/src/main/ets/pages/AlbumDetailPage.ets`
- Create: `entry/src/main/ets/pages/PlaylistDetailPage.ets`
- Create: `entry/src/main/ets/pages/SearchPage.ets`

- [ ] **Step 1**: 实现 `SongListPage`（通用歌曲列表页，支持标题栏 + 全部播放）
- [ ] **Step 2**: 实现 `ArtistDetailPage`（歌手信息 + 歌曲列表）
- [ ] **Step 3**: 实现 `AlbumDetailPage`（专辑封面 + 歌曲列表）
- [ ] **Step 4**: 实现 `PlaylistDetailPage`（歌单封面 + 歌曲列表 + 管理）
- [ ] **Step 5**: 实现 `SearchPage`（搜索框 + 实时结果列表）
- [ ] **Step 6**: 提交

## Task 8: UI 层 - 全屏播放页

**Files:**
- Create: `entry/src/main/ets/pages/PlayingPage.ets`

- [ ] **Step 1**: 实现全屏播放页（Swiper 封面页/歌词页 + 共享控制区 + bindSheet 转场）
- [ ] **Step 2**: 提交

## Task 9: 验证

- [ ] **Step 1**: 检查所有文件语法正确性
- [ ] **Step 2**: 检查模块引用关系完整
- [ ] **Step 3**: 提交最终代码
