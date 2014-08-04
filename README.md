# About

UnrarKit is here to enable Mac and iOS apps to easily work with RAR files for read-only operations.

There is a main project, with a static library target and a unit tests target, and an example project, which demonstrates how to use the library.

I'm always open to improvements, so please submit your pull requests.


# Installation

UnrarKit has been converted to a CocoaPods project. If you're not familiar with [CocoaPods](http://cocoapods.org), you can start with their [Getting Started guide](http://guides.cocoapods.org/using/getting-started.html).

I've included a sample [`podfile`](Example/Podfile) in the Example directory along with the sample project. Everything should install with the single command:

    pod install


# Notes

Since UnrarKit uses C++ libraries, you will need to change the extension of classes that use UnrarKit to `.mm`. This will include `libstdc++` in the linking stage. If you would like to keep your extension `.m` (though I'm not sure what the advantage would be), you will need to add `libstdc++` to the linker flags in your application.

To open in Xcode, use the [UnrarKit.xcworkspace](UnrarKit.xcworkspace) file, which includes the other projects.

# Credits

* Rogerio Pereira Araujo (rogerio.araujo@gmail.com)
* Vicent Scott (vkan388@gmail.com)
* Dov Frankel (dov@abbey-code.com)