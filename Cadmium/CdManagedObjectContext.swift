//
//  CdManagedObjectContext.swift
//  Cadmium
//
//  Copyright (c) 2016-Present Jason Fieldman - https://github.com/jmfieldman/Cadmium
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import CoreData


public class CdManagedObjectContext : NSManagedObjectContext {
    
    
    /**
     *    ------------------- Internal Properties ----------------------------
     */
    
    /**
     *  This handle tracks the main thread context singleton for our implementation.
     *  It should be initialized when the Cadmium system is initialized.
     */
    private static var _mainThreadContext: CdManagedObjectContext? = nil
    
    /**
     *  This handle tracks the master background save context.  This context will be
     *  the parent context for all others (include all background transactions and the
     *  main thread context).
     */
    private static var _masterSaveContext: CdManagedObjectContext? = nil
    
    
    /**
     *    ------------------- Internal Helper Functions ----------------------
     */
     
     
    /**
     Returns the main thread context (and protects against pre-initialization access)
     
     - returns: The main thread context
     */
    @inline(__always) internal class func mainThreadContext() -> CdManagedObjectContext {
        if let mtc = _mainThreadContext {
            return mtc
        }
        
        /* This is only feasible if we have not initialized the Cadmium engine. */
        fatalError("Cadmium must be initialized before a main thread context is available.")
    }
    
    /**
     Creates a new background write context whose parent is the master save context.
     
     - returns: The new background write context.
     */
    @inline(__always) internal class func newBackgroundWriteContext() -> CdManagedObjectContext {
        let newContext           = CdManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        newContext.parentContext = _masterSaveContext
        newContext.undoManager   = nil
        return newContext
    }
    
    /**
     Returns the proper CdManagedObjectContext instance for the calling thread.  If called from
     the main thread it will return the main thread context.  Otherwise it will check if a
     background write context exists for this thread.
     
     - returns: The proper CdManagedObjectContext for the calling thread (if it exists)
     */
    @inline(__always) internal class func forThreadContext() -> CdManagedObjectContext? {
        let currentThread = NSThread.currentThread()
        if currentThread.isMainThread {
            return mainThreadContext()
        }
        
        if let currentContext = currentThread.attachedContext() {
            return currentContext
        }
        
        return nil
    }

    
}



internal extension NSThread {
    
    /**
     Get the currently attached CdManagedObjectContext to the thread.
     
     - returns: The currently attached context, or nil if none.
     */
    internal func attachedContext() -> CdManagedObjectContext? {
        if self.isMainThread {
            return CdManagedObjectContext._mainThreadContext
        }
        return self.threadDictionary[kCdThreadPropertyCurrentContext] as? CdManagedObjectContext
    }
    
    /**
     Attach a background write context to the current thread
     */
    internal func attachContext(context: CdManagedObjectContext) {
        if self.isMainThread {
            fatalError("You cannot explicitly attach a context from the main thread.")
        }
        self.threadDictionary[kCdThreadPropertyCurrentContext] = context
    }
    
    /**
     Detach the background write context from the current thread.
     */
    internal func detachContext() {
        if self.isMainThread {
            fatalError("You cannot explicitly detach a context from the main thread.")
        }
        self.threadDictionary.removeObjectForKey(kCdThreadPropertyCurrentContext)
    }
    
}

