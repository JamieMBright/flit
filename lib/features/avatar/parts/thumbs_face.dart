/// Auto-generated from DiceBear thumbs style (MIT license).
/// Source: https://github.com/dicebear/dicebear
library;

/// Face variants for the DiceBear thumbs avatar style.
///
/// Each value is an SVG fragment. Placeholder tokens:
///   {{EYES}}  — replaced with the selected eyes SVG fragment
///   {{MOUTH}} — replaced with the selected mouth SVG fragment
const Map<String, String> thumbsFace = {
  'variant1': '<g transform="translate(0 5)">{{EYES}}</g>'
      '<g transform="translate(6 23)">{{MOUTH}}</g>',
  'variant2': '<g transform="translate(0 4)">{{EYES}}</g>'
      '<g transform="translate(6 24)">{{MOUTH}}</g>',
  'variant3': '<g transform="translate(0 3)">{{EYES}}</g>'
      '<g transform="translate(6 25)">{{MOUTH}}</g>',
  'variant4': '<g transform="translate(0 2)">{{EYES}}</g>'
      '<g transform="translate(6 26)">{{MOUTH}}</g>',
  'variant5': '<g transform="translate(0 1)">{{EYES}}</g>'
      '<g transform="translate(6 27)">{{MOUTH}}</g>',
};
