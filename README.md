# SeekES

SeekES 是一款 macOS Elasticsearch 桌面客户端，用于连接和管理 Elasticsearch 集群。它提供索引与映射浏览、文档查看和编辑、搜索查询、聚合分析及多连接管理等常用操作，让日常排查和数据探索无需依赖命令行。

官网：[https://newpanjing.github.io/seekes/](https://newpanjing.github.io/seekes/)

## Download

[Download the latest macOS app](https://github.com/newpanjing/seekes/releases/latest/download/SeekES-latest.zip)

The app is distributed unsigned. macOS may require allowing it from **System Settings > Privacy & Security** on first launch.

## Features

- 在一个 macOS 桌面应用中管理多个 Elasticsearch 连接。
- 浏览索引、Mapping 与 Settings，并查看和编辑文档。
- 编写和执行搜索、聚合及分析请求，快速检查响应结果。

## Xcode

Open `SeekES.xcodeproj` in Xcode, select the `SeekES` scheme, then run it. The project already configures the macOS 14 deployment target, bundle identifier, App Sandbox, outgoing network access, Info.plist, and localized resources.

`project.yml` is the Xcode project source. After changing it, run `xcodegen generate` to regenerate `SeekES.xcodeproj`.
