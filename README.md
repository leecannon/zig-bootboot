# zig-bootboot

This repo contains a zig'ified [BOOTBOOT](https://gitlab.com/bztsrc/bootboot) header file.

## How to use

Download the repo somehow then either:

### Use a package manager

* [zigmod](https://github.com/nektro/zigmod)
* [zkg](https://github.com/mattnite/zkg)

### Add as package in `build.zig`

* To `build.zig` add:
  
   ```zig
   exe.addPackagePath("bootboot", "zig-bootboot/bootboot.zig"); // or whatever the path is
   ```
* Then the package is available within any zig file:
  
   ```zig
   const bootboot = @import("bootboot");
   ```

### Import directly

In any zig file add:
```zig
const bootboot = @import("../zig-bootboot/bootboot.zig"); // or whatever the path is from *that* file
```
