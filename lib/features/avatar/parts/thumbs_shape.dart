/// Auto-generated from DiceBear thumbs style (MIT license).
/// Source: https://github.com/dicebear/dicebear
library;

/// Shape (body) variants for the DiceBear thumbs avatar style.
///
/// Each value is an SVG fragment. Placeholder tokens:
///   {{SHAPE_COLOR}} — replaced with the selected shape/body hex color
///   {{FACE}}        — replaced with the selected face SVG fragment
///
/// The shape wraps the face: it draws the body silhouette and then embeds the
/// face group at translate(29, 33) within the 100x100 viewBox coordinate space.
const Map<String, String> thumbsShape = {
  'default':
      '<path d="M95 53.33C95 29.4 74.85 10 50 10S5 29.4 5 53.33V140h90V53.33Z" fill="{{SHAPE_COLOR}}"/>'
      '<g transform="translate(29 33)">{{FACE}}</g>',
};
