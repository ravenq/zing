# 知音 Zing

> 一款基于 HarmonyOS NEXT 的本地音乐播放器，支持在线音源与网页资源嗅探下载。

知音（英文 Zing）是使用 ArkTS 开发的鸿蒙原生音乐应用，以「本地播放」为核心，同时提供合规的在线曲库接入和通用学习用途的网页资源嗅探能力。界面采用扁平、简洁的设计风格，整体色调统一。

<p align="center">
  <img src="screenshots/home.png" width="320" alt="知音 App 首页截图">
</p>

## 功能特性

### 本地播放
- 自动扫描设备中的本地音频文件（基于 `READ_AUDIO` 媒体库权限）
- 按专辑、歌手、歌曲分类浏览
- 播放 / 暂停、上一首 / 下一首、进度拖拽
- 顺序播放、单曲循环、随机播放多种播放模式
- 我喜欢、最近播放、自建歌单管理
- 支持从本地文件导入音乐

### 在线音乐
- 音源管理：可配置并管理多个在线音乐源
- 内置 Jamendo、ccMixter 等基于官方开放接口的适配器
- 通用 JSON / RSS 源适配器，便于扩展
- 在线搜索与试听

### 网页嗅探
- 用户自行输入网址，嗅探网页中的音频资源
- 嗅探到的资源可下载到本地播放
- 定位为通用学习工具，仅用于访问合规、授权的内容

### 后台与系统集成
- 后台连续播放（`audioPlayback` 后台模式）
- AVSession 媒体会话，通知栏 / 控制中心显示当前歌曲及上一首、下一首、播放暂停控制
- 锁屏与系统媒体控制联动

## 技术栈

- HarmonyOS NEXT（API 26 / HarmonyOS 7.0.0）
- ArkTS 严格模式、ArkUI 声明式 UI
- AVPlayer 音频播放、AVSession 媒体会话
- 系统媒体库扫描、RelationalStore 本地数据持久化
- 单 EntryAbility，phone 设备

## 项目结构

```
entry/src/main/ets/
├── common/          常量与主题
├── components/      播放控制、迷你播放条、歌曲项等通用组件
├── data/            音乐、收藏、历史、歌单、音源等数据仓库
├── models/          数据模型
├── pages/           首页、播放页、各列表与详情页、音源管理、网页嗅探
└── services/        播放服务、媒体会话、扫描、下载
    └── online/      在线音源适配器与注册中心
```

## 运行要求

- DevEco Studio（支持 HarmonyOS NEXT API 26）
- HarmonyOS NEXT 设备或模拟器
- 首次运行需授予音频读取权限以扫描本地音乐

## 构建运行

1. 使用 DevEco Studio 打开本项目
2. 等待依赖同步完成
3. 连接 HarmonyOS NEXT 设备或启动模拟器
4. 点击 Run，或使用命令行：

```bash
devecocli run --device <device-serial>
```

> 仓库中不包含签名材料，调试运行时由 DevEco Studio 自动生成调试签名。

## 合规说明

- 本项目仅接入官方开放接口、Creative Commons 曲库或已授权的音乐源。
- 不包含也不会提供任何绕过登录、VIP、签名校验或 DRM 的能力。
- 网页嗅探为用户自行输入网址的通用工具，使用者需自行确保所访问内容符合法律法规及版权要求。

## 开源协议

本项目基于 [Apache License 2.0](LICENSE) 开源。

```
Copyright 2026 fanliwen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```
