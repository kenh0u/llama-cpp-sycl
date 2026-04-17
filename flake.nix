{
  description = "Standalone llama.cpp build with SYCL (oneAPI) support";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-master.url = "github:nixos/nixpkgs/0c9c74006a8a9198d5f9e98b5ffb284471cd4f4a";
  };

  outputs = { self, nixpkgs, nixpkgs-master }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs-master { 
      inherit system; 
      config.allowUnfree = true; 
    };
    lib = pkgs.lib;

  in {
    packages.${system}.default = (pkgs.llama-cpp.override {
      cudaSupport = false; 
      rpcSupport = true;
    }).overrideAttrs (old: {
      pname = "llama-cpp-sycl";
      
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
        pkgs.intel-oneapi.hpc
        pkgs.intel-oneapi.base
        pkgs.installShellFiles
        pkgs.procps
      ];

      buildInputs = (old.buildInputs or []) ++ [ 
        pkgs.level-zero
        pkgs.mkl
        pkgs.onednn
      ];

      cmakeFlags = (old.cmakeFlags or []) ++ [
        "-DGGML_SYCL=ON"
        "-DGGML_SYCL_F16=ON"
        "-DGGML_SYCL_TARGET=INTEL"
        "-DCMAKE_C_COMPILER=icx"
        "-DCMAKE_CXX_COMPILER=icpx"
        "-DLLAMA_BUILD_EXAMPLES=OFF"
        "-DLLAMA_BUILD_SERVER=ON"
      ];

      preConfigure = (old.preConfigure or "") + ''
        export PATH="${pkgs.procps}/bin:$PATH"
        source ${pkgs.intel-oneapi.base}/setvars.sh --force
        
        export GCC_TOOLCHAIN="${pkgs.stdenv.cc.cc}"
        export LIBC_INC="${pkgs.stdenv.cc.libc.dev}/include"
        export LIBC_LIB="${pkgs.stdenv.cc.libc}/lib"
        export GCC_LIB="${pkgs.stdenv.cc.cc.lib}/lib"
        export GXX_INC="${pkgs.stdenv.cc.cc}/include/c++/${lib.getVersion pkgs.stdenv.cc.cc}"
        
        # We use -isystem ONLY for the C++ headers, and -I for the glibc headers
        # to see if it fixes the include_next issue.
        export COMMON_FLAGS="--gcc-toolchain=$GCC_TOOLCHAIN -I$LIBC_INC -B$LIBC_LIB -L$LIBC_LIB -L$GCC_LIB"
        export CFLAGS="$COMMON_FLAGS $CFLAGS"
        export CXXFLAGS="$COMMON_FLAGS -isystem $GXX_INC -isystem $GXX_INC/x86_64-unknown-linux-gnu $CXXFLAGS"
        export LDFLAGS="-L$LIBC_LIB -L$GCC_LIB $LDFLAGS"
        
        export CPLUS_INCLUDE_PATH="$GXX_INC:$GXX_INC/x86_64-unknown-linux-gnu:$LIBC_INC:$CPLUS_INCLUDE_PATH"
      '';

      postInstall = ''
        ln -sf $out/bin/llama-cli $out/bin/llama
        mkdir -p $out/include
        cp $src/include/llama.h $out/include/
      '';
      
    });
  };
}
