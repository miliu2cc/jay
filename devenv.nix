{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  # 编译期链接的本地库，见 book/src/installation.md。
  # 源码中对应 #[link(name = ...)] / crate 的链接需求：
  #   fontconfig        -> fontconfig
  #   libinput/sys.rs   -> input
  #   pango.rs          -> cairo / pangocairo-1.0 / gobject-2.0 / pango-1.0
  #   video/gbm.rs      -> gbm
  #   udev.rs           -> udev
  buildLibs = with pkgs; [
    fontconfig
    libgbm
    libinput
    pango
    udev
    xkeyboard-config
  ];

  # 运行期通过 dlopen 动态加载的可选依赖：
  #   src/gfx_apis/gl/egl/sys.rs       -> libEGL.so.1 / libGLESv2.so.2（OpenGL 后端）
  #   src/vulkan_core.rs               -> libvulkan.so.1（Vulkan 后端）
  #   src/sqlite/sqlite_sys.rs         -> libsqlite3.so.0（会话管理）
  runtimeLibs = with pkgs; [
    libglvnd
    vulkan-loader
    sqlite
  ];
in
{
  # 项目使用 edition 2024 + resolver 3，并且直接使用了标准库的
  #   - std::ffi::VaList（c_variadic）
  #   - Box::into_non_null（box_vec_non_null）
  # 这两个 API 在 nixpkgs 当前的 rustc 1.98.1 里仍是 unstable，会报 E0658；
  # 它们要到 1.99.0 才稳定。因此必须用 rust-overlay 的 stable（1.99.0），
  # 而不是 nixpkgs 里的 rustc。devenv 会自动引入 rust-overlay 输入。
 # 1.99.0
  languages.rust = {
    enable = true;
    channel = "beta";
    version = "latest";
  };
  # 默认组件即 rustc/cargo/clippy/rustfmt/rust-analyzer；如需 rust-src 需通过
  # languages.rust.toolchain.rust-src 单独指定，见 devenv 的 rust 模块。

  # 关键修复：提供 C 编译器/linker（cc）以及 gnumake、pkg-config。
  # 只启用 languages.rust 时，rust 模块也会 mkDefault 打开 languages.c，
  # 这里显式声明，确保 linker `cc` not found 不再出现。
  languages.c.enable = true;

  packages = [
    pkgs.git
    pkgs.pkgconf # pkg-config，供 cargo build script 探测系统库
    pkgs.shaderc # compile-shaders/shaderc-sys 通过 pkg-config probe("shaderc")
  ]
  ++ buildLibs
  ++ runtimeLibs;

  # devenv 将 packages 合并进 mkShell 的 buildInputs，
  # 因此 PKG_CONFIG_PATH / NIX_CFLAGS_COMPILE / NIX_LDFLAGS 会自动包含上述库，
  # cargo 生成的可执行文件也会带有指向 devenv-shell-env/lib 的 rpath，
  # 运行期无需再手动设置 LD_LIBRARY_PATH。
}
