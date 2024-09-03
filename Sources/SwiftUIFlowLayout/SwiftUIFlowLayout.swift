import SwiftUI

/// Default item spacing for `FlowLayout`.
public let flowLayoutDefaultItemSpacing: CGFloat = 4

/// A flexible flow layout that arranges items in a grid-like format with dynamic spacing and content.
///
/// `FlowLayout` supports various hashable collections (e.g., arrays, ranges, sets) and provides options for scrollable or stack-based layouts.
/// You can optionally specify the spacing between items, allowing the layout to use the system's default spacing if needed.
public struct FlowLayout<Trigger, Data, Content>: View where Data: Collection, Content: View {

  /// The layout mode: `scrollable` or `vstack`.
  let mode: Mode

  /// A binding to a trigger that updates the layout when its value changes.
  @Binding var trigger: Trigger

  /// The data to be displayed in the layout.
  let data: Data

  /// The spacing between items in the layout. Defaults to `flowLayoutDefaultItemSpacing`.
  let spacing: CGFloat

  /// A closure that generates the content for each item in the layout.
  @ViewBuilder let content: (Data.Element) -> Content

  /// The total height of the layout. Managed internally to accommodate different modes.
  @State private var totalHeight: CGFloat

  /// Initializes a new `FlowLayout` with the given parameters.
  ///
  /// - Parameters:
  ///   - mode: The layout mode, either `scrollable` or `vstack`.
  ///   - trigger: A binding to a trigger that updates the layout.
  ///   - data: The data to be displayed in the layout.
  ///   - spacing: The spacing between items in the layout. Defaults to `flowLayoutDefaultItemSpacing`.
  ///   - content: A closure that generates the content for each item.
  public init(mode: Mode,
              trigger: Binding<Trigger>,
              data: Data,
              spacing: CGFloat = flowLayoutDefaultItemSpacing,
              @ViewBuilder content: @escaping (Data.Element) -> Content) {
    self.mode = mode
    _trigger = trigger
    self.data = data
    self.spacing = spacing
    self.content = content
    _totalHeight = State(initialValue: (mode == .scrollable) ? .zero : .infinity)
  }

  public var body: some View {
    let stack = VStack {
      GeometryReader { geometry in
        self.content(in: geometry)
      }
    }
    return Group {
      if mode == .scrollable {
        stack.frame(height: totalHeight)
      } else {
        stack.frame(maxHeight: totalHeight)
      }
    }
  }

  private func content(in proxy: GeometryProxy) -> some View {
    var width = CGFloat.zero
    var height = CGFloat.zero
    var lastHeight = CGFloat.zero
    let itemCount = data.count
    return ZStack(alignment: .topLeading) {
      ForEach(Array(data.enumerated()), id: \.offset) { index, item in
        content(item)
          .padding([.horizontal, .vertical], spacing)
          .alignmentGuide(.leading) { dimensions in
            if (abs(width - dimensions.width) > proxy.size.width) {
              width = 0
              height -= lastHeight
            }
            lastHeight = dimensions.height
            let result = width
            if index == itemCount - 1 {
              width = 0
            } else {
              width -= dimensions.width
            }
            return result
          }
          .alignmentGuide(.top) { _ in
            let result = height
            if index == itemCount - 1 {
              height = 0
            }
            return result
          }
      }
    }
    .background(HeightReaderView(trigger: $totalHeight))
  }

  /// Represents the available layout modes for `FlowLayout`.
  public enum Mode {
    case scrollable, vstack
  }
}

// MARK: View Height Utilities

/// PreferenceKey for capturing view height.
private struct HeightPreferenceKey: PreferenceKey {
  static func reduce(value _: inout CGFloat, nextValue _: () -> CGFloat) {}
  static var defaultValue: CGFloat = 0
}

/// A view that reads its height and triggers a binding when it changes.
private struct HeightReaderView: View {
  @Binding var trigger: CGFloat
  var body: some View {
    GeometryReader { geo in
      Color.clear
        .preference(key: HeightPreferenceKey.self, value: geo.frame(in: .local).size.height)
    }
    .onPreferenceChange(HeightPreferenceKey.self) { h in
      trigger = h
    }
  }
}

// MARK: - Trigger-less Convenience Initializer

public extension FlowLayout where Trigger == Never? {

  /// A convenience initializer for `FlowLayout` that doesn't require a trigger.
  ///
  /// - Parameters:
  ///   - mode: The layout mode, either `scrollable` or `vstack`.
  ///   - data: The data to be displayed in the layout.
  ///   - spacing: The spacing between items in the layout. Defaults to `flowLayoutDefaultItemSpacing`.
  ///   - content: A closure that generates the content for each item.
  init(mode: Mode,
       data: Data,
       spacing: CGFloat = flowLayoutDefaultItemSpacing,
       @ViewBuilder content: @escaping (Data.Element) -> Content) {
    self.init(mode: mode,
              trigger: .constant(nil),
              data: data,
              spacing: spacing,
              content: content)
  }
}

// MARK: - Testing Previews

private var sampleData = [
  "Some long item here", "And then some longer one",
  "Short", "Items", "Here", "And", "A", "Few", "More",
  "And then a very very very long long long long long long long long longlong long long long long long longlong long long long long long longlong long long long long long longlong long long long long long longlong long long long long long long long one", "and", "then", "some", "short short short ones"
]

private func text(_ data: Any) -> some View {
  Text(String(describing: data))
    .font(.system(size: 12))
    .foregroundColor(.black)
    .padding()
    .background(RoundedRectangle(cornerRadius: 4)
      .border(Color.gray)
      .foregroundColor(Color.gray))
}

struct FlowLayout_Previews: PreviewProvider {
  static var previews: some View {
    FlowLayout(mode: .scrollable, data: sampleData) {
      text($0)
    }
    .padding()
  }
}

struct TestWithDeletion: View {
  @State private var data = sampleData

  var body: some View {
    VStack {
      Button("Delete all") {
        data.removeAll()
      }
      Button("Restore") {
        data = sampleData
      }
      Button("Add one") {
        data.append("\(Date().timeIntervalSince1970)")
      }
      FlowLayout(mode: .vstack, data: data) {
        text($0)
      }
      .padding()
    }
  }
}

struct TestWithDeletion_Previews: PreviewProvider {
  static var previews: some View {
    TestWithDeletion()
  }
}

struct TestWithRange_Previews: PreviewProvider {
  static var previews: some View {
    FlowLayout(mode: .scrollable,
               data: 1..<100) {
      text($0)
    }.padding()
  }
}

// MARK: - Migration Helpers

public extension FlowLayout {
  @available(swift, obsoleted: 1.1.0, renamed: "attemptConnection")
  var viewMapping: (Data.Element) -> Content { content }

  @available(swift, obsoleted: 1.1.0, renamed: "init(mode:trigger:data:spacing:content:)")
  init(mode: Mode,
       binding: Binding<Trigger>,
       items: Data,
       itemSpacing: CGFloat = flowLayoutDefaultItemSpacing,
       @ViewBuilder viewMapping: @escaping (Data.Element) -> Content) {
    self.init(mode: mode,
              trigger: binding,
              data: items,
              spacing: itemSpacing,
              content: viewMapping)
  }
}

public extension FlowLayout where Trigger == Never? {
  @available(swift, obsoleted: 1.1.0, renamed: "init(mode:data:spacing:content:)")
  init(mode: Mode,
       items: Data,
       itemSpacing: CGFloat = flowLayoutDefaultItemSpacing,
       @ViewBuilder viewMapping: @escaping (Data.Element) -> Content) {
    self.init(
      mode: mode,
      trigger: .constant(nil),
      data: items,
      spacing: itemSpacing,
      content: viewMapping
    )
  }
}
