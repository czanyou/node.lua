# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 2.8

#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:

# Remove some rules from gmake that .SUFFIXES does not remove.
SUFFIXES =

.SUFFIXES: .hpux_make_needs_suffix_list

# Suppress display of executed commands.
$(VERBOSE).SILENT:

# A target that is always out of date.
cmake_force:
.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/bin/cmake

# The command to remove a file.
RM = /usr/bin/cmake -E remove -f

# Escaping for special characters.
EQUALS = =

# The program to use to edit the cache.
CMAKE_EDIT_COMMAND = /usr/bin/ccmake

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /mnt/c/work/node.lua.tour/modules/deps/ubus

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /mnt/c/work/node.lua.tour/modules/deps/build/ubus

# Include any dependencies generated for this target.
include CMakeFiles/ubus.dir/depend.make

# Include the progress variables for this target.
include CMakeFiles/ubus.dir/progress.make

# Include the compile flags for this target's objects.
include CMakeFiles/ubus.dir/flags.make

CMakeFiles/ubus.dir/libubus.c.o: CMakeFiles/ubus.dir/flags.make
CMakeFiles/ubus.dir/libubus.c.o: /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus.c
	$(CMAKE_COMMAND) -E cmake_progress_report /mnt/c/work/node.lua.tour/modules/deps/build/ubus/CMakeFiles $(CMAKE_PROGRESS_1)
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Building C object CMakeFiles/ubus.dir/libubus.c.o"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -o CMakeFiles/ubus.dir/libubus.c.o   -c /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus.c

CMakeFiles/ubus.dir/libubus.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/ubus.dir/libubus.c.i"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -E /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus.c > CMakeFiles/ubus.dir/libubus.c.i

CMakeFiles/ubus.dir/libubus.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/ubus.dir/libubus.c.s"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -S /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus.c -o CMakeFiles/ubus.dir/libubus.c.s

CMakeFiles/ubus.dir/libubus.c.o.requires:
.PHONY : CMakeFiles/ubus.dir/libubus.c.o.requires

CMakeFiles/ubus.dir/libubus.c.o.provides: CMakeFiles/ubus.dir/libubus.c.o.requires
	$(MAKE) -f CMakeFiles/ubus.dir/build.make CMakeFiles/ubus.dir/libubus.c.o.provides.build
.PHONY : CMakeFiles/ubus.dir/libubus.c.o.provides

CMakeFiles/ubus.dir/libubus.c.o.provides.build: CMakeFiles/ubus.dir/libubus.c.o

CMakeFiles/ubus.dir/libubus-io.c.o: CMakeFiles/ubus.dir/flags.make
CMakeFiles/ubus.dir/libubus-io.c.o: /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-io.c
	$(CMAKE_COMMAND) -E cmake_progress_report /mnt/c/work/node.lua.tour/modules/deps/build/ubus/CMakeFiles $(CMAKE_PROGRESS_2)
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Building C object CMakeFiles/ubus.dir/libubus-io.c.o"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -o CMakeFiles/ubus.dir/libubus-io.c.o   -c /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-io.c

CMakeFiles/ubus.dir/libubus-io.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/ubus.dir/libubus-io.c.i"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -E /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-io.c > CMakeFiles/ubus.dir/libubus-io.c.i

CMakeFiles/ubus.dir/libubus-io.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/ubus.dir/libubus-io.c.s"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -S /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-io.c -o CMakeFiles/ubus.dir/libubus-io.c.s

CMakeFiles/ubus.dir/libubus-io.c.o.requires:
.PHONY : CMakeFiles/ubus.dir/libubus-io.c.o.requires

CMakeFiles/ubus.dir/libubus-io.c.o.provides: CMakeFiles/ubus.dir/libubus-io.c.o.requires
	$(MAKE) -f CMakeFiles/ubus.dir/build.make CMakeFiles/ubus.dir/libubus-io.c.o.provides.build
.PHONY : CMakeFiles/ubus.dir/libubus-io.c.o.provides

CMakeFiles/ubus.dir/libubus-io.c.o.provides.build: CMakeFiles/ubus.dir/libubus-io.c.o

CMakeFiles/ubus.dir/libubus-obj.c.o: CMakeFiles/ubus.dir/flags.make
CMakeFiles/ubus.dir/libubus-obj.c.o: /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-obj.c
	$(CMAKE_COMMAND) -E cmake_progress_report /mnt/c/work/node.lua.tour/modules/deps/build/ubus/CMakeFiles $(CMAKE_PROGRESS_3)
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Building C object CMakeFiles/ubus.dir/libubus-obj.c.o"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -o CMakeFiles/ubus.dir/libubus-obj.c.o   -c /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-obj.c

CMakeFiles/ubus.dir/libubus-obj.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/ubus.dir/libubus-obj.c.i"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -E /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-obj.c > CMakeFiles/ubus.dir/libubus-obj.c.i

CMakeFiles/ubus.dir/libubus-obj.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/ubus.dir/libubus-obj.c.s"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -S /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-obj.c -o CMakeFiles/ubus.dir/libubus-obj.c.s

CMakeFiles/ubus.dir/libubus-obj.c.o.requires:
.PHONY : CMakeFiles/ubus.dir/libubus-obj.c.o.requires

CMakeFiles/ubus.dir/libubus-obj.c.o.provides: CMakeFiles/ubus.dir/libubus-obj.c.o.requires
	$(MAKE) -f CMakeFiles/ubus.dir/build.make CMakeFiles/ubus.dir/libubus-obj.c.o.provides.build
.PHONY : CMakeFiles/ubus.dir/libubus-obj.c.o.provides

CMakeFiles/ubus.dir/libubus-obj.c.o.provides.build: CMakeFiles/ubus.dir/libubus-obj.c.o

CMakeFiles/ubus.dir/libubus-sub.c.o: CMakeFiles/ubus.dir/flags.make
CMakeFiles/ubus.dir/libubus-sub.c.o: /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-sub.c
	$(CMAKE_COMMAND) -E cmake_progress_report /mnt/c/work/node.lua.tour/modules/deps/build/ubus/CMakeFiles $(CMAKE_PROGRESS_4)
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Building C object CMakeFiles/ubus.dir/libubus-sub.c.o"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -o CMakeFiles/ubus.dir/libubus-sub.c.o   -c /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-sub.c

CMakeFiles/ubus.dir/libubus-sub.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/ubus.dir/libubus-sub.c.i"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -E /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-sub.c > CMakeFiles/ubus.dir/libubus-sub.c.i

CMakeFiles/ubus.dir/libubus-sub.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/ubus.dir/libubus-sub.c.s"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -S /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-sub.c -o CMakeFiles/ubus.dir/libubus-sub.c.s

CMakeFiles/ubus.dir/libubus-sub.c.o.requires:
.PHONY : CMakeFiles/ubus.dir/libubus-sub.c.o.requires

CMakeFiles/ubus.dir/libubus-sub.c.o.provides: CMakeFiles/ubus.dir/libubus-sub.c.o.requires
	$(MAKE) -f CMakeFiles/ubus.dir/build.make CMakeFiles/ubus.dir/libubus-sub.c.o.provides.build
.PHONY : CMakeFiles/ubus.dir/libubus-sub.c.o.provides

CMakeFiles/ubus.dir/libubus-sub.c.o.provides.build: CMakeFiles/ubus.dir/libubus-sub.c.o

CMakeFiles/ubus.dir/libubus-req.c.o: CMakeFiles/ubus.dir/flags.make
CMakeFiles/ubus.dir/libubus-req.c.o: /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-req.c
	$(CMAKE_COMMAND) -E cmake_progress_report /mnt/c/work/node.lua.tour/modules/deps/build/ubus/CMakeFiles $(CMAKE_PROGRESS_5)
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Building C object CMakeFiles/ubus.dir/libubus-req.c.o"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -o CMakeFiles/ubus.dir/libubus-req.c.o   -c /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-req.c

CMakeFiles/ubus.dir/libubus-req.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/ubus.dir/libubus-req.c.i"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -E /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-req.c > CMakeFiles/ubus.dir/libubus-req.c.i

CMakeFiles/ubus.dir/libubus-req.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/ubus.dir/libubus-req.c.s"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -S /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-req.c -o CMakeFiles/ubus.dir/libubus-req.c.s

CMakeFiles/ubus.dir/libubus-req.c.o.requires:
.PHONY : CMakeFiles/ubus.dir/libubus-req.c.o.requires

CMakeFiles/ubus.dir/libubus-req.c.o.provides: CMakeFiles/ubus.dir/libubus-req.c.o.requires
	$(MAKE) -f CMakeFiles/ubus.dir/build.make CMakeFiles/ubus.dir/libubus-req.c.o.provides.build
.PHONY : CMakeFiles/ubus.dir/libubus-req.c.o.provides

CMakeFiles/ubus.dir/libubus-req.c.o.provides.build: CMakeFiles/ubus.dir/libubus-req.c.o

CMakeFiles/ubus.dir/libubus-acl.c.o: CMakeFiles/ubus.dir/flags.make
CMakeFiles/ubus.dir/libubus-acl.c.o: /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-acl.c
	$(CMAKE_COMMAND) -E cmake_progress_report /mnt/c/work/node.lua.tour/modules/deps/build/ubus/CMakeFiles $(CMAKE_PROGRESS_6)
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Building C object CMakeFiles/ubus.dir/libubus-acl.c.o"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -o CMakeFiles/ubus.dir/libubus-acl.c.o   -c /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-acl.c

CMakeFiles/ubus.dir/libubus-acl.c.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing C source to CMakeFiles/ubus.dir/libubus-acl.c.i"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -E /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-acl.c > CMakeFiles/ubus.dir/libubus-acl.c.i

CMakeFiles/ubus.dir/libubus-acl.c.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling C source to assembly CMakeFiles/ubus.dir/libubus-acl.c.s"
	mipsel-openwrt-linux-gcc  $(C_DEFINES) $(C_FLAGS) -S /mnt/c/work/node.lua.tour/modules/deps/ubus/libubus-acl.c -o CMakeFiles/ubus.dir/libubus-acl.c.s

CMakeFiles/ubus.dir/libubus-acl.c.o.requires:
.PHONY : CMakeFiles/ubus.dir/libubus-acl.c.o.requires

CMakeFiles/ubus.dir/libubus-acl.c.o.provides: CMakeFiles/ubus.dir/libubus-acl.c.o.requires
	$(MAKE) -f CMakeFiles/ubus.dir/build.make CMakeFiles/ubus.dir/libubus-acl.c.o.provides.build
.PHONY : CMakeFiles/ubus.dir/libubus-acl.c.o.provides

CMakeFiles/ubus.dir/libubus-acl.c.o.provides.build: CMakeFiles/ubus.dir/libubus-acl.c.o

# Object files for target ubus
ubus_OBJECTS = \
"CMakeFiles/ubus.dir/libubus.c.o" \
"CMakeFiles/ubus.dir/libubus-io.c.o" \
"CMakeFiles/ubus.dir/libubus-obj.c.o" \
"CMakeFiles/ubus.dir/libubus-sub.c.o" \
"CMakeFiles/ubus.dir/libubus-req.c.o" \
"CMakeFiles/ubus.dir/libubus-acl.c.o"

# External object files for target ubus
ubus_EXTERNAL_OBJECTS =

libubus.so: CMakeFiles/ubus.dir/libubus.c.o
libubus.so: CMakeFiles/ubus.dir/libubus-io.c.o
libubus.so: CMakeFiles/ubus.dir/libubus-obj.c.o
libubus.so: CMakeFiles/ubus.dir/libubus-sub.c.o
libubus.so: CMakeFiles/ubus.dir/libubus-req.c.o
libubus.so: CMakeFiles/ubus.dir/libubus-acl.c.o
libubus.so: CMakeFiles/ubus.dir/build.make
libubus.so: CMakeFiles/ubus.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --red --bold "Linking C shared library libubus.so"
	$(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/ubus.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
CMakeFiles/ubus.dir/build: libubus.so
.PHONY : CMakeFiles/ubus.dir/build

CMakeFiles/ubus.dir/requires: CMakeFiles/ubus.dir/libubus.c.o.requires
CMakeFiles/ubus.dir/requires: CMakeFiles/ubus.dir/libubus-io.c.o.requires
CMakeFiles/ubus.dir/requires: CMakeFiles/ubus.dir/libubus-obj.c.o.requires
CMakeFiles/ubus.dir/requires: CMakeFiles/ubus.dir/libubus-sub.c.o.requires
CMakeFiles/ubus.dir/requires: CMakeFiles/ubus.dir/libubus-req.c.o.requires
CMakeFiles/ubus.dir/requires: CMakeFiles/ubus.dir/libubus-acl.c.o.requires
.PHONY : CMakeFiles/ubus.dir/requires

CMakeFiles/ubus.dir/clean:
	$(CMAKE_COMMAND) -P CMakeFiles/ubus.dir/cmake_clean.cmake
.PHONY : CMakeFiles/ubus.dir/clean

CMakeFiles/ubus.dir/depend:
	cd /mnt/c/work/node.lua.tour/modules/deps/build/ubus && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /mnt/c/work/node.lua.tour/modules/deps/ubus /mnt/c/work/node.lua.tour/modules/deps/ubus /mnt/c/work/node.lua.tour/modules/deps/build/ubus /mnt/c/work/node.lua.tour/modules/deps/build/ubus /mnt/c/work/node.lua.tour/modules/deps/build/ubus/CMakeFiles/ubus.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : CMakeFiles/ubus.dir/depend

