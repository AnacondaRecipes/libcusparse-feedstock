#!/bin/bash

# Install to conda style directories
[[ -d lib64 ]] && mv lib64 lib
mkdir -p ${PREFIX}/lib
[[ -d pkg-config ]] && mv pkg-config ${PREFIX}/lib/pkgconfig
[[ -d "$PREFIX/lib/pkgconfig" ]] && sed -E -i "s|cudaroot=.+|cudaroot=$PREFIX|g" $PREFIX/lib/pkgconfig/cusparse*.pc

[[ ${target_platform} == "linux-64" ]] && targetsDir="targets/x86_64-linux"
[[ ${target_platform} == "linux-ppc64le" ]] && targetsDir="targets/ppc64le-linux"
[[ ${target_platform} == "linux-aarch64" ]] && targetsDir="targets/sbsa-linux"

echo "=== BUILD SCRIPT DEBUGGING ==="
echo "Current directory: $(pwd)"
echo "Contents: $(ls -la)"
echo "Target platform: ${target_platform}"

for i in `ls`; do
    echo "Processing: $i"
    [[ $i == "build_env_setup.sh" ]] && echo "  Skipping build_env_setup.sh" && continue
    [[ $i == "conda_build.sh" ]] && echo "  Skipping conda_build.sh" && continue
    [[ $i == "metadata_conda_debug.yaml" ]] && echo "  Skipping metadata_conda_debug.yaml" && continue
    if [[ $i == "lib" ]] || [[ $i == "include" ]]; then
        # Headers and libraries are installed to targetsDir
        mkdir -p ${PREFIX}/${targetsDir}
        mkdir -p ${PREFIX}/$i
        cp -rv $i ${PREFIX}/${targetsDir}
        if [[ $i == "lib" ]]; then
            for j in "$i"/*.so*; do
                # Shared libraries are symlinked in $PREFIX/lib
                ln -s ${PREFIX}/${targetsDir}/$j ${PREFIX}/$j

                # Fix RPATH for all shared libraries (both .so and .so.X.Y.Z files)
                if [[ $j =~ \.so ]]; then
                    echo "  Found shared library: $j"
                    # Enhanced RPATH fixing only for linux-aarch64
                    if [[ ${target_platform} == "linux-aarch64" ]]; then
                        echo "  LINUX-AARCH64: Fixing RPATH for: ${PREFIX}/${targetsDir}/$j"
                        echo "  Original RPATH: $(patchelf --print-rpath ${PREFIX}/${targetsDir}/$j 2>/dev/null || echo 'No RPATH')"
                        # Clear any existing RPATH first, then set to $ORIGIN
                        echo "  Running: patchelf --remove-rpath ${PREFIX}/${targetsDir}/$j"
                        patchelf --remove-rpath ${PREFIX}/${targetsDir}/$j 2>&1
                        echo "  Running: patchelf --set-rpath '\$ORIGIN' ${PREFIX}/${targetsDir}/$j"
                        patchelf --set-rpath '$ORIGIN' ${PREFIX}/${targetsDir}/$j 2>&1
                        # Verify the RPATH was set correctly
                        echo "  RPATH after fix: $(patchelf --print-rpath ${PREFIX}/${targetsDir}/$j 2>/dev/null || echo 'No RPATH')"
                    else
                        echo "  OTHER PLATFORM: Setting RPATH for: ${PREFIX}/${targetsDir}/$j"
                        # Standard RPATH setting for other platforms
                        patchelf --set-rpath '$ORIGIN' --force-rpath ${PREFIX}/${targetsDir}/$j
                    fi
                fi
            done
        fi
    else
        # Put all other files in targetsDir
        mkdir -p ${PREFIX}/${targetsDir}/libcusparse
        cp -rv $i ${PREFIX}/${targetsDir}/libcusparse
    fi
done

check-glibc "$PREFIX"/lib*/*.so.* "$PREFIX"/bin/* "$PREFIX"/targets/*/lib*/*.so.* "$PREFIX"/targets/*/bin/*

# Verify all shared libraries have correct RPATH (only for linux-aarch64)
if [[ ${target_platform} == "linux-aarch64" ]]; then
    echo "=== DEBUGGING RPATH ISSUES ON LINUX-AARCH64 ==="
    echo "Target platform: ${target_platform}"
    echo "Targets directory: ${targetsDir}"
    echo "PREFIX: ${PREFIX}"
    
    echo "=== LISTING ALL FILES IN TARGETS DIRECTORY ==="
    ls -la ${PREFIX}/${targetsDir}/lib/
    
    echo "=== CHECKING RPATH FOR ALL SHARED LIBRARIES ==="
    for lib in ${PREFIX}/${targetsDir}/lib/*.so*; do
        if [[ -f "$lib" ]]; then
            echo "File: $lib"
            echo "  Type: $(file "$lib")"
            echo "  Original RPATH: $(patchelf --print-rpath "$lib" 2>/dev/null || echo "No RPATH")"
            
            if [[ "$lib" =~ \.so ]]; then
                echo "  Attempting to fix RPATH..."
                echo "  Command: patchelf --remove-rpath '$lib'"
                patchelf --remove-rpath "$lib" 2>&1
                echo "  Command: patchelf --set-rpath '\$ORIGIN' '$lib'"
                patchelf --set-rpath '$ORIGIN' "$lib" 2>&1
                echo "  Final RPATH: $(patchelf --print-rpath "$lib" 2>/dev/null || echo "No RPATH")"
                echo "  ---"
            fi
        fi
    done
    
    echo "=== FINAL RPATH VERIFICATION ==="
    for lib in ${PREFIX}/${targetsDir}/lib/*.so*; do
        if [[ -f "$lib" && "$lib" =~ \.so ]]; then
            rpath=$(patchelf --print-rpath "$lib" 2>/dev/null || echo "No RPATH")
            echo "Final RPATH for $(basename "$lib"): $rpath"
            if [[ "$rpath" != "\$ORIGIN" ]]; then
                echo "ERROR: $(basename "$lib") still has incorrect RPATH: $rpath"
                echo "Attempting aggressive fix..."
                patchelf --remove-rpath "$lib" 2>&1
                patchelf --set-rpath '$ORIGIN' "$lib" 2>&1
                echo "After aggressive fix: $(patchelf --print-rpath "$lib" 2>/dev/null || echo "No RPATH")"
            fi
        fi
    done
    echo "=== END DEBUGGING ==="
fi
