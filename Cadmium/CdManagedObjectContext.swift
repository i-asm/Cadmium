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
    internal static var _mainThreadContext: CdManagedObjectContext? = nil
    
    /**
     *  This handle tracks the master background save context.  This context will be
     *  the parent context for all others (include all background transactions and the
     *  main thread context).
     */
    internal static var _masterSaveContext: CdManagedObjectContext? = nil
    
    /**
     *  This should be set to true when an update handler is installed.  It tells
     *  the notification handler to iterate through updated objects and call their
     *  handlers.
     */
    internal static var shouldCallUpdateHandlers: Bool = false
    
    /**
     Initialize the master save context and the main thread context.
     
     - parameter coordinator: The persistent store coordinator for the save context.
     */
    internal class func initializeMasterContexts(coordinator coordinator: NSPersistentStoreCoordinator?) {
        _masterSaveContext = CdManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        _masterSaveContext?.undoManager = nil
        _masterSaveContext?.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        _masterSaveContext?.persistentStoreCoordinator = coordinator
        
        _mainThreadContext = CdManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        _mainThreadContext?.undoManager = nil
        _mainThreadContext?.parentContext = _masterSaveContext
        
        let notificationQueue = NSOperationQueue()
        
        /* Attach update handler to main thread context */
        NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: _masterSaveContext, queue: notificationQueue) { (notification: NSNotification) -> Void in
            dispatch_async(dispatch_get_main_queue()) {
                NSThread.currentThread().setInsideMainThreadChangeNotification(true)
                
                /* Fault-in update objects before mergeChangesFromContextDidSaveNotification
                   This allows monitoring FRC to see newly inserted objects, rather than them
                   being treated like invisible faults.
                   http://www.mlsite.net/blog/?p=518 */
                if let updates = notification.userInfo?["updated"] as? Set<NSManagedObject> {
                    for update in updates {
                        _mainThreadContext?.objectWithID(update.objectID).willAccessValueForKey(nil)
                    }
                }
                
                _mainThreadContext?.mergeChangesFromContextDidSaveNotification(notification)
                NSThread.currentThread().setInsideMainThreadChangeNotification(false)
            }
        }
        
        /* Attach update handler to main thread context */
        NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextObjectsDidChangeNotification, object: _mainThreadContext, queue: nil) { (notification: NSNotification) -> Void in
            guard shouldCallUpdateHandlers else { return }
            
            dispatch_async(dispatch_get_main_queue()) {
                if let refreshedObjects = notification.userInfo?[NSRefreshedObjectsKey] as? Set<CdManagedObject> {
                    for object in refreshedObjects {
                        object.updateHandler?(.Refreshed)
                    }
                }
                
                if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<CdManagedObject> {
                    for object in updatedObjects {
                        object.updateHandler?(.Updated)
                    }
                }
                
                if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<CdManagedObject> {
                    for object in deletedObjects {
                        object.updateHandler?(.Deleted)
                    }
                }
            }
        }
        
        /* Attach handler for one-time iCloud setup */
        NSNotificationCenter.defaultCenter().addObserverForName(NSPersistentStoreCoordinatorStoresWillChangeNotification, object: coordinator, queue: notificationQueue) { (notification: NSNotification) -> Void in
            guard let msc = _masterSaveContext else {
                return
            }
            
            msc.performBlock {
                if (msc.hasChanges) {
                    try! msc.save()
                } else {
                    msc.reset()
                }
            }
        }
        
        #if os(iOS)
        /* Attach update handler for general iCloud update notifications */
        NSNotificationCenter.defaultCenter().addObserverForName(NSPersistentStoreDidImportUbiquitousContentChangesNotification, object: coordinator, queue: notificationQueue) { (notification: NSNotification) -> Void in
            _masterSaveContext?.performBlock {
                _masterSaveContext?.mergeChangesFromContextDidSaveNotification(notification)
                self.saveMasterWriteContext()
            }
        }
        #endif
    }
    
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
        Cd.raise("Cadmium must be initialized before a main thread context is available.")
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

    /**
     Saves the master write context if necessary.
     */
    @inline(__always) internal class func saveMasterWriteContext() {
        guard let msc = _masterSaveContext else {
            return
        }
        
        msc.performBlockAndWait {
            if msc.hasChanges {
                try! msc.save()
            }
        }
    }
}



internal extension NSThread {
    
    /**
     Get the currently attached CdManagedObjectContext to the thread.
     
     - returns: The currently attached context, or nil if none.
     */
    @inline(__always) internal func attachedContext() -> CdManagedObjectContext? {
        if self.isMainThread {
            return CdManagedObjectContext._mainThreadContext
        }
        return self.threadDictionary[kCdThreadPropertyCurrentContext] as? CdManagedObjectContext
    }
    
    /**
     Attach a context to the current thread.  Pass nil to remove the context from the current thread.
     
     - parameter context: The context to attach, or nil to remove.
     */
    @inline(__always) internal func attachContext(context: CdManagedObjectContext?) {
        if self.isMainThread {
            Cd.raise("You cannot explicitly attach a context from the main thread.")
        }
        self.threadDictionary[kCdThreadPropertyCurrentContext] = context
    }
    
    /**
     Returns true if the current transaction context should *NOT* perform
     an implicit commit.
     
     - returns: true if the current transaction context should *NOT*
                perform an implicit commit.
     */
    @inline(__always) internal func noImplicitCommit() -> Bool {
        return (self.threadDictionary[kCdThreadPropertyNoImplicitSave] as? Bool) ?? false
    }
    
    /**
     Declare if the current transaction context should perform an implicit commit
     when finished.
     
     - parameter status: Whether or not the implicit commit should be aborted.
     */
    @inline(__always) internal func setNoImplicitCommit(status: Bool?) {
        self.threadDictionary[kCdThreadPropertyNoImplicitSave] = status
    }
    
    /**
     Returns true if the main thread is inside a sanctioned
     NSManagedObjectContextDidSaveNotification notification).
     
     - returns: true if the main thread should allow modifications (set during
     the NSManagedObjectContextDidSaveNotification notification).
     */
    internal func insideMainThreadChangeNotification() -> Bool {
        return (self.threadDictionary[kCdThreadPropertyMainSaveNotif] as? Bool) ?? false
    }
    
    /**
     Declare if the main thread context is inside of a sanctioned
     NSManagedObjectContextDidSaveNotification merge event.
     
     - parameter status: true if so, false if not.
     */
    internal func setInsideMainThreadChangeNotification(inside: Bool) {
        self.threadDictionary[kCdThreadPropertyMainSaveNotif] = inside
    }
    
    
}

