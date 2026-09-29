# 鸿蒙本地音乐播放器设计文档

> 模仿 QQ 音乐 · HarmonyOS NEXT (API 26) · ArkTS

## 1. 概述

开发一个鸿蒙版本地音乐播放器，UI/交互模仿 QQ 音乐，功能覆盖：本地音乐扫描与导入、歌曲播放、歌词显示、歌单管理、收藏、最近播放、按歌手/专辑分类浏览、搜索。

- **目标 SDK**: API 26 (compatibleSdkVersion 26.0.0), Stage 模型
- **视觉主题**: QQ 音乐绿色浅色主题，主色 #31C27C
- **音乐来源**: 系统媒体库扫描 + 文件选择器导入

## 2. 信息架构与导航

### 2.1 主框架

底部 4 Tab 导航 + 全局迷你播放条 + 全屏播放页（模态覆盖层）。

| Tab | 名称 | 核心功能 |
|-----|------|---------|
| 1 | 我的 | 本地歌曲、我喜欢、最近播放、导入入口、我的歌单 |
| 2 | 歌单 | 全部自建歌单网格，新建/编辑/删除 |
| 3 | 分类 | 按歌手/专辑浏览，点击进入详情 |
| 4 | 设置 | 扫描设置、播放模式、歌词开关、关于 |

### 2.2 页面层级

```
Tabs 容器
├── 我的页 (MyMusicPage)
├── 歌单页 (PlaylistPage)
├── 分类页 (CategoryPage)
└── 设置页 (SettingsPage)

二级页面 (Navigation)
├── 本地歌曲列表页 (SongListPage)
├── 歌手详情页 (ArtistDetailPage)
├── 专辑详情页 (AlbumDetailPage)
├── 歌单详情页 (PlaylistDetailPage)
└── 搜索页 (SearchPage)

覆盖层
└── 全屏播放页 (PlayingPage)
    ├── 封面页 (Swiper index 0)
    └── 歌词页 (Swiper index 1)
```

### 2.3 迷你播放条

固定在 Tab 栏上方，全局可见。点击展开全屏播放页（bindSheet 转场动画）。展示：封面缩略图、歌曲名、歌手名、播放/暂停按钮、下一首按钮、播放列表按钮、迷你进度条。

## 3. 分层架构

### 3.1 模型层 (`models/`)

```typescript
// Song - 歌曲
interface Song {
  id: string;           // 唯一标识（文件URI hash）
  title: string;        // 歌曲名
  artist: string;       // 歌手
  album: string;        // 专辑
  duration: number;     // 时长(ms)
  filePath: string;     // 文件路径
  fileSize: number;     // 文件大小
  coverUri?: string;    // 封面URI
  favorite: boolean;    // 是否收藏
}

// Artist - 歌手
interface Artist {
  name: string;
  songCount: number;
  coverUri?: string;
  songs: string[];      // songId 列表
}

// Album - 专辑
interface Album {
  name: string;
  artist: string;
  coverUri?: string;
  songCount: number;
  songs: string[];
}

// Playlist - 歌单
interface Playlist {
  id: string;
  name: string;
  coverUri?: string;
  songIds: string[];
  createdAt: number;
  updatedAt: number;
}

// LyricLine - 歌词行
interface LyricLine {
  time: number;   // 时间戳(ms)
  text: string;   // 歌词文本
}

// PlayMode - 播放模式
enum PlayMode {
  SEQUENCE = 0,   // 顺序播放
  REPEAT_ONE = 1, // 单曲循环
  SHUFFLE = 2     // 随机播放
}
```

### 3.2 数据层 (`data/`)

**MusicRepository**: 歌曲元数据读写
- `scanFromMediaLibrary()`: 通过 userFileManager 扫描系统媒体库音频文件
- `importFromPicker()`: 通过 documentSelect 让用户选择音频文件导入
- `getAllSongs()`: 获取全部歌曲
- `getSongsByArtist()`: 按歌手分组
- `getSongsByAlbum()`: 按专辑分组
- `search()`: 关键词搜索
- 持久化：preferences 缓存歌曲列表，避免每次重新扫描

**PlaylistRepository**: 歌单 CRUD
- `create(name)`, `rename(id, name)`, `delete(id)`
- `addSong(playlistId, songId)`, `removeSong(playlistId, songId)`
- `getAll()`, `getById(id)`
- 持久化：relationalStore

**FavoriteRepository**: 收藏管理
- `toggle(songId)`, `isFavorite(songId)`, `getAllFavorites()`
- 持久化：preferences

**HistoryRepository**: 最近播放
- `add(songId)`, `getRecent(limit=50)`
- 持久化：preferences，最多保留 100 条

### 3.3 服务层 (`services/`)

**PlayerService**: AVPlayer 封装（单例，由 EntryAbility 持有）
- `play(song)`, `playQueue(songs[], startIndex)`
- `pause()`, `resume()`, `seek(position)`
- `next()`, `previous()`
- `setPlayMode(mode)`
- 状态回调：`onStateChange`, `onProgressUpdate`, `onSongChange`, `onPlayModeChange`
- 内部维护播放队列、当前索引、播放模式
- 通过 AppStorage 同步状态：`currentSong`, `playerState`, `currentPosition`, `playMode`, `playQueue`

**LrcParser**: LRC 歌词解析
- `parse(lrcText)`: 解析 LRC 文本为 LyricLine[]
- `match(time)`: 根据当前时间返回高亮行索引
- 支持多时间标签行 `[00:01.00][00:15.00]歌词`
- 内嵌歌词从媒体元数据读取，无歌词时显示纯音乐

**MusicScanner**: 媒体库扫描服务
- 封装 userFileManager / photoAccessHelper 的音频文件查询逻辑
- 提取封面、时长等元数据
- 支持增量扫描

### 3.4 UI 层

页面与组件目录结构：

```
pages/
├── Index.ets              (Tabs 容器 + 迷你播放条)
├── MyMusicPage.ets        (我的)
├── PlaylistPage.ets       (歌单)
├── CategoryPage.ets       (分类)
├── SettingsPage.ets       (设置)
├── SongListPage.ets       (歌曲列表)
├── ArtistDetailPage.ets   (歌手详情)
├── AlbumDetailPage.ets    (专辑详情)
├── PlaylistDetailPage.ets (歌单详情)
├── SearchPage.ets         (搜索)
└── PlayingPage.ets        (全屏播放页)

components/
├── MiniPlayerBar.ets      (迷你播放条)
├── SongItem.ets           (歌曲列表项)
├── PlaylistCard.ets       (歌单卡片)
├── PlayerControls.ets     (播放控制区)
└── LyricView.ets          (歌词滚动视图)
```

## 4. 全屏播放页设计

### 4.1 封面+歌词分页（Swiper）

- **封面页**（index 0）：专辑封面 + 歌曲名/歌手/专辑 + 进度条 + 播放控制 + 功能图标（收藏/下载/评论/更多）
- **歌词页**（index 1）：歌词滚动视图，当前行高亮放大，底部共享进度条和控制按钮
- 左右滑动切换，底部控制区两页共享

### 4.2 播放控制区

- 左：播放模式图标（顺序/单曲循环/随机，点击切换）
- 中：上一首 / 播放暂停(大圆按钮) / 下一首
- 右：播放列表图标（弹出队列列表）

## 5. 色彩主题

通过 `resources/base/element/color.json` 管理：

| 名称 | 色值 | 用途 |
|------|------|------|
| primary | #31C27C | 主色（按钮、高亮、选中态） |
| primary_dark | #26A366 | 深色变体（渐变深色端） |
| primary_light | #5DD99A | 浅色变体（渐变浅色端） |
| bg_white | #FFFFFF | 页面背景白 |
| bg_gray | #F5F6F8 | 分区背景灰 |
| text_main | #333333 | 主文字 |
| text_sub | #999999 | 次文字 |
| divider | #EEEEEE | 分割线 |
| error | #FF5252 | 错误/删除 |
| start_window_background | #FFFFFF | 启动背景 |

## 6. 权限申请

`module.json5` 中声明以下权限：
- `ohos.permission.READ_AUDIO` - 读取音频文件
- `ohos.permission.WRITE_AUDIO` - 写入音频元数据（收藏标记等）

运行时通过 `abilityAccessCtrl` 动态申请。

## 7. 页面路由

`main_pages.json` 配置所有页面路由：
```json
{
  "src": [
    "pages/Index",
    "pages/MyMusicPage",
    "pages/PlaylistPage",
    "pages/CategoryPage",
    "pages/SettingsPage",
    "pages/SongListPage",
    "pages/ArtistDetailPage",
    "pages/AlbumDetailPage",
    "pages/PlaylistDetailPage",
    "pages/SearchPage",
    "pages/PlayingPage"
  ]
}
```

## 8. 错误处理

- 文件扫描失败：显示空状态提示"未找到本地音乐，点击导入"
- 播放失败（文件损坏/格式不支持）：Toast 提示"无法播放此文件"，自动跳到下一首
- 歌词解析失败：显示"暂无歌词"
- 权限被拒绝：显示引导页面"需要存储权限才能扫描本地音乐"

## 9. 测试策略

- 单元测试：LrcParser 解析逻辑、PlayMode 切换逻辑、Repository CRUD
- UI 测试：歌曲列表渲染、播放控制交互、歌词同步
- 使用 @ohos/hypium 测试框架

## 10. 文件目录结构

```
entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets       (持有 PlayerService 单例)
├── models/
│   └── index.ets              (所有模型定义与导出)
├── data/
│   ├── MusicRepository.ets
│   ├── PlaylistRepository.ets
│   ├── FavoriteRepository.ets
│   └── HistoryRepository.ets
├── services/
│   ├── PlayerService.ets
│   ├── LrcParser.ets
│   └── MusicScanner.ets
├── pages/
│   ├── Index.ets
│   ├── MyMusicPage.ets
│   ├── PlaylistPage.ets
│   ├── CategoryPage.ets
│   ├── SettingsPage.ets
│   ├── SongListPage.ets
│   ├── ArtistDetailPage.ets
│   ├── AlbumDetailPage.ets
│   ├── PlaylistDetailPage.ets
│   ├── SearchPage.ets
│   └── PlayingPage.ets
├── components/
│   ├── MiniPlayerBar.ets
│   ├── SongItem.ets
│   ├── PlaylistCard.ets
│   ├── PlayerControls.ets
│   └── LyricView.ets
└── common/
    ├── Constants.ets          (全局常量)
    └── Theme.ets             (主题工具函数)
```
