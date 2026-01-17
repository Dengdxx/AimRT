// Copyright (c) 2024, SmartCar Project
// Iceoryx2 Plugin for AimRT - Channel Backend (Simplified)

#pragma once

#include <atomic>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

#if defined(_WIN32)
  #include <windows.h>
#else
  #include <unistd.h>
#endif

#include "core/channel/channel_backend_base.h"
#include "core/channel/channel_backend_tools.h"
#include "iceoryx2_plugin/iceoryx2_publisher.h"
#include "iceoryx2_plugin/iceoryx2_subscriber.h"
#include "iox2/iceoryx2.hpp"

namespace aimrt::plugins::iceoryx2_plugin {

// Default configuration constants
static constexpr uint64_t kDefaultMaxSliceLen = 4 * 1024 * 1024;  // 4MB
static constexpr size_t kMaxMsgsPerSubscriberPerPoll = 64;

class Iceoryx2ChannelBackend : public runtime::core::channel::ChannelBackendBase {
 public:
  struct Options {
    uint64_t max_slice_len = kDefaultMaxSliceLen;
    std::string allocation_strategy = "dynamic";
    std::string node_name;
    std::string listener_thread_name;
    std::string listener_thread_sched_policy;
    std::vector<uint32_t> listener_thread_bind_cpu;
    bool use_event_mode = true;
  };

 public:
  Iceoryx2ChannelBackend() = default;
  ~Iceoryx2ChannelBackend() override;

  std::string_view Name() const noexcept override { return "iceoryx2"; }

  void Initialize(YAML::Node options_node) override;
  void Start() override;
  void Shutdown() override;

  void SetChannelRegistry(const runtime::core::channel::ChannelRegistry* channel_registry_ptr) noexcept override {
    channel_registry_ptr_ = channel_registry_ptr;
  }

  void SetOptions(const Options& options) noexcept { options_ = options; }

  bool RegisterPublishType(
      const runtime::core::channel::PublishTypeWrapper& publish_type_wrapper) noexcept override;
  bool Subscribe(const runtime::core::channel::SubscribeWrapper& subscribe_wrapper) noexcept override;
  void Publish(runtime::core::channel::MsgWrapper& msg_wrapper) noexcept override;

 private:
  enum class State : uint32_t { kPreInit,
                                kInit,
                                kStart,
                                kShutdown };

  Options options_;
  std::atomic<State> state_ = State::kPreInit;
  const runtime::core::channel::ChannelRegistry* channel_registry_ptr_ = nullptr;

  // Iceoryx2 Node - directly managed, no manager layer needed (iox2 has no RouDi)
  std::optional<iox2::Node<iox2::ServiceType::Ipc>> node_;

  // Publishers - wrapped for clean API
  std::mutex pub_mtx_;
  std::unordered_map<std::string, std::unique_ptr<Iox2Publisher>> publishers_;

  // Subscribers - wrapped for clean API
  std::mutex sub_mtx_;
  std::unordered_map<std::string, std::unique_ptr<Iox2Subscriber>> subscribers_;

  // Subscriber callback data
  struct SubscriberData {
    std::unique_ptr<runtime::core::channel::SubscribeTool> tool;
    std::string default_serialization_type;
  };
  std::unordered_map<std::string, SubscriberData> subscriber_data_;

  // WaitSet for event-based mode
  std::optional<iox2::WaitSet<iox2::ServiceType::Ipc>> waitset_;

  struct WaitSetEntry {
    iox2::WaitSetGuard<iox2::ServiceType::Ipc> guard;
    std::string url;
  };
  std::vector<WaitSetEntry> waitset_entries_;

  // Polling/Event loop thread
  std::atomic<bool> running_{false};
  std::thread poller_thread_;
  void ConfigureListenerThread();
  void PollingThreadFunc();
  void EventLoopFunc();

  // Stats aggregation
  Iox2Stats pub_stats_;
  Iox2Stats sub_stats_;
};

}  // namespace aimrt::plugins::iceoryx2_plugin
