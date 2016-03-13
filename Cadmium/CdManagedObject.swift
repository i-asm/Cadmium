//
//  CdManagedObject.swift
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

/**
 *  Any core data model class you create must inherit from CdManagedObject
 *  instead of NSManagedObject.  This is enforced in the query functions since
 *  a return type must of CdManagedObject.
 *
 *  The implementation of this class installs access and write hooks that
 *  verify you are modifying your managed objects in the proper context.
 */
public class CdManagedObject : NSManagedObject {
    
    /**
     This is an override for willAccessValueForKey: that ensures the access
     is performed in the proper threading context.
     
     - parameter key: The key whose value is being accessed.
     */
    public override func willAccessValueForKey(key: String?) {
        super.willAccessValueForKey(key)
    }
    
    /**
     This is an override for willChangeValueForKey: that ensures the change
     is performed in the proper threading context.
     
     - parameter key: The key whose value is being changed.
     */
    public override func willChangeValueForKey(key: String) {
        super.willChangeValueForKey(key)
    }
    
}