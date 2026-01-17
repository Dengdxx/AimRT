# Iceoryx2 Plugin for AimRT

基于 [Eclipse iceoryx2](https://github.com/eclipse-iceoryx/iceoryx2) 的 AimRT 零拷贝 IPC 通信插件。

## 特性

- ✅ **零拷贝通信** - 共享内存直接传输，无序列化开销
- ✅ **无守护进程** - 不需要 RouDi（与 iceoryx1 不同）
- ✅ **性能统计** - 自动统计发布/订阅次数和字节数
- ✅ **抽象封装** - `Iox2Publisher`/`Iox2Subscriber` 包装器

## 文件结构

```
iceoryx2_plugin/
├── iceoryx2_plugin.h/cc       # 插件入口
├── iceoryx2_channel_backend.h/cc  # Channel 后端实现
├── iceoryx2_publisher.h       # Publisher 封装
├── iceoryx2_subscriber.h      # Subscriber 封装
├── iceoryx2_types.h           # 公共类型 (Iox2Stats, Iox2Error)
├── global.h/cc                # 日志
└── test/                      # 单元测试
```

## 配置示例

```yaml
aimrt:
  plugin:
    plugins:
      - name: iceoryx2_plugin
        path: /path/to/aimrt_iceoryx2_plugin.so
        options:
          max_slice_len: 4194304      # 4MB per message
          node_name: "my_vision_node" # 可选，进程隔离标识
          listener_thread_name: "iox2_listener"
          listener_thread_sched_policy: "SCHED_FIFO"  # 可选，实时调度
          listener_thread_bind_cpu: [2, 3]            # 可选，CPU 亲和性
          use_event_mode: true        # 使用 WaitSet 事件模式

  channel:
    backends:
      - type: iceoryx2
        options:
          max_slice_len: 4194304
    
    pub_topics_options:
      - topic_name: /vision/frames
        enable_backends: [iceoryx2]
    
    sub_topics_options:
      - topic_name: /vision/frames
        enable_backends: [iceoryx2]
```

### 配置项说明

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `max_slice_len` | uint64 | 4MB | 单条消息最大大小 |
| `node_name` | string | `aimrt_iox2_{pid}` | 节点名称，用于进程隔离和调试 |
| `listener_thread_name` | string | 空 | 监听线程名称 |
| `listener_thread_sched_policy` | string | 空 | 调度策略 (SCHED_FIFO/SCHED_RR) |
| `listener_thread_bind_cpu` | uint32[] | 空 | CPU 亲和性绑定 |
| `use_event_mode` | bool | true | 使用 WaitSet 事件驱动模式 |

## 编译

### 前置条件

**Rust 工具链** - iceoryx2 基于 Rust 编写，需要安装：

```bash
# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 使用 nightly 版本
rustup default nightly
```

### 构建插件

CMake 会自动从 GitHub 拉取 iceoryx2 源码并编译：

```bash
cd build
cmake .. -DAIMRT_BUILD_ICEORYX2_PLUGIN=ON
make aimrt_iceoryx2_plugin -j$(nproc)
```

首次编译会下载约 50MB 源码并编译 Rust 库，耗时约 2-5 分钟。

## 测试

```bash
# 运行单元测试
./build/AimRT/src/plugins/iceoryx2_plugin/aimrt_iceoryx2_plugin_test
```

## 与 iceoryx_plugin 对比

| 特性 | iceoryx_plugin | iceoryx2_plugin |
|------|:-------------:|:---------------:|
| 守护进程 | 需要 RouDi | ❌ 不需要 |
| 配置复杂度 | 高 | 低 |
| 性能统计 | ❌ | ✅ |
| API 抽象 | 基础 | 完善 |
| Rust 支持 | ❌ | ✅ (FFI) |

## TODO

- [x] Event/Listener 替代轮询（WaitSet 模式已实现）
- [ ] Request/Response RPC 后端
- [ ] 动态订阅/取消订阅支持
