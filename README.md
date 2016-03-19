![Cadmium](/Assets/Banner.png)

Cadmium is a Core Data framework for Swift that enforces best practices and raises exceptions for common Core Data pitfalls exactly where you make them.

# Design Goals

* Create a minimalist/concise framework API that provides for most Core Data use cases and guides the user towards best practices.
* Aggressively protect the user from performing common Core Data pitfalls, and raise exceptions immediately on the offending statement rather than waiting for a context save event.

---

Here's an example of a Cadmium transaction that gives all of your employee objects a raise:

```swift
Cd.transact {
    try! Cd.objects(Employee.self).fetch().forEach {
        $0.salary += 10000
    }
}
```

You might notice a few things:

* Transaction usage is dead-simple.  You do not declare any parameters for use inside the block.
* You never have to reference the managed object context, we manage it for you.
* The changes are committed automatically upon completion (you can disable this.)

### What Cadmium is Not

Cadmium is not designed to be a 100% complete wrapper around Core Data.  Some of the much more
advanced Core Data features are hidden behind the Cadmium API.  If you are creating an enterprise-level
application that requires meticulous manipulation of Core Data stores and contexts to optimize heavy lifting, then
Cadmium is not for you.

Cadmium is for you if want a smart wrapper that vastly simplifies most Core Data tasks and warns you
immediately when you inadvertently manipulate data in a way you shouldn't.

# Installing

You can install Cadmium by adding it to your [CocoaPods](http://cocoapods.org/) ```Podfile```:

```ruby
pod 'Cadmium'
```

Or you can use a variety of ways to include the ```Cadmium.framework``` file from this project into your own.

# How to Use

### Context Architecture

Cadmium uses the same basic context architecture as CoreStore, with a root save context running on a private queue that
has one read-only child context on the main queue and any number of writeable child contexts running on background queues.

![Cadmium Core Data Architecture](/Assets/core_data_arch.png)

This means that your main thread will never bog down on write transactions, and will only be used to merge changes (in memory)
and updating any UI elements dependent on your data.

It also means that you cannot initiate modifications to managed objects on the main thread!  All of your write operations
must exist inside transactions that occur in background threads.  You will need to design your app to support the idea
of asynchronous write operations, which is what you *should* be doing when it comes to database modification.

### Initialization

Set up Cadmium with a single initialization call:

```swift
do {
    try Cd.initWithSQLStore(momdInbundleID: nil,
                            momdName:       "MyObjectModel.momd",
                            sqliteFilename: "MyDB.sqlite",
                            options:        nil /* Optional */)
} catch let error {
    print("\(error)")
}
```

This loads the object model, sets up the persistent store coordinator, and initializes important contexts.

If your object model is in a framework (not your main bundle), you'll have to pass the framework's bundle identifier to the first argument.

The ```options```  argument flows through to the options passed in addPersistentStoreWithType: on the NSPersistentStoreCoordinator.

### Querying

Cadmium offers a chained query mechanism.  This can be used to query objects from the main thread (for read-only purposes), or from inside a transaction.

Querying starts with ```Cd.objects(..)``` and looks like this:

```swift
do {
    for employee in try Cd.objects(Employee.self)
                          .filter("name = %@", someName)
                          .sort("name", ascending: true)
                          .fetch() {
        /* Do something */
        print("Employee name: \(employee.name)")
    }
} catch let error {
    print("\(error)")
}
```

You begin by passing the managed object type into the parameter for ```Cd.objects(..)```.  This constructs a ```CdFetchRequest``` for managed objects of that type.

Chain in as many filter/sort/modification calls as you want, and finalize with ```fetch()``` or ```fetchOne()```.  ```fetch()``` returns an array of objects, and ```fetchOne()``` returns a single optional object (```nil``` if none were found matching the filter).

### Transactions

You can only initiate changes to your data from inside of a transaction.  You can initiate a transaction using either:

```swift
Cd.transact {
    //...
}
```

```swift
Cd.transactAndWait {
    //...
}
```

```Cd.transact``` performs the transaction asynchronously (the calling thread continues while the work in the transaction is performed).   ```Cd.transactAndWait``` performs the transaction synchronously (it will block the calling thread until the transaction is complete.)

To ensure best practices and avoid potential deadlocks, you are not allowed to call ```Cd.transactAndWait``` from the main thread (this will raise an exception.)

### Implicit Transaction Commit

When a transaction completes, the transaction context automatically commits any changes you made to the data store.  For most transactions this means you do not need to call any additional commit/save command.

If you want to turn off the implicit commit for a transaction (e.g. to perform a rollback and ignore any changes made), you can call ```Cd.cancelImplicitCommit()``` from inside the transaction.  A typical use case would look like:

```swift
Cd.transact {

    modifyThings()

    if someErrorOccurred {
        Cd.cancelImplicitCommit()
        return
    }

    moreActions()
}
```

You can also force a commit mid-transaction by calling ```Cd.commit()```.  You may want to do this during long transactions when you want to save changes before possibly returning with a cancelled implicit commit.  A use case might look like:

```swift
Cd.transact {

    modifyThingsStepOne()
    Cd.commit() //changes in modifyThingsStepOne() cannot be rolled back!

    modifyThingsStepTwo()

    if someErrorOccurred {
        Cd.cancelImplicitCommit()
        return
    }

    moreActions()
}
```

### Creating and Deleting Objects

Objects can be created and deleted inside transactions.

```swift
Cd.transact {
    let newEmployee    = try! Cd.create(Employee.self)
    newEmployee.name   = "Bob"
    newEmployee.salary = 10000
}

Cd.transact {
    Cd.delete(try! Cd.objects(Employee.self).filter("name = %@", "Bob").fetch())
}
```                  

You can also delete objects directly from a CdFetchRequest:

```swift
Cd.objects(Employee.self).filter("salary > 100000").delete()
```

If called:

* Outside a transaction: will delete the objects asynchronously in a background transaction.
* Inside a transaction: will perform the delete synchronously inside the transaction.


### Modifying Objects from Other Contexts

You will often need to modify a managed object from one context inside of another context.  The most
common use case is when you want to modify objects you've queried from the main thread (which are read-only).

You can use ```Cd.useInCurrentContext``` to get a copy of the object that is suitable for
modification in the current context:

```swift
/* Acquire a read-only employee object somewhere on the main thread */
guard let employee = try! Cd.objects(Employee.self).fetchOne() else {
    return
}

/* Modify it in a transaction */
Cd.transact {
    guard let txEmployee = Cd.useInCurrentContext(employee) else {
        return
    }

    txEmployee.salary += 10000    
}
```

Note that an object must have been inserted and committed in a transaction before it can be accessed from another context.
If a transient object has not been inserted yet, it will not be available with this method.


### Notifying the Main Thread

Because transactions occur on the transaction context's private queue, calls to ```Cd.commit()``` are synchronous and only
return after the save has propagated to the persistent store.

You can use this fact to notify the main thread that a commit has completed in your transaction:

```swift
Cd.transact {

    modifyThings()
    Cd.commit()

    /* only called after the commit saves up to the persistent store */
    dispatch_async(dispatch_get_main_queue()) {
        notifyOthers()
    }    
}
```

### Fetched Results Controller

For typical uses of ```NSFetchedResultsController```, you should use the built-in subclass ```CdFetchedResultsController```.  This
subclass wraps the normal functionality of ```NSFetchedResultsController``` onto the protected main queue context.

You can use the ```CdFetchedResultsController``` as you would a ```NSFetchedResultsController``` with the following in mind:

* The objects in the fetch results exist in the main thread read-only context and cannot be modified.  Use ```Cd.useInCurrentContext```
to modify them in a transaction.
* You can pass a ```UITableView``` into the ```automateDelegation``` method to perform the standard insert/delete commands on sections and
rows when your fetched results controller has changes.  This can help save a few lines in your own view controllers.

### Aggressively Identifying Coding Pitfalls

Most developers who use Core Data have gone through the same gauntlet of discovering the various pitfalls and complications of creating a multi-threaded Core Data application.  

Even seasoned veterans are still susceptible to the occasional ```1570: The operation couldn’t be completed``` or ```13300: NSManagedObjectReferentialIntegrityError```

Many of the common issues arise because the standard Core Data framework is lenient about allowing code that does the Wrong Thing and only throwing an error on the eventual attempt to save (which may not be proximal to the offending code.)

Cadmium performs aggressive checking on managed object operations to make sure you are coding correctly, and will raise exceptions on the offending lines rather than waiting for a save to occur.
