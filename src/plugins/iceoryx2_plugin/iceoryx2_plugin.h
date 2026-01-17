// Copyright (c) 2024, SmartCar Project
// Iceoryx2 Plugin for AimRT - Zero-copy IPC using Iceoryx2

#pragma once

#include <atomic>
#include <vector>

#include "aimrt_core_plugin_interface/aimrt_core_plugin_base.h"
#include "runtime/core/aimrt_core.h"

namespace aimrt::plugins::iceoryx2_plugin {

// Forward declaration
class Iceoryx2ChannelBackend;

class Iceoryx2Plugin : public AimRTCorePluginBase {
 public:
  struct Options {
    // Shared memory configuration
    uint64_t shm_init_size = 16 * 1024 * 1024;  // 16MB default
    uint64_t max_slice_len = 4 * 1024 * 1024;   // 4MB default per message

    // Allocation strategy: "static", "dynamic", "power_of_two"
    // TODO: Currently only "dynamic" is implemented
    std::string allocation_strategy = "dynamic";

    // Node name for process isolation (default: "aimrt_iox2_{pid}")
    std::string node_name;

    // Listener thread configuration
    std::string listener_thread_name;
    std::string listener_thread_sched_policy;        // e.g., "SCHED_FIFO", "SCHED_RR"
    std::vector<uint32_t> listener_thread_bind_cpu;  // CPU affinity

    // Event-based mode (WaitSet) vs polling mode
    bool use_event_mode = true;
  };

 public:
  Iceoryx2Plugin() = default;
  ~Iceoryx2Plugin() override = default;

  std::string_view Name() const noexcept override { return "iceoryx2_plugin"; }

  bool Initialize(runtime::core::AimRTCore* core_ptr) noexcept override;
  void Shutdown() noexcept override;

 private:
  void SetPluginLogger();
  void RegisterIceoryx2ChannelBackend();

 private:
  runtime::core::AimRTCore* core_ptr_ = nullptr;

  Options options_;

  bool init_flag_ = false;

  std::atomic_bool stop_flag_ = false;
};

}  // namespace aimrt::plugins::iceoryx2_plugin
