#!/bin/bash

# Install to conda style directories
[[ -d lib64 ]] && mv lib64 lib
mkdir -p ${PREFIX}/lib
[[ -d pkg-config ]] && mv pkg-config ${PREFIX}/lib/pkgconfig
[[ -d "$PREFIX/lib/pkgconfig" ]] && sed -E -i "s|cudaroot=.+|cudaroot=$PREFIX|g" $PREFIX/lib/pkgconfig/cusparse*.pc

[[ ${target_platform} == "linux-64" ]] && targetsDir="targets/x86_64-linux"
[[ ${target_platform} == "linux-ppc64le" ]] && targetsDir="targets/ppc64le-linux"
[[ ${target_platform} == "linux-aarch64" ]] && targetsDir="targets/sbsa-linux"

for i in `ls`; do
    [[ $i == "build_env_setup.sh" ]] && continue
    [[ $i == "conda_build.sh" ]] && continue
    [[ $i == "metadata_conda_debug.yaml" ]] && continue
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
                    # Enhanced RPATH fixing only for linux-aarch64
                    if [[ ${target_platform} == "linux-aarch64" ]]; then
                        # Clear any existing RPATH first, then set to $ORIGIN
                        patchelf --remove-rpath ${PREFIX}/${targetsDir}/$j
                        patchelf --set-rpath '$ORIGIN' ${PREFIX}/${targetsDir}/$j
                    else
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
    for lib in ${PREFIX}/${targetsDir}/lib/*.so*; do
        if [[ -f "$lib" && "$lib" =~ \.so ]]; then
            rpath=$(patchelf --print-rpath "$lib" 2>/dev/null || echo "No RPATH")
            if [[ "$rpath" != "\$ORIGIN" ]]; then
                echo "WARNING: $(basename "$lib") has incorrect RPATH: $rpath"
                echo "Attempting to fix..."
                patchelf --remove-rpath "$lib"
                patchelf --set-rpath '$ORIGIN' "$lib"
            fi
        fi
    done
fi
