* x264 fork to add cmake support

** goals

the goal of this fork is to add cmake support to x264. the provided functionality is not yet on par with the traditional configure based build. I thus encourage you to post issues on functionality that is buggy or missing. 

** suported OS

Linux, Windows 7

* How to use

Open a terminal (make sure your desired toolchain and cmake is available through the environment):
```
$ cd repo
$ cd cmake_unofficial
$ cmake .
```

This will generate the project/Makefiles that you'll need tpo build x264.



