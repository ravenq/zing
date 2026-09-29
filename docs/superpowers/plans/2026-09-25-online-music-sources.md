# 在线音乐音源模块实施计划

**Date**: 2026-09-25
**Goal**: 为知音播放器新增在线音乐搜索、试听、下载与自定义音源（RSS/JSON）能力
**Execute with**: executing-plans
**关联设计**: `docs/superpowers/specs/2026-09-25-online-music-sources-design.md`

## Architecture Summary

适配器架构：`IMusicSource` 统一搜索接口，内置 ccMixter/Jamendo，自定义 RSS/JsonApi；`SourceRegistry` 以 `Promise.allSettled` 聚合并隔离单源失败；在线曲目通过 `toPlayableSong` 内存映射为 `Song`（filePath=streamUrl）复用 PlayerService；DownloadService 下载到沙箱并按稳定 id 入库。

不改动 PlayerService、PlayingPage、Song 模型字段。不做 git 提交。

## Tech Stack

| 组件 | 库/工具 | 用途 |
|------|---------|------|
| HTTP | @ohos.net.http | 音源请求 |
| 播放 | @kit.MediaKit AVPlayer（现有） | 网络流试听 |
| 下载 | @ohos.request.downloadFile | 文件下载 |
| 持久化 | @kit.ArkData preferences | 音源配置/密钥 |

## File Responsibility Map

| 文件 | 职责 |
|------|------|
| models/OnlineTypes.ets | 新增：在线模型 |
| services/online/HttpUtil.ets | 新增：HTTP 封装 + 重试 |
| services/online/JsonPath.ets | 新增：纯函数路径提取/模板/映射 |
| services/online/XmlMiniParser.ets | 新增：RSS 最小解析 |
| services/online/IMusicSource.ets | 新增：音源接口 |
| services/online/CcMixterSourceAdapter.ets | 新增：ccMixter |
| services/online/JamendoSourceAdapter.ets | 新增：Jamendo |
| services/online/RssSourceAdapter.ets | 新增：RSS |
| services/online/JsonApiSourceAdapter.ets | 新增：JSON 模板 |
| services/online/SourceRegistry.ets | 新增：聚合/映射 |
| services/DownloadService.ets | 新增：下载与进度 |
| data/SourceRepository.ets | 新增：配置持久化 |
| pages/OnlineSearchPage.ets | 新增：在线搜索页 |
| pages/SourceManagePage.ets | 新增：音源管理页 |
| components/OnlineTrackItem.ets | 新增：结果项 |
| common/Constants.ets | 修改：+路由/StorageName |
| resources/base/profile/main_pages.json | 修改：+页面、补 PlayingPage |
| module.json5 | 修改：+INTERNET |
| pages/MyMusicPage.ets | 修改：+在线入口、抽入库方法 |
| pages/SettingsPage.ets | 修改：+音源管理入口 |
| entryability/EntryAbility.ets | 修改：初始化 SourceRepository |

## 验证约定

- 纯函数（JsonPath/映射/去重键）：node 临时断言，脚本不入库。
- 构建门禁：`devecocli assemble`（或 build），无 ArkTS 严格模式错误。
- 设备验证：设计文档第 7 节清单。

## Tasks

### Task 1：基础设施（权限/路由/模型/HTTP）

**Goal**：搭好模块骨架，可独立编译。

1. module.json5：`requestPermissions` 增加
   ```json5
   { "name": "ohos.permission.INTERNET" }
   ```
2. Constants.ets：StorageName 增加 `SOURCE='source_storage'`；RouterPath 增加 `ONLINE_SEARCH='pages/OnlineSearchPage'`、`SOURCE_MANAGE='pages/SourceManagePage'`。
3. main_pages.json：src 增加 `pages/PlayingPage`、`pages/OnlineSearchPage`、`pages/SourceManagePage`。
4. 新建 models/OnlineTypes.ets：按设计第 3 节写入全部接口/类型（SourceKind/OnlineTrack/JsonFieldMapping/MusicSourceConfig/DownloadStatus/DownloadTask/SourceFailure）。
5. 新建 services/online/HttpUtil.ets：基于 @ohos.net.http，10s 超时，getJson/getText，超时/5xx 重试 1 次（800ms），非 2xx 抛错。

**Verify**：构建通过。

### Task 2：纯函数工具 + ccMixter 适配器

**Goal**：跑通首个内置源"能搜"。

1. 新建 services/online/JsonPath.ets：
   - `getPath(obj: Object, path: string): Object`（`.` 分隔，缺失返回 undefined）
   - `fillTemplate(tpl: string, keyword: string): string`（替换 `{keyword}` 为 encodeURIComponent）
   - `buildOnlineSongId(sourceId, trackId): string` → `online:sourceId:trackId`
   - `buildDownloadSongId(sourceId, trackId): string` → `download:sourceId:trackId`
   node 断言全部正确。
2. 新建 IMusicSource.ets：接口（config/isReady/search）。
3. 新建 CcMixterSourceAdapter.ets：请求 `https://ccmixter.org/api/query?f=json&s={kw}&search_type=all&limit=30`，映射 upload_id/upload_name/user_name/files[](download_url, 优先 mp3)/license_name/license_url，downloadable=true。

**Verify**：node 断言纯函数；构建通过。

### Task 3：SourceRegistry + 搜索页 + 结果项（试听闭环）

**Goal**：合并搜索 + 点击试听。

1. 新建 SourceRegistry.ets：searchAll（allSettled，顺序 ccmixter→jamendo→自定义）、toPlayableSong/toPlayableSongs。
2. 新建 components/OnlineTrackItem.ets：封面/标题/艺术家/许可徽标/下载按钮位（本任务先占位回调）。
3. 新建 pages/OnlineSearchPage.ets：token 竞态、顶部失败提示条、单 List 分组、点击行 `PlayerService.playQueue(toPlayableSongs(results), index)`。
4. MyMusicPage 快捷入口加"在线音乐"。

**Verify**：构建通过；设备上 ccMixter 可搜可试听。

### Task 4：Jamendo + SourceRepository + 音源管理页

**Goal**：密钥配置与 Jamendo 启用。

1. 新建 data/SourceRepository.ets：preferences 保存内置/自定义源配置、jamendo client_id、autoAddToLibrary（默认 true）；提供 getConfigs/saveConfig/deleteConfig/getJamendoClientId/setJamendoClientId/getAutoAdd。
2. 新建 JamendoSourceAdapter.ets：client_id 为空 isReady=false；映射 results（license_name/license_ccurl/audiodownload/audiodownload_allowed）；status=failed 抛错。
3. 新建 pages/SourceManagePage.ets：内置源开关、Jamendo client_id 输入、自定义源列表（本任务自定义增删弹窗可先做名称/URL，字段映射在 Task 6 补全）、下载开关。
4. SettingsPage 增加"在线音源管理"行；EntryAbility 初始化 SourceRepository 并刷新 Registry。

**Verify**：构建；设备上未配置提示、填无效 id 提示凭证无效。

### Task 5：DownloadService + 进度 + 入库

**Goal**：可下载并入库。

1. 新建 services/DownloadService.ets：downloadFile 到 `filesDir/online/{trackId}{ext}`；progress/complete/fail；以 sourceId:trackId 去重；onTasksChange 订阅。
2. 抽公共入库方法（LocalLibrary 工具或在 MusicRepository 增加 mergeAndCache(songs)），MyMusicPage/SettingsPage 改为复用。
3. OnlineTrackItem/OnlineSearchPage 接下载状态：百分比/✓/重试；完成后按 autoAdd 构造 download: Song 并 mergeAndCache。

**Verify**：设备下载授权曲目→进度→本地库出现→断网可播；无授权按钮置灰。

### Task 6：RSS + JSON 自定义源完整表单

**Goal**：完成两类自定义音源。

1. 新建 services/online/XmlMiniParser.ets：提取 item 的 title、enclosure url、itunes:duration、itunes:image。
2. 新建 RssSourceAdapter.ets：getText + 解析 + 本地关键词过滤。
3. 新建 JsonApiSourceAdapter.ets：fillTemplate + listPath 取数组 + 字段映射 + headers。
4. SourceManagePage 表单补全：RSS（名称/Feed URL）、JSON（名称/模板/headers/字段映射必填校验）。

**Verify**：node 断言解析/映射；设备添加自定义源可搜、开关/删除生效。

### Task 7：端到端验证与构建门禁

**Goal**：按设计第 7 节清单全量验证。

1. 飞行模式失败空态、恢复重搜。
2. 全量回归本地播放/收藏/歌单无影响。
3. `devecocli` assemble 无错误。

## Success Criteria

- [ ] ccMixter 开箱即搜即听
- [ ] Jamendo 填 client_id 后可搜，无效有提示
- [ ] 可下载曲目下载入库，断网可播；无授权置灰
- [ ] 自定义 RSS/JSON 可增删改、开关生效
- [ ] 全源失败有空态
- [ ] 本地功能无回归；assemble 通过
