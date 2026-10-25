#!/usr/bin/env bash
# Builds the llama.cpp server that powers Inklet's built-in local models.
# Prints the path of the built binary. The build is cached per pinned revision.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
llama_cpp_tag="v0.7.0"
llama_cpp_revision="620d2225cc436ab0b001e3200e590e3b286ef9ab"
cache_dir="${INKLET_LLAMA_CPP_CACHE_DIR:-${repo_root}/.build/llama.cpp}"
source_dir="${cache_dir}/source-${llama_cpp_revision}"
build_dir="${cache_dir}/build-${llama_cpp_revision}"
binary_path="${build_dir}/bin/llama-server"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "The built-in engine is built only on Apple silicon Macs." >&2
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake is required to build the built-in engine. Install it with: brew install cmake" >&2
  exit 1
fi

if [[ -x "$binary_path" ]]; then
  echo "$binary_path"
  exit 0
fi

if [[ ! -d "${source_dir}/.git" ]]; then
  rm -rf "$source_dir"
  mkdir -p "$cache_dir"
  git clone --quiet --depth 1 --branch "$llama_cpp_tag" \
    https://github.com/ggml-org/llama.cpp.git "$source_dir" >&2
fi

actual_revision="$(git -C "$source_dir" rev-parse HEAD)"
if [[ "$actual_revision" != "$llama_cpp_revision" ]]; then
  echo "llama.cpp ${llama_cpp_tag} resolved to ${actual_revision}, expected ${llama_cpp_revision}." >&2
  exit 1
fi

# A single static binary with the Metal shaders embedded, so the app bundle needs no extra libraries.
cmake -S "$source_dir" -B "$build_dir" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DBUILD_SHARED_LIBS=OFF \
  -DGGML_METAL=ON \
  -DGGML_METAL_EMBED_LIBRARY=ON \
  -DGGML_NATIVE=OFF \
  -DLLAMA_BUILD_SERVER=ON \
  -DLLAMA_BUILD_TOOLS=ON \
  -DLLAMA_BUILD_APP=OFF \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_UI=OFF \
  -DLLAMA_USE_PREBUILT_UI=OFF \
  -DLLAMA_OPENSSL=OFF \
  -DLLAMA_ALL_WARNINGS=OFF \
  -DLLAMA_BUILD_IS_DEV=OFF >&2
cmake --build "$build_dir" --config Release --target llama-server -j "$(sysctl -n hw.ncpu)" >&2

if [[ ! -x "$binary_path" ]]; then
  echo "Missing built llama-server: ${binary_path}" >&2
  exit 1
fi

echo "$binary_path"
