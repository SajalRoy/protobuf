setlocal

pip install wheel

REM Checkout release commit
cd %REPO_DIR%
git checkout %BUILD_COMMIT%

REM ======================
REM Build Protobuf Library
REM ======================

mkdir src\.libs
pushd src\.libs

IF %PYTHON_VERSION%==2.7 GOTO build_core_mingw
IF %PYTHON_VERSION%==3.4 GOTO build_core_mingw
IF %PYTHON_VERSION%==3.5 GOTO build_core_msvc
IF %PYTHON_VERSION%==3.6 GOTO build_core_msvc

:build_core_mingw
cmake -G "%generator%" -Dprotobuf_BUILD_SHARED_LIBS=%BUILD_DLL% -Dprotobuf_UNICODE=%UNICODE% -DZLIB_ROOT=%ZLIB_ROOT% -Dprotobuf_BUILD_TESTS=OFF -D"CMAKE_MAKE_PROGRAM:PATH=%MINGW%/mingw32-make.exe" ../../cmake
mingw32-make
GOTO build_core_end

:build_core_msvc
cmake -G "%generator%" -Dprotobuf_BUILD_SHARED_LIBS=%BUILD_DLL% -Dprotobuf_UNICODE=%UNICODE% -Dprotobuf_BUILD_TESTS=OFF ../../cmake
msbuild protobuf.sln /p:Platform=%vcplatform% /p:Configuration=Release /logger:"C:\Program Files\AppVeyor\BuildAgent\Appveyor.MSBuildLogger.dll"
dir /s /b
copy Release\libprotobuf.lib libprotobuf.a
copy Release\libprotobuf-lite.lib libprotobuf-lite.a
GOTO build_core_end

:build_core_end
popd

REM ======================
REM Build python library
REM ======================

cd python

REM https://github.com/Theano/Theano/issues/4926
sed -i '/Wno-sign-compare/a \ \ \ \ extra_compile_args.append(\'-D_hypot=hypot\')' setup.py
sed -i 's/\'-DPYTHON_PROTO2_CPP_IMPL_V2\'/\'-DPYTHON_PROTO2_CPP_IMPL_V2\',\'-D_hypot=hypot\'/g' setup.py

REM https://github.com/tpaviot/pythonocc-core/issues/48
IF NOT %PYTHON_ARCH%==64 GOTO no_win64_change
sed -i '/Wno-sign-compare/a \ \ \ \ extra_compile_args.append(\'-DMS_WIN64\')' setup.py
sed -i 's/\'-DPYTHON_PROTO2_CPP_IMPL_V2\'/\'-DPYTHON_PROTO2_CPP_IMPL_V2\',\'-DMS_WIN64\'/g' setup.py
:no_win64_change

REM MSVS default is dymanic
IF NOT DEFINED vcplatform GOTO msvc_static_build_end
sed -i '/Wno-sign-compare/a \ \ \ \ extra_compile_args.append(\'/MT\')' setup.py
sed -i 's/\'-DPYTHON_PROTO2_CPP_IMPL_V2\'/\'-DPYTHON_PROTO2_CPP_IMPL_V2\',\'\/MT\'/g' setup.py
:msvc_static_build_end

REM MSVC doesn't recognize these options
IF NOT DEFINED vcplatform GOTO msvc_remove_flags_end
sed -i '/-Wno-write-strings/c\    extra_compile_args = []' setup.py
sed -i '/-Wno-invalid-offsetof/d' setup.py
sed -i '/-Wno-sign-compare/d' setup.py
:msvc_remove_flags_end

cat setup.py
python setup.py bdist_wheel --cpp_implementation --compile_static_extension
cd ..\..
