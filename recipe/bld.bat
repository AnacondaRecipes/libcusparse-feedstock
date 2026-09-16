if "%TARGET_PLATFORM%" == "win-arm64" (
    set CUDA_ARCH=arm64
) else (
    set CUDA_ARCH=x64
)

if not exist %PREFIX% mkdir %PREFIX%
if not exist %LIBRARY_LIB%\%CUDA_ARCH% mkdir %LIBRARY_LIB%\%CUDA_ARCH%

move lib\%CUDA_ARCH%\* %LIBRARY_LIB%\%CUDA_ARCH%
move bin\%CUDA_ARCH%\* %LIBRARY_BIN%
move include\* %LIBRARY_INC%
