# UnrarKit CHANGELOG

## 2.3

* Full Unicode support (Issue #11)
* Better support for moving files during a decompression into memory by adding a new block-based method


## 2.2.4

Added -lc++ to CocoaPods linker flags, so that a .mm file is no longer required for a successful build


## 2.2.2

Added documentation, full Travis CI integration


## 2.2

Upgraded to unrar library 5.2.1


## 2.1

Fixed bug in NSErrors generated


## 2.0.7

Fixed major leak of file descriptors, causing clients to run out of file descriptors


## 2.0.6

Added requires_arc flag to podspec


## 2.0.5

Fixed an Xcode 6 compilation bug


## 2.0.2

First release in CocoaPods spec repo


## 2.0.0

Initial release