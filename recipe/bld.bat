if not exist %PREFIX% mkdir %PREFIX%
if not exist %LIBRARY_LIB%\x64 mkdir %LIBRARY_LIB%\x64

move lib\x64\* %LIBRARY_LIB%\x64
move bin\x64\* %LIBRARY_BIN%
move include\* %LIBRARY_INC%
