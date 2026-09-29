# 在线音乐音源模块设计文档

> 知音 / Zing · HarmonyOS NEXT (API 26) · ArkTS
> 关联文档：`2026-09-24-harmonyos-music-player-design.md`

## 1. 概述

在现有本地音乐播放器基础上新增"在线音乐"能力：搜索合法开放曲库、在线试听、下载并可加入本地库；同时支持用户自定义 RSS 播客源与可配置 JSON 接口源。

### 1.1 合规边界

- 仅接入官方开放接口、Creative Commons 等允许分享的曲库，以及权利人自行授权的音源。
- 不接入未授权 MP3 搬运站、聚合解析站；不绕过登录、VIP、防盗链。
- 对要求署名/非商业许可的曲目展示许可名称与许可链接。

### 1.2 第一版范围

| 能力 | 第一版 |
|------|--------|
| 内置 ccMixter（CC 曲库，无需密钥） | 是，开箱即用 |
| 内置 Jamendo（需 client_id） | 是，用户在音源管理页填写后启用 |
| 自定义 RSS/播客源 | 是 |
| 自定义可配置 JSON 接口源 | 是 |
| 在线试听 | 是 |
| 下载（受 `downloadable` 开关约束） | 是 |
| 下载后加入本地库 | 是，可在设置中关闭 |
| 下载断点续传 / 重启恢复 | 否 |
| FMA、Internet Archive 内置 | 否（后续可按适配器扩展） |

### 1.3 关键约束

- 不改动现有 `Song` 模型字段与 `PlayerService` 内部播放逻辑。
- 在线临时曲目不写入 `ALL_SONGS` 与本地缓存，保证本地库纯净；仅"下载并入库"的曲目以稳定 id 进入本地库。
- 新增普通权限 `ohos.permission.INTERNET`；下载到应用沙箱无需额外存储权限。

## 2. 分层架构

### 2.1 架构总览（方案 A：适配器 + 统一 OnlineTrack）

```text
页面层
  OnlineSearchPage            SourceManagePage
  OnlineTrackItem(组件)
        │ 搜索/试听                    │ 配置读写
        ▼                              ▼
  SourceRegistry               SourceRepository
  - 聚合已启用音源              (preferences 持久化)
  - 并行搜索/单源失败隔离       - 自定义音源列表
  - toPlayableSong() 映射       - Jamendo client_id
                               - 各源启用状态/下载设置
        │
   ┌────┴───────────────────────────────────┐
   │  IMusicSource (接口)                    │
   ├───────────┬──────────┬─────────┬───────┴────────┐
   │ CcMixter  │ Jamendo  │ Rss     │ JsonApi        │
   └───────────┴──────────┴─────────┴────────────────┘
        │
  DownloadService (@ohos.request.downloadFile)
  - 下载进度 / 完成后导入本地库
```

### 2.2 核心数据流

- **搜索**：页面输入关键词 → `SourceRegistry.searchAll(keyword)` → 对所有 `enabled && isReady()` 的适配器并行调用 → 单源失败进入 `failedSources`，成功结果合并（每条带 `sourceId/sourceName`）。
- **试听**：`OnlineTrack` → `SourceRegistry.toPlayableSong(track)` 生成临时 `Song`（`filePath=streamUrl`，`id='online:'+sourceId+':'+trackId`）→ `PlayerService.playQueue(songs, index)`，复用现有播放链路。
- **下载/入库**：`DownloadService.start(track)` → 沙箱文件 → 按设置以稳定 id 构造本地 `Song` 并合并入库。

## 3. 数据模型

新增于 `models/OnlineTypes.ets`，不修改现有 `Song` 字段。

```typescript
export type SourceKind = 'builtin' | 'rss' | 'jsonapi';

export interface OnlineTrack {
  id: string;                 // 音源内唯一 id
  sourceId: string;           // 'ccmixter' | 'jamendo' | 自定义源 id
  sourceName: string;         // 展示用音源名
  title: string;
  artist: string;
  duration: number;           // 毫秒，未知填 0
  streamUrl: string;          // 试听地址（AVPlayer url）
  coverUrl?: string;
  licenseName?: string;       // 如 "CC BY 3.0"
  licenseUrl?: string;
  downloadUrl?: string;       // 无下载授权时留空
  downloadable: boolean;      // Jamendo 取 audiodownload_allowed
}

export interface JsonFieldMapping {
  listPath: string;           // 结果数组路径，如 "results" 或 "data.tracks"
  id: string;
  title: string;
  artist: string;
  duration?: string;          // 可空，单位秒
  streamUrl: string;
  coverUrl?: string;
  downloadUrl?: string;
  licenseName?: string;
  licenseUrl?: string;
}

export interface MusicSourceConfig {
  id: string;                 // 内置固定 ccmixter/jamendo；自定义生成唯一 id
  name: string;
  kind: SourceKind;
  enabled: boolean;
  url?: string;               // RSS 地址或 JSON 模板（含 {keyword}）
  mapping?: JsonFieldMapping; // 仅 jsonapi
  headers?: Record<string, string>;
  builtin?: boolean;          // 内置源不可删除
}

export type DownloadStatus = 'pending' | 'running' | 'completed' | 'failed';

export interface DownloadTask {
  trackId: string;
  title: string;
  sourceId: string;
  status: DownloadStatus;
  progress: number;           // 0-100
  localPath?: string;
  error?: string;
}

export interface SourceFailure {
  sourceId: string;
  sourceName: string;
  reason: string;
}
```

字段映射路径规则：字段值统一使用相对路径，用 `.` 分隔；`listPath` 指向结果数组，其余字段路径相对数组内单个元素。

## 4. 适配器接口与各源约定

```typescript
export interface IMusicSource {
  config: MusicSourceConfig;
  isReady(): boolean;                              // 是否可发起请求
  search(keyword: string): Promise<OnlineTrack[]>; // 失败抛异常，由 Registry 隔离
}
```

### 4.1 CcMixterSourceAdapter（builtin，默认启用）

- 请求：`https://ccmixter.org/api/query?f=json&s={enc(keyword)}&search_type=all&limit=30`
- 解析：每条取 `upload_id/upload_name/user_name`；`files[]` 中取音频文件 `download_url` 作为 `streamUrl`（优先 mp3）；`license_name/license_url` 直接映射；`downloadable=true`。
- 无密钥，`isReady()` 恒为 true。

### 4.2 JamendoSourceAdapter（builtin，默认启用但需密钥）

- 请求：`https://api.jamendo.com/v3.0/tracks/?client_id={id}&format=json&limit=30&namesearch={enc(keyword)}`
- `isReady()`：client_id 非空才 true；为空时 Registry 跳过且不报错。
- 解析：`results[]` → `id/name/artist_name/duration*1000/audio/image`；许可名取 `license_name`、许可链接取 `license_ccurl`（任一为空时对应信息不展示）；`downloadUrl=audiodownload`；`downloadable=audiodownload_allowed`。
- 返回 `status:"failed"`（如 code 5 凭证无效）时抛出带提示错误，Registry 标记该源失败，UI 显示"Jamendo 凭证无效"。

### 4.3 RssSourceAdapter（自定义）

- 拉取用户填写的 RSS/播客 URL；解析 `item`：`title`、`enclosure@url`（作为 streamUrl）、`itunes:duration`、`itunes:image`。
- 多数播客无服务端搜索，故对 title/作者做本地关键词过滤。
- `downloadable = !!enclosure.url`。
- XML 通过 `XmlMiniParser` 最小解析（ArkTS 无内置 DOM）。

### 4.4 JsonApiSourceAdapter（自定义）

- URL 模板将 `{keyword}` 替换为编码后关键词。
- 按 `mapping.listPath` 沿 `.` 路径取数组，逐字段按相对路径提取；`duration` 若提供按秒 ×1000。
- 支持可选自定义 `headers`（第一版 0~1 个键值对）。

### 4.5 SourceRegistry

```typescript
class SourceRegistryClass {
  searchAll(keyword: string): Promise<{ tracks: OnlineTrack[]; failedSources: SourceFailure[] }>;
  toPlayableSong(track: OnlineTrack): Song;
  toPlayableSongs(tracks: OnlineTrack[]): Song[];
}
```

- 对所有 `enabled && isReady()` 源使用 `Promise.allSettled`；fulfilled 合并，rejected 进 `failedSources`。
- 结果顺序：ccMixter → Jamendo → 自定义源；源内保持各自返回顺序。
- `toPlayableSong` 仅做内存映射，不写 `ALL_SONGS`、不写缓存。

## 5. 页面与交互

### 5.1 入口与路由

- MyMusicPage 快捷入口新增"在线音乐"（图标 `⌕`），跳 `OnlineSearchPage`；保留现有四个本地入口。
- 音源管理入口：OnlineSearchPage 右上角"音源"按钮 + SettingsPage"在线音源管理"行，均跳 `SourceManagePage`。
- `RouterPath` 新增：

```typescript
static readonly ONLINE_SEARCH = 'pages/OnlineSearchPage';
static readonly SOURCE_MANAGE = 'pages/SourceManagePage';
```

- `main_pages.json` 登记两个新页面，并补登当前遗漏的 `pages/PlayingPage`。

### 5.2 OnlineSearchPage

沿用 SearchPage 的 token 竞态模式（输入即搜、`searchToken` 防旧结果覆盖）。

```text
‹   [ 🔍 搜索在线音乐 ]            音源
⚠ Jamendo 未配置 client_id（点此去配置）   # 仅在源未就绪/失败时
在线音乐（源名 + 数量）
♪ 曲目A   艺术家   CC BY      ⬇
♪ 曲目B   艺术家   CC BY-NC   ⬇
Jamendo
♪ ...
```

- 单个 `List` + section header 分组。
- 点击行试听：合并结果 `toPlayableSongs` 后 `playQueue(songs, index)`；正在播放行显示 ●；MiniPlayerBar 与 PlayingPage 通过同一 `CURRENT_SONG` 自动生效。
- 行尾下载按钮：
  - `downloadable=false` → 置灰，提示"该曲目版权方未开放下载，仅可试听"。
  - 可下载 → 进入 DownloadService，按钮随进度更新。
- 许可标识：行内小字显示 `licenseName`；点击展示署名文本与 `licenseUrl`（第一版不引入 Web 组件）。
- 全部源失败空态："网络不可用或所有音源暂不可用" + 去音源设置入口。

### 5.3 SourceManagePage

```text
内置音源
  ccMixter   [开关]   无需密钥，直接可用
  Jamendo    [开关]
    client_id: [____________]   填写后自动生效
自定义音源
  我的播客A   RSS   [开关]  编辑  删除
  JSON源B     JSON  [开关]  编辑  删除
  [ + 添加音源 ]
下载设置
  下载后自动加入本地库   [开关，默认开]
```

- Jamendo client_id：TextInput 保存后写入 SourceRepository，下次搜索即时生效；附"到 developer.jamendo.com 免费申请"提示。
- 添加/编辑表单按类型切换：
  - RSS：名称、Feed URL。
  - JSON：名称、URL 模板（含 `{keyword}`）、headers（可选 0~1 键值对）、字段映射（listPath/id/title/artist/streamUrl 必填，其余选填）。
  - 校验：URL 非空且为 http(s)；JSON 必填映射缺失则禁用保存。
  - 编辑回填；删除前二次确认；内置源不显示删除。
- 所有改动即时持久化并刷新 Registry。

### 5.4 下载与导入本地库

```typescript
class DownloadServiceClass {
  start(track: OnlineTrack): void;
  getTasks(): DownloadTask[];
  onTasksChange(cb: (tasks: DownloadTask[]) => void): void;
}
```

- 使用 `@ohos.request.downloadFile`，保存到沙箱 `filesDir/online/`，文件名 `track.id + 扩展名`（由 downloadUrl 推断，默认 `.mp3`）。
- `progress` 更新进度；`complete` → completed + localPath；`fail` → failed + error。任务列表仅存内存。
- 行尾状态：running 显示百分比/进度；completed 显示 ✓；failed 显示重试。
- 入库（"下载后自动加入本地库"默认开）：
  - 构造本地 `Song`：`id='download:'+sourceId+':'+track.id`；`filePath=localPath`；title/artist/coverUri/duration 透传；`album=sourceName`；`favorite=false`。
  - 复用"按 id 去重合并 → `AppStorage.setOrCreate(ALL_SONGS)` → `MusicRepository.cacheSongs`"流程（从 MyMusicPage 抽出为可复用方法）。
  - Toast"已下载并加入本地库"；关闭开关时仅下载并提示"已保存到设备"。

## 6. 网络与错误处理

### 6.1 HttpUtil

```typescript
export class HttpUtil {
  static async getJson(url: string, headers?: Record<string, string>): Promise<Object>;
  static async getText(url: string, headers?: Record<string, string>): Promise<string>;
}
```

- 基于 `@ohos.net.http`，`connectTimeout/readTimeout = 10s`，GET，默认 User-Agent。
- 非 2xx 抛带状态码错误；JSON 解析失败抛"音源返回格式异常"。
- 内置源对网络超时/5xx 自动重试 1 次（间隔 800ms）；4xx 不重试。
- 不记录 client_id 等敏感信息。

### 6.2 错误分层

| 场景 | 处理 | 用户感知 |
|------|------|----------|
| 单源网络失败/超时 | allSettled 捕获 | 顶部提示"xx 音源暂不可用"，其他源正常 |
| Jamendo 未配置 | isReady=false，跳过 | 提示条，可点跳配置 |
| Jamendo 凭证无效 | search 抛错 | 该源分组提示凭证无效 |
| 所有源失败 | tracks 为空 | 失败空态 + 去设置 |
| 无下载授权 | downloadable=false | 下载按钮置灰 |
| 下载失败 | 单任务 failed | 行尾重试 |
| 入库失败 | 文件保留 | "已下载，加入本地库失败" |
| 试听失败 | 复用 PlayerService 自动切下一首 | 自动跳下一首，超限停止 |

竞态控制：搜索用 `searchToken`；下载以 `sourceId:trackId` 为唯一键，重复点击直接忽略。

## 7. 测试策略

项目当前无单测框架，第一版以手动验证 + 纯函数自测为主，不引入测试框架。

- 纯函数（用 node 临时断言，脚本不入库）：JSON 路径提取、URL 模板替换、RSS 最小解析、OnlineTrack→Song 映射、下载去重键。
- 设备端手动验证清单：
  1. 全新安装：ccMixter 可搜（开箱即用），Jamendo 提示未配置。
  2. 无效 client_id → 凭证无效提示；有效 id → 出结果。
  3. 点结果试听、MiniPlayer/全屏页同步、自动切下一首。
  4. 下载授权曲目 → 进度 → 本地库出现，断网仍可播放。
  5. downloadable=false 按钮置灰。
  6. 自定义 RSS/JSON 源可搜可过滤；关闭/删除生效。
  7. 飞行模式失败空态；恢复后重搜正常。
- 构建门禁：交付前 `devecocli` assemble，确认无 ArkTS 严格模式/类型错误。

## 8. 文件清单

### 8.1 新增

```text
entry/src/main/ets/models/OnlineTypes.ets
entry/src/main/ets/services/online/HttpUtil.ets
entry/src/main/ets/services/online/IMusicSource.ets
entry/src/main/ets/services/online/CcMixterSourceAdapter.ets
entry/src/main/ets/services/online/JamendoSourceAdapter.ets
entry/src/main/ets/services/online/RssSourceAdapter.ets
entry/src/main/ets/services/online/JsonApiSourceAdapter.ets
entry/src/main/ets/services/online/SourceRegistry.ets
entry/src/main/ets/services/online/XmlMiniParser.ets
entry/src/main/ets/services/DownloadService.ets
entry/src/main/ets/data/SourceRepository.ets
entry/src/main/ets/pages/OnlineSearchPage.ets
entry/src/main/ets/pages/SourceManagePage.ets
entry/src/main/ets/components/OnlineTrackItem.ets
```

### 8.2 修改

```text
entry/src/main/module.json5                            # +INTERNET
entry/src/main/ets/common/Constants.ets                # +路由/StorageName
entry/src/main/resources/base/profile/main_pages.json  # +两个新页面、补 PlayingPage
entry/src/main/ets/pages/MyMusicPage.ets               # +在线入口、抽合并入库方法
entry/src/main/ets/pages/SettingsPage.ets              # +在线音源管理入口
entry/src/main/ets/data/MusicRepository.ets            # 复用入库方法（如需要）
```

### 8.3 不改动

PlayerService 内部逻辑、PlayingPage、现有 Song 模型字段、本地扫描/收藏/歌单逻辑。

## 9. 实施顺序

1. 基础设施：INTERNET 权限、Constants、main_pages、OnlineTypes、HttpUtil。
2. 内置 ccMixter 适配器（先跑通能搜能听）。
3. SourceRegistry + OnlineSearchPage + OnlineTrackItem（合并搜索 + 试听闭环）。
4. Jamendo 适配器 + SourceRepository + SourceManagePage（密钥与音源管理）。
5. DownloadService + 下载进度 + 入库复用方法。
6. RSS（XmlMiniParser）+ JSON 适配器及配置表单。
7. 按第 7 节清单逐项设备验证 + 构建门禁。
