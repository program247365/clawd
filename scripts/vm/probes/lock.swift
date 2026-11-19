import Foundation
let h = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_NOW)!
typealias Lock = @convention(c) () -> Int32
print(unsafeBitCast(dlsym(h, "SACLockScreenImmediate")!, to: Lock.self)())
