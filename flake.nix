{
  description = "Standalone llama.cpp build with SYCL (oneAPI) support in FHS environment";

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

    # 1. The "unwrapped" llama.cpp build
    llama-cpp-sycl-unwrapped = (pkgs.llama-cpp.override {
      cudaSupport = false; 
      rpcSupport = true;
    }).overrideAttrs (old: {
      pname = "llama-cpp-sycl-unwrapped";
      
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
        pkgs.intel-compute-runtime
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
        
        # Base flags for both C and C++
        export BASE_FLAGS="--gcc-toolchain=$GCC_TOOLCHAIN -B$LIBC_LIB -L$LIBC_LIB -L$GCC_LIB"
        
        # C flags: Just need glibc headers
        export CFLAGS="$BASE_FLAGS -isystem $LIBC_INC $CFLAGS"
        
        # C++ flags: GCC headers MUST come BEFORE glibc headers for include_next to work
        export CXXFLAGS="$BASE_FLAGS -isystem $GXX_INC -isystem $GXX_INC/x86_64-unknown-linux-gnu -isystem $LIBC_INC $CXXFLAGS"
        
        export LDFLAGS="-L$LIBC_LIB -L$GCC_LIB $LDFLAGS"
        
        # Do NOT set C_INCLUDE_PATH or CPLUS_INCLUDE_PATH as they can interfere with 
        # the compiler's internal headers (like stdatomic.h)
        unset C_INCLUDE_PATH
        unset CPLUS_INCLUDE_PATH
      '';

      postInstall = ''
        ln -sf $out/bin/llama-cli $out/bin/llama
        mkdir -p $out/include
        cp $src/include/llama.h $out/include/
      '';
    });

  in {
    packages.${system} = {
      inherit llama-cpp-sycl-unwrapped;
      
      default = pkgs.buildFHSEnv {
        name = "llama-cpp-sycl";
        
        targetPkgs = pkgs: with pkgs; [
          llama-cpp-sycl-unwrapped
          
          # Runtime Intel OneAPI dependencies
          intel-oneapi.base
          intel-oneapi.hpc
          intel-compute-runtime
          level-zero
          mkl
          onednn
          
          # System libraries and tools
          zlib
        ];

        profile = ''
          export ONEAPI_ROOT=/usr
          export LD_LIBRARY_PATH=${pkgs.intel-compute-runtime}/lib:$LD_LIBRARY_PATH
          export UR_L0_ENABLE_RELAXED_ALLOCATION_LIMITS=1
          export ZES_ENABLE_SYSMAN=1
        '';

        runScript = "bash";

        extraInstallCommands = ''
          mkdir -p $out/bin
          for f in ${llama-cpp-sycl-unwrapped}/bin/*; do
            ln -s $f $out/bin/$(basename $f)
          done
        '';
      };
    };
  };
}
