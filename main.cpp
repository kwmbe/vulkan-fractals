#include <vulkan/vulkan_raii.hpp>
#include <GLFW/glfw3.h>

#include <iostream>
#include <stdexcept>
#include <cstdlib>

constexpr uint32_t WIDTH = 800;
constexpr uint32_t HEIGHT = 600;

const std::vector<char const*> validationLayers = {
  "VK_LAYER_KHRONOS_validation"
};

#ifdef NDEBUG
constexpr bool enableValidationLayers = false;
#else
constexpr bool enableValidationLayers = true;
#endif

class HelloTriangleApplication {
public:
  void run() {
    initWindow();
    initVulkan();
    mainLoop();
    cleanup();
  }

private:
  vk::raii::Context                context;
  vk::raii::Instance               instance =       nullptr;
  vk::raii::DebugUtilsMessengerEXT debugMessenger = nullptr;

  GLFWwindow* window = nullptr;

  std::vector<const char*> requiredDeviceExtensions = {
    vk::KHRSwapchainExtensionName,
    vk::KHRSpirv14ExtensionName,
    vk::KHRSynchronization2ExtensionName,
    vk::KHRCreateRenderpass2ExtensionName
  };

  void initWindow() {
    glfwInit();
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);

    window = glfwCreateWindow(WIDTH, HEIGHT, "Vulkan", nullptr, nullptr);
  }

  void initVulkan() {
    createInstance();
    setupDebugMessenger();
    pickPhysicalDevice();
  }

  void createInstance() {
    constexpr vk::ApplicationInfo appInfo{
      .pApplicationName =   "Hello Triangle",
      .applicationVersion = VK_MAKE_VERSION( 1, 0, 0 ),
      .pEngineName =        "No Engine",
      .engineVersion =      VK_MAKE_VERSION( 1, 0, 0 ),
      .apiVersion =         vk::ApiVersion
    };

    // Get validation layers
    std::vector<char const*> requiredLayers;
    if (enableValidationLayers) {
      requiredLayers.assign(validationLayers.begin(), validationLayers.end());
    }

    // Check if layers are supported
    auto layerProperties = context.enumerateInstanceLayerProperties();
    if (std::ranges::any_of(
      requiredLayers,
      [&layerProperties](auto const& requiredLayer) {
        return std::ranges::none_of(
          layerProperties,
          [requiredLayer] (auto const& layerProperty) {
            return strcmp(layerProperty.layerName, requiredLayer) == 0;
          }
        );
      }
    )) {
      throw std::runtime_error("One or more required layers are not supported!");
    }

    // Get required extensions
    auto requiredExtensions =  getRequiredExtensions();
    auto extensionProperties = context.enumerateInstanceExtensionProperties();

    // Print extensions
    std::cout << "available extensions:\n";

    for (const auto& extension : extensionProperties) {
        std::cout << '\t' << extension.extensionName << '\n';
    }

    // Check if extensions are supported
    for (const auto& extension : requiredExtensions) {
      if (std::ranges::none_of(
        extensionProperties,
        [extension] (auto const& extensionProperty) { return strcmp(extensionProperty.extensionName, extension) == 0; }
      )) {
        throw std::runtime_error("Required GLFW extensions not supported: " + std::string(extension));
      }
    }

    vk::InstanceCreateInfo createInfo{
      .pApplicationInfo =        &appInfo,
      .enabledLayerCount =       static_cast<uint32_t>(requiredLayers.size()),
      .ppEnabledLayerNames =     requiredLayers.data(),
      .enabledExtensionCount =   static_cast<uint32_t>(requiredExtensions.size()),
      .ppEnabledExtensionNames = requiredExtensions.data()
    };

    instance = vk::raii::Instance(context, createInfo);
  }

  std::vector<const char*> getRequiredExtensions() {
    uint32_t glfwExtensionCount = 0;
    auto glfwExtensions =         glfwGetRequiredInstanceExtensions(&glfwExtensionCount);

    std::vector extensions(glfwExtensions, glfwExtensions + glfwExtensionCount);
    if (enableValidationLayers) {
      extensions.push_back(vk::EXTDebugUtilsExtensionName);
    }

    return extensions;
  }

  static VKAPI_ATTR vk::Bool32 VKAPI_CALL debugCallback(vk::DebugUtilsMessageSeverityFlagBitsEXT severity, vk::DebugUtilsMessageTypeFlagsEXT type, const vk::DebugUtilsMessengerCallbackDataEXT* pCallbackData, void*) {
    // explanation for configuration at: https://docs.vulkan.org/tutorial/latest/03_Drawing_a_triangle/00_Setup/02_Validation_layers.html#_message_callback
    std::cerr << "validation layer: type " << to_string(type) << " msg: " << pCallbackData->pMessage << std::endl;

    return vk::False;
  }

  void setupDebugMessenger() {
    if (!enableValidationLayers) return;

    vk::DebugUtilsMessageSeverityFlagsEXT severityFlags( vk::DebugUtilsMessageSeverityFlagBitsEXT::eVerbose | vk::DebugUtilsMessageSeverityFlagBitsEXT::eWarning | vk::DebugUtilsMessageSeverityFlagBitsEXT::eError  );
    vk::DebugUtilsMessageTypeFlagsEXT     messageTypeFlags( vk::DebugUtilsMessageTypeFlagBitsEXT::eGeneral  | vk::DebugUtilsMessageTypeFlagBitsEXT::ePerformance | vk::DebugUtilsMessageTypeFlagBitsEXT::eValidation );
    vk::DebugUtilsMessengerCreateInfoEXT  debugUtilsMessengerCreateInfoEXT{
      .messageSeverity = severityFlags,
      .messageType = messageTypeFlags,
      .pfnUserCallback = &debugCallback
      };
    debugMessenger = instance.createDebugUtilsMessengerEXT(debugUtilsMessengerCreateInfoEXT);
  }

  void pickPhysicalDevice() {
    vk::raii::PhysicalDevice physicalDevice = nullptr;

    auto devices = instance.enumeratePhysicalDevices();

    if (devices.empty()) {
      throw std::runtime_error("failed to find GPUs with Vulkan support!");
    }

    const auto devIter = std::ranges::find_if(
      devices,
      [&](const auto& device) {
        if (isDeviceSuitable(device)) {
          physicalDevice = device;
          return true;
        }
        return false;
      }
    );

    if (devIter == devices.end()) {
      throw std::runtime_error("failed to find a suitable GPU!");
    }
  }

  bool isDeviceSuitable(vk::raii::PhysicalDevice device) {
    auto queueFamilies = device.getQueueFamilyProperties();
    bool isSuitable =    device.getProperties().apiVersion >= VK_API_VERSION_1_3;
    const auto qfpIter = std::ranges::find_if( queueFamilies, [](vk::QueueFamilyProperties const & qfp) {
      return (qfp.queueFlags & vk::QueueFlagBits::eGraphics) != static_cast<vk::QueueFlags>(0);
    });

    isSuitable = isSuitable && (qfpIter != queueFamilies.end());

    auto extensions = device.enumerateDeviceExtensionProperties();
    bool found =      true;

    for (const auto& extension : requiredDeviceExtensions) {
      auto extensionIter = std::ranges::find_if(extensions, [extension](const auto& ext) { return strcmp(ext.extensionName, extension) == 0; });
      found = found && extensionIter != extensions.end();
    }

    return isSuitable && found;
  }

  void mainLoop() {
    while (!glfwWindowShouldClose(window)) {
      glfwPollEvents();
    }
  }

  void cleanup() {
    glfwDestroyWindow(window);
    glfwTerminate();
  }
};

int main() {
  HelloTriangleApplication app;

  try {
    app.run();
  } catch (const std::exception& e) {
    std::cerr << e.what() << std::endl;
    return EXIT_FAILURE;
  }

  return EXIT_SUCCESS;
}
