//
//  CancellationToken.swift
//  CancellationToken
//
//  Created by Tom Lokhorst on 2014-10-31.
//
//

import Foundation

/**
A token that will never be cancelled
*/
public let NotCancellableToken = CancellationToken(state: .NotCancelled)

/**
A already cancelled token
*/
public let CancelledToken = CancellationToken(state: .Cancelled)

enum State {
  case Cancelled
  case NotCancelled
  case Pending(CancellationTokenSource)
}

/**
A `CancellationToken` indicates if cancellation of "something" was requested.
Can be passed around and checked by whatever wants to be cancellable.

To create a cancellation token, use `CancellationTokenSource`.
*/
public struct CancellationToken {

  private var state: State

  public var isCancellationRequested: Bool {
    switch state {
    case .Cancelled:
      return true
    case .NotCancelled:
      return false
    case let .Pending(source):
      return source.isCancellationRequested
    }
  }

  internal init(state: State) {
    self.state = state
  }

  public func register(handler: Void -> Void) {

    switch state {
    case let .Pending(source):
      source.register(handler)
    default:
      handler()
    }
  }
}

/**
A `CancellationTokenSource` is used to create a `CancellationToken`.
The created token can be set to "cancellation requested" using the `cancel()` method.
*/
public class CancellationTokenSource {
  public var token: CancellationToken {
    if isCancellationRequested {
      return CancellationToken(state: .Cancelled)
    }
    else {
      return CancellationToken(state: .Pending(self))
    }
  }

  private var handlers: [Void -> Void] = []
  internal var isCancellationRequested = false

  public init() {
  }

  public func register(handler: Void -> Void) {
    if isCancellationRequested {
      handler()
    }
    else {
      handlers.append(handler)
    }
  }

  public func cancel() {
    tryCancel()
  }

  public func cancel(when: dispatch_time_t) {
    // On a background queue
    let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)

    dispatch_after(when, queue) { [weak self] in
      self?.tryCancel()
      return
    }
  }

  public func cancel(seconds: NSTimeInterval) {
    cancel(dispatch_time(DISPATCH_TIME_NOW, Int64(seconds * Double(NSEC_PER_SEC))))
  }

  internal func tryCancel() -> Bool {
    if !isCancellationRequested {
      isCancellationRequested = true
      executeHandlers()

      return true
    }

    return false
  }

  private func executeHandlers() {
    // Call all previously scheduled handlers
    for handler in handlers {
      handler()
    }

    // Cleanup
    handlers = []
  }
}
