import Foundation

#if canImport(Observation)
  import Observation
#endif

/// Provides storage for tracking and access to data changes.
///
/// You don't need to create an instance of `PerceptionRegistrar` when using
/// the ``Perception/Perceptible()`` macro to indicate observability of a type.
@available(iOS, deprecated: 17, renamed: "ObservationRegistrar")
@available(macOS, deprecated: 14, renamed: "ObservationRegistrar")
@available(tvOS, deprecated: 17, renamed: "ObservationRegistrar")
@available(watchOS, deprecated: 10, renamed: "ObservationRegistrar")
public struct PerceptionRegistrar: Sendable {
  private let _rawValue: AnySendable

  /// Creates an instance of the observation registrar.
  ///
  /// You don't need to create an instance of
  /// ``PerceptionRegistrar`` when using the
  /// ``Perception/Perceptible()`` macro to indicate observably
  /// of a type.
  public init() {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
      #if canImport(Observation)
        self._rawValue = AnySendable(ObservationRegistrar())
      #else
        self._rawValue = AnySendable(_PerceptionRegistrar())
      #endif
    } else {
      self._rawValue = AnySendable(_PerceptionRegistrar())
    }
  }

  #if canImport(Observation)
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    private var registrar: ObservationRegistrar {
      self._rawValue.base as! ObservationRegistrar
    }
  #endif

  private var perceptionRegistrar: _PerceptionRegistrar {
    self._rawValue.base as! _PerceptionRegistrar
  }
}

#if canImport(Observation)
  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  extension PerceptionRegistrar {
    public func access<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.registrar.access(subject, keyPath: keyPath)
    }

    public func withMutation<Subject: Observable, Member, T>(
      of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T
    ) rethrows -> T {
      try self.registrar.withMutation(of: subject, keyPath: keyPath, mutation)
    }

    public func willSet<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.registrar.willSet(subject, keyPath: keyPath)
    }

    public func didSet<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.registrar.didSet(subject, keyPath: keyPath)
    }
  }
#endif

extension PerceptionRegistrar {
  @_disfavoredOverload
  public func access<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    #if canImport(Observation)
      if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
        func `open`<T: Observable>(_ subject: T) {
          self.registrar.access(
            subject,
            keyPath: unsafeDowncast(keyPath, to: KeyPath<T, Member>.self)
          )
        }
        if let subject = subject as? any Observable {
          open(subject)
        }
      } else {
        perceptionCheck()
        self.perceptionRegistrar.access(subject, keyPath: keyPath)
      }
    #endif
  }

  @_disfavoredOverload
  public func withMutation<Subject: Perceptible, Member, T>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    #if canImport(Observation)
      if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
        let subject = subject as? any Observable
      {
        func `open`<S: Observable>(_ subject: S) throws -> T {
          return try self.registrar.withMutation(
            of: subject,
            keyPath: unsafeDowncast(keyPath, to: KeyPath<S, Member>.self),
            mutation
          )
        }
        return try open(subject)
      } else {
        return try self.perceptionRegistrar.withMutation(of: subject, keyPath: keyPath, mutation)
      }
    #else
      return try mutation()
    #endif
  }

  @_disfavoredOverload
  public func willSet<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    #if canImport(Observation)
      if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
        let subject = subject as? any Observable
      {
        func `open`<S: Observable>(_ subject: S) {
          return self.registrar.willSet(
            subject,
            keyPath: unsafeDowncast(keyPath, to: KeyPath<S, Member>.self)
          )
        }
        return open(subject)
      } else {
        return self.perceptionRegistrar.willSet(subject, keyPath: keyPath)
      }
    #endif
  }

  @_disfavoredOverload
  public func didSet<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    #if canImport(Observation)
      if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
        let subject = subject as? any Observable
      {
        func `open`<S: Observable>(_ subject: S) {
          return self.registrar.didSet(
            subject,
            keyPath: unsafeDowncast(keyPath, to: KeyPath<S, Member>.self)
          )
        }
        return open(subject)
      } else {
        return self.perceptionRegistrar.didSet(subject, keyPath: keyPath)
      }
    #endif
  }
}

extension PerceptionRegistrar: Codable {
  public init(from decoder: any Decoder) throws {
    self.init()
  }

  public func encode(to encoder: any Encoder) {
    // Don't encode a registrar's transient state.
  }
}

extension PerceptionRegistrar: Hashable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    // A registrar should be ignored for the purposes of determining its
    // parent type's equality.
    return true
  }

  public func hash(into hasher: inout Hasher) {
    // Don't include a registrar's transient state in its parent type's
    // hash value.
  }
}

#if DEBUG
  private func perceptionCheck() {
    if #unavailable(iOS 17, macOS 14, tvOS 17, watchOS 10),
      !_PerceptionLocals.isInPerceptionTracking,
      !_PerceptionLocals.skipPerceptionChecking,
      isInSwiftUIBody()
    {
      runtimeWarn(
        """
        Perceptible state was accessed but is not being tracked. Track changes to state by \
        wrapping your view in a 'WithPerceptionTracking' view.
        """
      )
    }
  }

  private let isInSwiftUIBody: () -> Bool = memoize {
    for callStackSymbol in Thread.callStackSymbols {
      let mangledSymbol = callStackSymbol.utf8
        .drop(while: { $0 != .init(ascii: "$") })
        .prefix(while: { $0 != .init(ascii: " ") })
      guard
        let demangled = String(Substring(mangledSymbol)).demangled,
        demangled.contains("body.getter : "),
        !demangled.isActionClosure
      else {
        continue
      }
      return true
    }
    return false
  }

  extension String {
    fileprivate var isActionClosure: Bool {
      var view = self[...].utf8
      guard view.starts(with: "closure #".utf8) else { return false }
      view = view.drop(while: { $0 != .init(ascii: "-") })
      return view.starts(with: "-> () in ".utf8)
    }

    fileprivate var demangled: String? {
      return self.utf8CString.withUnsafeBufferPointer { mangledNameUTF8CStr in
        let demangledNamePtr = swift_demangle(
          mangledName: mangledNameUTF8CStr.baseAddress,
          mangledNameLength: UInt(mangledNameUTF8CStr.count - 1),
          outputBuffer: nil,
          outputBufferSize: nil,
          flags: 0
        )
        if let demangledNamePtr = demangledNamePtr {
          let demangledName = String(cString: demangledNamePtr)
          free(demangledNamePtr)
          return demangledName
        }
        return nil
      }
    }
  }

  @_silgen_name("swift_demangle")
  private func swift_demangle(
    mangledName: UnsafePointer<CChar>?,
    mangledNameLength: UInt,
    outputBuffer: UnsafeMutablePointer<CChar>?,
    outputBufferSize: UnsafeMutablePointer<UInt>?,
    flags: UInt32
  ) -> UnsafeMutablePointer<CChar>?
#else
  @_transparent
  @inline(__always)
  private func perceptionCheck() {}
#endif

#if DEBUG
  @available(iOS, deprecated: 17)
  @available(macOS, deprecated: 14)
  @available(tvOS, deprecated: 17)
  @available(watchOS, deprecated: 10)
  public func _withoutPerceptionChecking<T>(
    _ apply: () -> T
  ) -> T {
    return _PerceptionLocals.$skipPerceptionChecking.withValue(true) {
      apply()
    }
  }
#else
  @available(iOS, deprecated: 17)
  @available(macOS, deprecated: 14)
  @available(tvOS, deprecated: 17)
  @available(watchOS, deprecated: 10)
  @_transparent
  @inline(__always)
  public func _withoutPerceptionChecking<T>(
    _ apply: () -> T
  ) -> T {
    apply()
  }
#endif
