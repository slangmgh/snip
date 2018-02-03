# Package

version       = "0.1.0"
author        = "genotrance"
description   = "Text editor to speed up testing code snippets"
license       = "MIT"

bin = @["snip"]
srcDir = "src"
skipExt = @["nim"]

# Dependencies

requires "nim >= 0.16.0"

task release, "Build release binary":
    exec "nim c -d:release -o:snip -d:VERSION=v" & version & " --opt:size src/snip.nim"
    exec "sleep 1"
    exec "strip -s snip.exe"
    exec "upx --best snip.exe"

task key, "Build key":
    exec "nim c -o:key src/snip/key.nim"

task buildmap, "Build buildmap":
    exec "nim c -o:buildmap src/snip/buildmap.nim"

task test, "Test snip":
    exec "nim c tests/sniptest.nim"