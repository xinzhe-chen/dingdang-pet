# Dingdang Pet 资源协议 v1

## 设计原则

动作不绑定行号。atlas 只描述图像几何，animation 描述帧序列，binding 把运行时语义连接到任意动画，behavior 描述安全的互动组合。

配置优先级为：App 安全上限 > 用户设置 > Release 默认值。资源更新不会覆盖用户手动选择的缩放和显示模式。

## Catalog

入口必须是资源包根目录的 `catalog.json`：

```json
{
  "schemaVersion": 1,
  "catalogVersion": "1.2.0",
  "defaultPetID": "dingdang",
  "pets": []
}
```

一个 Release 可以包含多只宠物。`defaultPetID` 必须对应其中一只。

## Atlas

网格 atlas 的行列和 cell 尺寸完全可变：

```json
{
  "id": "main",
  "file": "pets/dingdang/main.webp",
  "filtering": "nearest",
  "layout": {
    "type": "grid",
    "columns": 12,
    "rows": 17,
    "cellWidth": 192,
    "cellHeight": 208,
    "spacing": 0,
    "margin": 0
  }
}
```

不规则 atlas 使用命名矩形：

```json
{
  "id": "special",
  "file": "pets/dingdang/special.webp",
  "layout": {
    "type": "rects",
    "frames": {
      "sleep-01": { "x": 0, "y": 0, "width": 220, "height": 190 }
    }
  }
}
```

## Animation

每个动画独立声明帧数、帧时长、播放模式和循环策略：

```json
{
  "dance": {
    "frames": [
      { "atlas": "main", "row": 4, "column": 0, "durationMs": 100 },
      { "atlas": "special", "name": "sleep-01", "durationMs": 180 }
    ],
    "playback": "pingPong",
    "loopCount": 2,
    "priority": 6,
    "interruptible": true
  }
}
```

支持 `forward`、`reverse` 和 `pingPong`。单帧可以设置 offset、scale 和 flipX。

## Bindings

唯一必需语义是 `defaultIdle`。常用可选语义：

- `moveLeft` / `moveRight`
- `primaryClick` / `secondaryClick` / `longPress`
- `dragging`
- `updateSucceeded` / `updateFailed`

绑定目标是 animations 中任意名称。

## Directional look

方向数不限于 16。`degrees` 使用屏幕坐标中的顺时针角度：0 为上，90 为右，180 为下，270 为左。运行时使用最近角度选择。

## Behavior graph

安全原语：

- `play`
- `wait`
- `sequence`
- `random`
- `condition`
- `transition`
- `playSound`
- `set`

资源不能定义代码。`set` 只允许运行时认识的属性；未知属性不会产生系统副作用。

可读取上下文包括 displayMode、distanceToLeftEdge、distanceToRightEdge、clickCount、idleDuration、currentScale 和当前动画状态。

## Presentation

桌面可配置默认/最小/最大缩放、高度和锚点。菜单栏可配置高度、是否填满系统实际菜单栏高度、每秒移动点数、安全边距、暂停范围和刘海穿越策略：

- `fillsAvailableHeight: true`：使用当前屏幕真实菜单栏高度，并将宠物脚底对齐菜单栏底边；`false` 时使用 `height`，但不会超过菜单栏。
- `notchTraversal: "continuous"`：坐标连续穿过刘海，物理刘海遮挡期间不瞬移；`"skip"` 才会显式跳过刘海区。
- `safeMarginLeft` / `safeMarginRight`：安全范围模式下的两侧边距；用户选择“整条菜单栏”时边距为 0。
- `speed` 与 `pauseInterval`：移动速度和抵达最外侧后可选的原地暂停区间。

用户设置优先于 Release 默认值。

## 限制

- 最多 128 只宠物
- 每只最多 32 个 atlas
- 每只最多 512 个动画
- 每个动画最多 4096 帧
- atlas 单边最多 16384 像素
- FPS 最大 60
- catalog 解压后最多 256 MiB
- ZIP 最多 4096 个目录项，路径不得为绝对路径、反斜杠路径或包含 `.` / `..` 段

这些是固定运行时的安全上限，不能由 Release 放宽。
